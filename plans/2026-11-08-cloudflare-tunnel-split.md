# Cloudflare Tunnel Split Across Cosmos Repositories (2026-11-08)

Status: accepted work order for an agent (for example Codex). Do not commit; the owner reviews and
commits.

Sphere amendment (2026-11-10): the Rails `performance` surface was removed from Sphere. This plan
does not authorize Cloudflare changes; its existing tunnel, DNS, and Access records remain untouched
until the owner separately approves cleanup. Do not add a Sphere Rails origin for this hostname.

## Target

The four Cosmos repositories started as copies of one application (formerly Global) and still carry
the same tunnel configuration and token copies. Each repository gets its own tunnel:

| Repository | Tunnel                                                       | Hostnames                                                                       |
| ---------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| Access     | existing tunnel, kept as is                                  | `visa`, `auth` (app and org)                                                    |
| Governance | `governance-dev` (new)                                       | `base` (`www`, app, org and com), `tech` (org)                                  |
| Sphere     | `sphere-jp-dev` (new; one tunnel per region and environment) | `core` (app, org), `palm` (app), `warp` (app, org, com)                         |
| Press      | `press-dev` (new) plus the existing Workers VPC tunnel       | `edit` (org) on `press-dev`; `info`, `news`, `help`, `docs` stay on Workers VPC |

`guid` is not attached to any tunnel; it is to be retired. Whether each repository's `.dev` operator
tools get hostnames on its tunnel is an owner decision taken during step 2 of the repository section
below.

Tunnel names follow `<repository>-<environment>`; Sphere adds the region:
`sphere-<region>-<environment>`. Only `jp` is planned for Sphere for now.

Workers VPC (`umaxica-dev-workers-vpc`) is used only by Press. Access, Governance and Sphere remove
their own Workers VPC connector definition, token reference and documentation. Nobody deletes the
Workers VPC tunnel, its token, its DNS records or the Workers configuration in Cloudflare.

Related records: `adr/cosmos-base-surface-decomposition.md`,
`adr/cosmos-sphere-surfaces-and-rp-independence.md`, `specs/cosmos-press-route-ownership/spec.md`.

## Cross-Repository Order

1. Governance, Sphere and Press each create their new tunnel and Access applications, without
   hostnames that the existing tunnel still serves.
2. For each hostname that leaves the existing tunnel: Access removes it from the existing tunnel,
   then the receiving repository attaches it to its new tunnel. Do both for one hostname before
   moving to the next, so no hostname points at two tunnels.
3. Access, Governance and Sphere remove their Workers VPC configuration from their repositories.
4. Each repository starts `cloudflared` in its Dev Container and confirms its own hostnames open.

Until a repository has its own token, leave `CLOUDFLARED_TOKEN` empty in that repository's `.env`
when more than one Dev Container runs; four connectors on one token join the same tunnel as replicas
and traffic reaches a random repository.

## Rules for Every Repository

- Survey first and wait for owner approval before changing anything in Cloudflare.
- Cloudflare is an external service: change one item at a time and confirm the result.
- Never delete or rotate the existing tunnel or its token; Access keeps using them.
- Ask the owner before deleting any DNS record.
- Never print secret values in logs, documents or the conversation. Ask the owner where a new token
  is stored before writing it to a file.
- Do not commit. Report what was created, removed and kept, which files changed, and what was
  verified.

## This Repository: Sphere

Create `sphere-jp-dev`; discard this repository's copy of the existing token. Later regions and
environments follow the same pattern (`sphere-us-dev`, `sphere-jp-stg`).

1. Survey: list where this repository keeps tunnel configuration and tokens (`compose.yaml`
   `cloudflare-tunnel`, `cloudflare-tunnel-edge`, the Workers VPC connector, `.env*`, credentials),
   the hostnames and Access applications they serve, and whether they point at the existing tunnel
   that Access keeps. Read only.
2. Plan and wait for approval: the `sphere-jp-dev` tunnel; hostnames `core` (app, org), `palm` (app)
   and `warp` (app, org, com); their Access applications; where the new token is stored; how names,
   hostnames and tokens grow per region; removal of the Workers VPC configuration.
3. Execute after approval: create `sphere-jp-dev`; attach each hostname right after Access removes
   it from the existing tunnel; store the new token and remove the existing token from this
   repository; remove the Workers VPC connector, its token reference and its documentation.
4. Start `cloudflared` in the Dev Container and confirm it connects to `sphere-jp-dev`.
5. Update `compose.yaml` and `docs/operations/` to the new layout.

## Operator Hostnames (decided 2026-11-09)

The owner decided repository-specific public hostnames for the `.dev` operator tools. This
repository uses:

- `mission-sphere-jp.umaxica.dev`
- `flipper-sphere-jp.umaxica.dev`
- `blazer-sphere-jp.umaxica.dev`
- `pghero-sphere-jp.umaxica.dev`
- `swagger-sphere-jp.umaxica.dev`
- `performance-sphere-jp.umaxica.dev`
- `coverband-sphere-jp.umaxica.dev`

Every repository follows `<tool>-<suffix>.umaxica.dev`:

| Repository | Operator hostname pattern       | Example                          |
| ---------- | ------------------------------- | -------------------------------- |
| Access     | `<tool>-access.umaxica.dev`     | `mission-access.umaxica.dev`     |
| Governance | `<tool>-governance.umaxica.dev` | `mission-governance.umaxica.dev` |
| Press      | `<tool>-press.umaxica.dev`      | `mission-press.umaxica.dev`      |
| Sphere     | `<tool>-sphere-jp.umaxica.dev`  | `mission-sphere-jp.umaxica.dev`  |

Each name is one label under `umaxica.dev`, so Cloudflare's Universal SSL certificate for
`*.umaxica.dev` covers it without an extra certificate. The region in the suffix matches the tunnel
name (`sphere-jp-dev`), so later regions such as `us` do not collide. Do not reuse another
repository's hostnames or the original unsuffixed names.

Steps, following the Access precedent in `plans/2026-11-08-cloudflare-tunnel-split.md` of
`umaxica-apps-cosmos-access`:

1. Update the seven `PUBLIC_*_URL` entries in `.env.container.devcontainer` and the public-host
   network aliases in `.devcontainer/compose.yaml`. Keep the `PRIVATE_*_URL` values and internal
   `*.core.dev.localhost` aliases.
2. Reconcile route comments and current operator documentation with these names.
3. Plan this repository tunnel's ingress, DNS records and Cloudflare Access applications for these
   names, keeping origin authentication. Obtain the owner's approval before external changes.
4. Recreate the affected containers after active tests finish, then verify host admission,
   unauthenticated refusal and authenticated access for every tool.

## Cloudflare State After the Split (2026-11-09)

The owner had Claude apply the Cloudflare side through the Cloudflare API MCP server, one step at a
time with approval, reading each change back. Access protection was configured before DNS for every
new hostname. Tunnel tokens were never printed or recorded; the owner copied each into the
repository's `.env`.

| Repository | Tunnel (ID)                                               | Hostnames → origin                                                                                                   | Access application                     |
| ---------- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Access     | `Auth` (`1d501e9a-62f7-4c0d-ba5e-a26e3f10088f`), existing | `visa`/`auth` `.umaxica.app`/`.org` → `visa`/`auth` `.{app,org}.localhost`; `<tool>-access.umaxica.dev`              | `access-dev`; tools in `dashboard`     |
| Governance | `governance-dev` (`fed9d611-67fb-42c4-afb8-cadc6c251878`) | `www.umaxica.{app,org,com,dev}` → `base.*.localhost`; `tech.umaxica.org` → `tech.org.localhost`; `<tool>-governance` | `governance-dev`; tools in `dashboard` |
| Press      | `press-dev` (`142819c4-75c1-4cb0-8cdd-9d7f81fbafe7`)      | `edit.umaxica.org` → `edit.org.localhost`; `<tool>-press.umaxica.dev`                                                | `press-dev`; tools in `dashboard`      |
| Sphere     | `sphere-jp-dev` (`e5acbb34-4efe-4f31-9fbb-82e91e0a26bd`)  | `www-jp.umaxica.{app,com,org}` → `warp.*.localhost`; `<tool>-sphere-jp.umaxica.dev`                                  | `sphere-jp-dev`; tools in `dashboard`  |

- Every tool hostname routes to `http://<tool>.core.dev.localhost:3000`. Every tunnel ends with an
  `http_status:404` catch-all (Auth's was `http_status:300` before).
- All DNS records are proxied CNAMEs to `<tunnel id>.cfargotunnel.com`. `www`, `www-jp` and `edit`
  were repointed from `Auth`; the others were created.
- Every Access application uses the reusable `dev` policy, which now allows only the owner's two
  email addresses. It previously included anyone authenticated by password or one-time PIN, which
  denied the owner in practice. After this change no tunnel hostname is outside an Access
  application.
- `www-jp` is Warp, not Core. Core and Palm had no published hostname on any tunnel; the
  `jp.umaxica.app` path route is recorded in Sphere's
  `docs/backlog/2026-11-09-core-jp-app-path-route.md`.
- Workers VPC (`umaxica-dev-workers-vpc`) was not changed.

### Open After This Step

- Connectors: until Governance, Press and Sphere recreate `cloudflare-tunnel`, their running
  connectors still carry the old `Auth` token (four connectors on `Auth`), and Governance and Sphere
  still run Workers VPC connectors removed from their Compose files. Verify one connector per tunnel
  after recreation.
- Repository configuration for the tool hostnames (Compose aliases and `PUBLIC_*_URL`) is done in
  Access and Press (Press's `.devcontainer` patch is still unapplied) and pending in Governance and
  Sphere.
- Cleaned up with owner approval (2026-11-09): the seven unsuffixed tool DNS records and their
  `dashboard` destinations; `us.umaxica.{app,com,org}` and the stopped `Edge` tunnel;
  `wide-jp.umaxica.org` (a former Warp name). Kept: the stopped `DEV-MP4-EDGE` tunnel and its
  records (`info`, `docs-jp`, `help-jp`, `news-jp`, `umaxica.dev`, `umaxica.net`), which the owner
  reports are served by Press's Workers VPC path.
- Visa is behind Access. Server-to-server OIDC calls through the public hostname will be refused; a
  bypass for the protocol endpoints or a service token is needed before testing RP and OP through
  the tunnel.
- The MCP connection holds DNS, Access and Tunnel write scopes; revoke or reduce it when this work
  ends.

### Access Policies: `surface-gate` and `dev` (2026-11-09, later the same day)

The owner reversed the blanket protection above for the public surfaces:

- `surface-gate` (reusable policy `a9d526d4-3cdd-4794-ac7c-322298a7890f`) is attached to every
  `app`, `com` and `org` Access application: `access-dev`, `governance-dev`, `sphere-jp-dev`,
  `press-dev`, `info`, `help-jp`, `news-jp` and `docs-jp`. Normally it is **Bypass / Everyone**, so
  these hosts are public again and server-to-server OIDC calls (Discovery, JWKS, token, userinfo,
  revocation, and RP JWKS) pass without Access. `info`, `help-jp`, `news-jp` and `docs-jp` were in
  practice locked before this change and became public with it.
- `dev` (owner's two email addresses) stays only on `dashboard`, the `.dev` operator tools.
- The name carries no environment so the same policy can exist in staging and production accounts.

**To lock every public surface at once:** edit `surface-gate` to Action **Allow**, Include
**Emails** (the owner's addresses). This also stops RP and OP server-to-server calls, so RP sign-in
fails while locked. To unlock, set it back to **Bypass / Everyone**.

### Sphere hostnames renamed (2026-11-10)

Per `adr/cosmos-sphere-surfaces-and-rp-independence.md` (amendment 2026-11-10), the `sphere-jp-dev`
tunnel now serves: `www-jp.umaxica.{app,com,org}` -> Core (`core.*.localhost`, with the Core path
rule `^/((api/v0|oidc|sign)(/.*)?|\.well-known/jwks\.json|csp-violation-report)$`);
`warp-jp.umaxica.{app,com,org}` -> Warp (`warp.*.localhost`); `palm-jp.umaxica.app` -> Palm
(`palm.app.localhost`). DNS records for `warp-jp` and `palm-jp` were created; interim
`warp.umaxica.{app,com,org}` and `palm.umaxica.app` records made in the dashboard earlier that day
were deleted. The `sphere-jp-dev` Access application and the `sphere-development-*` Turnstile
widgets list exactly the seven new hostnames. Sphere and Access configuration must follow (Codex
work orders in the conversation).

Sphere `.com` removed (2026-11-10): `www-jp.umaxica.com` and `warp-jp.umaxica.com` were taken off
the `sphere-jp-dev` tunnel, DNS, Access and Turnstile (owner decision; Sphere backlog
`docs/backlog/2026-11-10-sphere-has-no-com.md`).
