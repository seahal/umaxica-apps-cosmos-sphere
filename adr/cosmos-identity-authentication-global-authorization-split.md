# Cosmos Identity Executes Authentication and Authorization; Cosmos Global Is Its Control Plane (2026-11-08)

## Status

Accepted (2026-11-08), architecture only. Implementation, migration order and the open questions
below are not decided by this record.

Revised the same day: an earlier draft of this record made Global a runtime authorization decision
service behind an Identity relay. That model is replaced by the one below and is listed under
Rejected Alternatives.

This record changes the repository topology described in
`adr/split-into-regional-and-global-repos.md` (one global repository combining identity provider and
relying parties). Neither that record nor any other existing ADR has been amended yet; reconciling
them is follow-up work.

## Context

The GitHub repositories were renamed from `umaxica-apps-jit-*` to `umaxica-apps-cosmos-*`.
`umaxica-apps-cosmos-identity`, `umaxica-apps-cosmos-press` and `umaxica-apps-cosmos-regional` were
created as copies of `umaxica-apps-cosmos-global`. At this decision all four contain the same code.

That code combines, in one Rails application, the OpenID Provider (Visa), the credential ceremonies
(Auth), the browser RP and identity/session surface (Base), and the authorization model (policies,
organizations, roles and memberships). Credentials, signing keys and sessions live next to
permission data and policy rules, and the same application both edits and evaluates authorization.
Changes in one area have repeatedly risked silently breaking a boundary in another, and the combined
surface has become too large to change safely.

Press and Regional are ordinary end-user services. They need authentication and authorization
without carrying either.

This record uses the XACML component vocabulary, which remains the common language for dividing
authorization work: a Policy Administration Point (PAP) authors and manages policy; a Policy
Decision Point (PDP) evaluates it; a Policy Information Point (PIP) supplies attributes; a Policy
Retrieval Point (PRP) holds the policy the PDP reads; a Policy Enforcement Point (PEP) applies the
decision. Using the vocabulary does not adopt the XACML policy language.

## Decision

### Roles

| Repository      | Components                                                 | Responsibility                                                   |
| --------------- | ---------------------------------------------------------- | ---------------------------------------------------------------- |
| Identity        | OpenID Provider, OAuth authorization server, PDP, PIP, PRP | Executes authentication and common authorization                 |
| Global          | PAP (control plane)                                        | Manages and distributes authorization configuration              |
| Press, Regional | PEP and a local PDP                                        | Apply Identity's decisions and add service-specific restrictions |

1. **Identity is the only authorization server.** Identity hosts the OpenID Provider and all OAuth
   token issuance: sign-in, MFA, step-up, sessions, credentials, signing keys, ID tokens and access
   tokens. No other repository issues tokens.
2. **Identity executes common authorization.** Identity is the PDP for authorization common to all
   services (organizations, memberships, roles and permissions). It decides from the applied
   configuration (decision 5) and its own attributes, such as `sub` and `acr`. Services send
   authentication and common authorization requests to Identity only.
3. **Global is the control plane.** Global authors and manages organizations, memberships, roles,
   permissions, policy rules and authentication-strength requirements, validates changes to them,
   records their audit history, and publishes them to Identity. Whether a user may change
   permissions is decided by the published configuration, as for any other operation. Global is not
   an OAuth authorization server, takes no part in runtime authentication or authorization, and is
   never called while a request is being authenticated or authorized.
4. **Services may only narrow Identity's decision.** Press, Regional and other services are OpenID
   Connect relying parties of Identity. They enforce Identity's decision and may add a local
   decision about resources they own, such as whether an article belongs to the organization and is
   in an editable state. An operation is permitted only when both permit:
   `Permit = IdentityPermit AND LocalPermit`. A local decision can never grant what Identity denied.
   When a service finds that an operation needs stronger authentication, it signals a step-up
   challenge (RFC 9470, OAuth 2.0 Step Up Authentication Challenge Protocol) and Identity performs
   the step-up.

### Distribution

5. **Global publishes consistent, signed snapshots.** Global distributes policy rules and the
   attribute data they depend on (memberships and role assignments) together as one consistent
   snapshot, carrying Global's signature, a monotonically increasing version and an expiry. Identity
   applies a snapshot only after verifying signature, version (never older than the applied one),
   internal consistency and expiry. A snapshot that fails verification is not applied and the
   currently applied one stays in effect, subject to decision 7.
6. **Identity's code fixes what configuration can change.** A signature proves origin and integrity,
   not that the content is legitimate; a compromised Global can sign harmful configuration.
   Identity's code therefore fixes:
   - which kinds of configuration Identity accepts at all; OpenID Connect and OAuth configuration
     (decision 11) is never among them;
   - a minimum authentication strength for every operation, which configuration can raise but never
     lower;
   - safety constraints that configuration cannot remove.
7. **Stale configuration is handled by direction of risk.**
   - **Authentication strength:** staleness is safe in one direction. Identity uses the stronger of
     the last verified requirement and its code floors, and never runs weaker than the floors.
   - **Authorization data:** staleness is unsafe, because an old snapshot can still contain grants
     that Global has revoked. Each snapshot has a maximum age. Beyond it, Identity denies operations
     classified as sensitive and continues others only within a bound recorded with the snapshot
     format. Revocations must reach Identity within a stated time limit.
8. **Global's availability does not gate requests.** While Identity holds a valid snapshot, sign-in,
   token issuance and authorization continue when Global is down; only configuration changes stop.

### Surfaces and data

9. **Global's administration screens are an Identity relying party.** Administrators sign in at
   Identity through OpenID Connect and change configuration in Global's own screens.
10. **Identity serves ceremony screens only.** Identity renders only the screens that must run on
    its own origin: sign-in, MFA, passkey ceremonies, consent, step-up and sign-out. Credentials are
    entered only there, and passkeys are bound to Identity's origin. Identity has no administration
    console and no dashboard. User self-service lists live outside Identity; registering or removing
    a credential redirects to an Identity ceremony and back.
11. **OpenID Connect and OAuth configuration is Identity code.** Client registrations, redirect
    URIs, client secrets, signing keys, token lifetimes and MFA requirements are code in the
    Identity repository, reviewed and deployed, and are not writable from Global or from any screen.
    If Global could write redirect URIs, a Global compromise could register an attacker's redirect
    URI and obtain users' tokens.
12. **Identity and Global share no database.** Each owns its databases; neither reads nor writes the
    other's, directly or through a replica. Only these cross the boundary: the Identity subject
    (`sub`) as the reference to a person, tokens, signed snapshots from Global to Identity, and
    events from Identity to Global. Identity stores applied snapshots as a read-only copy; Global
    remains the only writer of authorization data. Global stores `sub` and no copy of credentials or
    profile data; display data comes from token claims or a read-only Identity interface. Lifecycle
    changes such as account deletion reach Global as events, and Global cleans up its own records.
    Audit records on both sides carry `sub` and time so they can be correlated without a shared
    store.

## Rejected Alternatives

- **Splitting OpenID Connect and OAuth across two servers.** OpenID Connect sign-in is an OAuth
  authorization code flow, so the OpenID Provider is necessarily an OAuth authorization server. A
  second authorization server would double keys, client registrations, token endpoints and
  revocation, and add token-exchange steps in which services can use the wrong token.
- **Global as a token-issuing authorization server.** Two token issuers blur the boundary for the
  same reason.
- **Global as the runtime PDP behind an Identity relay.** Identity would forward every authorization
  query to Global. Every request would pay an internal hop, and Global's outage would deny all
  authorization. Separating the PAP from the PDP keeps the management tool out of the request path.
- **Sharing a database between Identity and Global.** It would reconnect the halves below the
  application boundary.

## Open Questions

- The snapshot format, the operation vocabulary shared by Global, Identity and services, and how
  Identity's floors and fixed constraints are expressed.
- Full snapshots versus a full snapshot plus deltas, and whether revocations use a faster path than
  ordinary changes.
- The revocation time limit, the maximum snapshot age, and which operations are sensitive (decision
  7).
- Whether Identity pulls snapshots or Global pushes them, and how that channel is authenticated.
- Bootstrapping and recovery: how the first Global administrator is created when Global's own access
  depends on configuration Global publishes, and how a broken or malicious snapshot is recovered
  from.
- Whether access tokens carry coarse permissions, and how that interacts with revocation latency.
- Whether Global holds anything about a person beyond the Identity subject (`sub`).
- Placement of Base, which currently combines authentication screens with post-sign-in dashboards,
  and which application hosts user self-service lists (credentials, sessions).
- How code-managed client registration scales if the number of clients grows beyond a small, known
  set.
- Which current databases (`config/database.yml`) belong to Identity and which to Global, and how
  existing cross-database references and audit (Chronicle) records that span both sides are cut.

## Consequences

- Global can be offline without stopping sign-in or authorization; its outage stops only
  configuration changes.
- Identity holds a read-only copy of authorization data next to credentials. This is an accepted
  regression from fully separating credentials and permission data: the copy is read-only, signed
  and versioned, and editing and validation remain in Global.
- A Global compromise can sign harmful authorization configuration. Identity's fixed constraints
  bound it, and authentication cannot be weakened below Identity's floors; it is not otherwise
  prevented.
- Permission changes take effect after distribution, not immediately; the revocation limit makes
  that delay explicit.
- Services integrate with one endpoint and one token type, and keep their own resource rules.
- Superseded 2026-11-08 by the hard reset in `adr/cosmos-base-surface-decomposition.md` (each
  repository uses only its own databases from the first step): the split proceeds by first
  establishing the boundary inside one application (authorization evaluation reads only the applied
  configuration, and authorization editing writes only through the control plane), then deleting the
  unowned half from each repository, so each step keeps a working application.
