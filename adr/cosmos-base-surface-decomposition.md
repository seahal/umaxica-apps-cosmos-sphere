# Cosmos Base Surface Decomposition (2026-11-08)

## Status

Accepted (2026-11-08), direction only. Implementation order and design are decided later. Preference
placement remains open.

## Context

`adr/cosmos-identity-authentication-global-authorization-split.md` lists the placement of Base as an
open question. Base combines ceremony screens, post-sign-in screens, authorization administration,
operator work, avatars, preferences and a publishing API. Base is itself a relying party of Visa (it
has `oidc/callback`), not the authorization server, so most of it does not need to live in Access.

Repository names: Access was Identity, Governance was Global, Sphere was Regional.

The groups below were taken from `config/routes/base.rb` in `umaxica-apps-cosmos-access` at
`281a9e5c5`.

Corrected 2026-11-08: step-up `verification` is the RP side of step-up, has its own OIDC callback,
and stays with Governance; an earlier version of this record assigned it to Access.

## Decision

| Group                           | Examples                                                                                                                       | Owner                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------ |
| 1. Authentication ceremonies    | `ceremony_bindings/.../confirmation`, `identity/recovery`, `identity/mfa`, passkey and TOTP registration                       | Access                                                 |
| 2. Authorization administration | `iam/grants`, `organizations/memberships`, `groups`, `api/v0/membership`, `api/v0/iam`                                         | Governance                                             |
| 3. Operator work                | `support/enforcement_cases`, `clients/revocations`, `audit`, `system`                                                          | Governance                                             |
| 4. Step-up (RP side)            | `verification`, `verification/{setups,callbacks,completions,cancellations}`                                                    | Governance                                             |
| 5. Account screens              | `dashboard`, `identity` lists (emails, telephones, sessions, passkeys), `withdrawal`, `privacy/erasure`, `secrets`, `billings` | Governance                                             |
| 6. Avatars and social graph     | `avatars`, follow, block, mute, `ownership_transfers`, `api/v0/avatar`                                                         | Canonical data in Governance; social screens in Sphere |
| 7. Preferences                  | `preference/*` on `app`, `org` and `com`                                                                                       | Open                                                   |
| 8. Publishing API               | org `publishing` (docs, help, info, news entries and archives)                                                                 | Press `edit`                                           |
| 9. Protocol endpoints           | `sign`, `sign/out`, `oidc/callback`, `jwks`, health, revision                                                                  | Placed by OP/RP role, following the standards below    |

1. **Authentication facts belong to Access; authorization configuration belongs to Governance.**
   Sign-ins, MFA, sessions, token issuance and revocation, and their audit records are written only
   by Access. Organizations, memberships, roles, permissions and their change history are written
   only by Governance, which publishes them to Access as signed snapshots. Both sides keep their own
   audit records, correlated by `sub` and time.
2. **Account screens live in Governance and own no Access data.** Lists of credentials and sessions
   are read from a read-only Access interface. Registering or removing a credential redirects to an
   Access ceremony and back. Withdrawal is confirmed by an Access ceremony; Access notifies
   Governance by event and Governance cleans up its own records. `secrets` and `billings` are stored
   by Governance.
3. **Avatars and the social graph are canonical in Governance.** This includes follow, block and
   mute, and is not to be changed. Sphere serves the social screens, writes changes to Governance,
   and reads from a copy distributed by Governance rather than calling Governance on every display.
   Social writes are unavailable while Governance is down; this does not conflict with the split
   ADR, whose availability rule covers authentication and authorization only.
4. **The publishing API moves to Press `edit`.** It was placed in Base when the application was
   Global; it belongs with the staff publishing relying party.
5. **Protocol endpoints follow the standards.**
   - Access (Visa, the OP): OpenID Connect Discovery 1.0 (`/.well-known/openid-configuration`),
     `jwks_uri` (RFC 7517), authorization and token endpoints (RFC 6749, OpenID Connect Core 1.0),
     userinfo, revocation (RFC 7009), introspection (RFC 7662) and `end_session_endpoint` (OpenID
     Connect RP-Initiated Logout 1.0).
   - Every RP: `redirect_uri` (current `oidc/callback`), `backchannel_logout_uri` (OpenID Connect
     Back-Channel Logout 1.0), its own `jwks_uri` for `private_key_jwt` (RFC 7523, OpenID Connect
     Core 1.0 section 9), the sign-in entry (current `sign`) and RP-initiated sign-out (current
     `sign/out`).
   - Every application: health and revision.
6. **Step-up is split by role.** Governance, as the RP, requests stronger authentication from Visa
   with `acr_values` or `max_age` (OpenID Connect Core 1.0) and handles the result through its own
   `verification` callback; this is the client side of RFC 9470 (OAuth 2.0 Step Up Authentication
   Challenge Protocol). Access (Visa and Auth) performs the stronger authentication.
7. **Signed-in and anonymous use stay on separate subdomains.** `com` remains anonymous; `app` and
   `org` require sign-in.

8. **Auth and Visa carry no navigation out of their ceremonies.** They are not relying parties, so
   they cannot know whether the person is signed in at an RP. Their screens therefore show no links
   or menus to preferences, sign-in, sign-up or sign-out. Every entry starts at an RP through an
   OpenID Connect request: sign-in with an authorization request (OpenID Connect Core 1.0), sign-up
   with `prompt=create` (OpenID Connect Initiating User Registration 1.0), and sign-out through
   `end_session_endpoint` (OpenID Connect RP-Initiated Logout 1.0). The only way back is the RP's
   `redirect_uri` with `state`. Steps within one ceremony, such as moving from OTP entry to the next
   step, keep their links. Auth and Visa read the preference cookie for language and theme but offer
   no screen to change it.
9. **Auth and Visa have no home page.** `/` on an Auth or Visa host is unrouted and answers 404.
   Visa's roots were already retired on 2026-11-02 (`adr/rails-routing-resourceful-policy.md`);
   Auth's `root "roots#index"` is removed the same way. Code that uses the Auth root as a return or
   fallback destination (observed in `AuthenticationBase`, `SocialAuth`, `VerificationBase`, the org
   passkey ceremonies, `Auth::Org::Sign::UpsController` and the Auth layouts) returns to the RP's
   `redirect_uri` instead; when no valid RP return is known, it shows an explicit error rather than
   substituting another destination.

## Protocol Target: OAuth 2.1, OpenID Connect and FAPI 2.0 (amended 2026-11-10)

The owner set the target for every Cosmos OP and RP: conform to **OAuth 2.1** (the IETF
consolidation of OAuth 2.0 and its security best practice; still an Internet-Draft, so track the
current version), **OpenID Connect** (Core, Discovery, RP-Initiated and Back-Channel Logout) and the
**FAPI 2.0 Security Profile**. Implementation moves toward these step by step; current code that
differs is a gap to close, not an exception. PS256 signing
(`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`) is the first decision taken for FAPI 2.0.
Claiming conformance to FAPI 2.0 requires meeting the whole profile (for example PKCE, sender-
constrained tokens, `private_key_jwt` or mTLS client authentication, PAR), not only the algorithm.

## First Step: Hard Reset

The split is a hard reset. It replaces the order in the last consequence of
`adr/cosmos-identity-authentication-global-authorization-split.md` (establish the boundary inside
one application, then delete the unowned half): from the first step, each repository reads and
writes only its own databases, and existing development data is not carried across the boundary.
There is no transition in which Governance reads Access-owned databases.

Breaking existing development data and current behaviour is accepted. Deleting volumes or data, and
changing external services, still require the owner's approval each time.

Each repository keeps only its own routes by removing the `draw` lines for unowned subdomains from
`config/routes.rb`, then the code that no longer has a caller. `RuntimeRole` restricts one process
to one role; it is not the mechanism that separates repositories. Access keeps only `visa` and
`auth`; it has no relying party, so Base App, Base Org and Tech are removed from Access.

The goal is all four repositories running independently. Order:

1. **Access runs as a minimal OP and Auth.** Issuer, JWKS, authorization and token endpoints and the
   existing Auth ceremonies work with Access's own databases and keys only. Ceremonies moved from
   Base are not part of this step.
2. **Governance's RPs authenticate without Access databases, starting with Base App.** RP
   authentication already has two paths (observed at `281a9e5c5`): `BrowserRpAuthentication`
   branches between a local-cell path (`RpCellLocalSession`, `RpRequestAuthenticator`, which verify
   the Access JWT against public JWKS and use the RP's own session store) and a legacy path that
   follows OP grants, parent tokens, device sessions and canonical principals in Access-owned
   databases. Base RP-owned routes already use the local-cell path under the `shared` role.
   Governance moves Base App fully onto the local-cell path, including policies, the actor model and
   authoritative audit, and closes callback, refresh, logout and revocation under the existing
   separated-RP logout contract. Base Org and Tech follow the same pattern. Revocation latency and
   failure handling are decided after this is built.
3. **Authentication ceremonies (group 1) move to Access `auth` one at a time,** rebuilt on the OP
   session, as `ceremony_bindings/.../confirmation` already is through `AuthorityController`, and
   bound to the RP return. The Auth root fallbacks are removed in this step. The contract for this
   binding is decided when the step starts.
4. **Account screens separate their reads and updates** through the read-only Access interface and
   Access ceremonies; some current controllers also update Access-owned records (for example passkey
   names).
5. **Hostnames move** to each repository's tunnel after both sides accept the change.

## Consequences

- Access shrinks to Visa, Auth and the ceremony group; it keeps no administration console or
  dashboard, as the split ADR requires.
- Governance gains user-facing account screens and becomes an RP of Access for them.
- Sphere depends on Governance for social writes and on distributed copies for avatar and social
  graph reads.
- Press `edit` gains the publishing API in addition to the routes in
  `specs/cosmos-press-route-ownership/spec.md` (Press repository).

## Open Questions

- How Auth implements the authentication ceremonies once they leave Governance.
- Preference placement. The leading candidate is canonical storage in Governance, delivered as a
  realm-wide cookie (`.umaxica.app`, `.umaxica.org`) that every RP reads, with the same cookie used
  device-locally when signed out. `.app`, `.org` and `.com` cannot share one cookie, so preferences
  would be per realm. `locale` and `zoneinfo` could later be carried as standard OpenID Connect
  claims. Not decided.
- The read-only Access interface used by account screens, and the event channel from Access to
  Governance.
- How Governance distributes avatar and social-graph copies to N Sphere regions, and their maximum
  staleness.
