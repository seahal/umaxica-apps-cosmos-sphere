# Cosmos Sphere Serves App, Org and Com and Will Stop Reading Access Databases (2026-11-08)

## Status

Accepted (2026-11-08), direction only. Implementation timing and design are decided later.

## Context

Sphere (formerly Regional) owns the `core`, `palm` and `warp` subdomains and will be deployed in N
regions from one codebase. It is a relying party of Access (formerly Identity) under
`adr/cosmos-identity-authentication-global-authorization-split.md`.

A read-only survey of the shared codebase on 2026-11-08 (`umaxica-apps-cosmos-access` at
`281a9e5c5`) found:

- The `core`, `palm` and `warp` base controllers include `BrowserRpAuthentication`,
  `SessionLimitGate` and `AuthorizationAudit`. `BrowserRpAuthentication` has a local-cell path that
  verifies the Access JWT against public JWKS and uses the RP's own session store, and a legacy path
  that reads Access-owned databases (`op_base_app/org`, principals). Which path runs depends on the
  runtime role. `SessionLimitGate` reads `op_base_*` when resolving session limits, and
  `AuthorizationAudit` writes `chronicle`.
- RP runtime roles, OIDC clients and cell stores carry a region in their names (`rp-core-app-jp`,
  `core-app-jp`, `rp_core_app`). Adding a region appears to add a role, a client and a database per
  surface; this has not been verified.

## Decision

1. **Sphere serves the `app`, `org` and `com` surfaces.** `org` is Sphere's own staff surface for
   Sphere's domain, distinct from Governance's `tech`, which manages authorization configuration.
   `com` is served without models or authentication.
2. **Sphere will not read any Access-owned database.** Sphere authenticates and authorizes from OIDC
   tokens issued by Access and from its own stores only. The in-process reads listed above are
   removed. This work starts after the Access and Governance separation is complete.
3. **Multi-region deployment is validated in staging.** The per-region shape of runtime roles, OIDC
   clients and databases is tested when staging `us` and `jp` regions are built, before production
   regions depend on it.
4. **Only `jp` is planned for now.** Sphere is designed, built and operated for the `jp` region
   until another region is decided. Names keep the region (for example the `sphere-jp-dev`
   Cloudflare Tunnel) so that later regions follow the same pattern.

## Consequences

- Until decision 2 is implemented, Sphere paths that still use the legacy authentication path need
  Access databases, so routing cleanup alone cannot remove `op_base_*`, `rp_base_*` or principal
  connections from Sphere.
- Distant regions reading Access databases directly is not an acceptable end state for latency and
  isolation; decision 2 removes that dependency.
- The per-region naming may change after the staging validation.

## Open Questions

- Which business databases `core`, `palm` and `warp` use beyond authentication (`*_setting`,
  `*_signal`, `occurrence`, `avatar`, `search`), including through jobs and model associations.
- The concrete responsibilities of `warp`.
- Sphere keeps its own `chronicle` instance (`adr/cosmos-common-database-connections.md`); which
  audit records stay there once Access-owned principals are no longer available is open.

## Amendment: Public Hostnames for Core, Warp and Palm (2026-11-10)

**Status: Accepted (owner).** Sphere's public hostnames are renamed so each name says which surface
it serves, with the region suffix `-jp`:

| Surface | Before                                                           | After                                                               |
| ------- | ---------------------------------------------------------------- | ------------------------------------------------------------------- |
| Core    | `jp.umaxica.app`, `jp.umaxica.com`, `jp.umaxica.org`             | `www-jp.umaxica.app`, `www-jp.umaxica.com`, `www-jp.umaxica.org`    |
| Warp    | `www-jp.umaxica.app`, `www-jp.umaxica.com`, `www-jp.umaxica.org` | `warp-jp.umaxica.app`, `warp-jp.umaxica.com`, `warp-jp.umaxica.org` |
| Palm    | `palm-jp.umaxica.app`                                            | `palm-jp.umaxica.app` (unchanged)                                   |

`www-jp` now matches `www` (Governance's Base): the regional entry point. Because `www-jp` changes
meaning (Warp before, Core after), every consumer must switch in one coordinated step: Sphere's
`PUBLIC_CORE_*`, `PUBLIC_WARP_*` and `PUBLIC_PALM_*` URLs and Dev Container aliases; Access's OIDC
client registrations (redirect and post-logout URIs) for the Core, Warp and Palm clients; the
Cloudflare tunnel routes, DNS records, Access applications and Turnstile widget domains; and Jump's
approved edges. The Core path rule previously applied to `jp.*`
(`docs/architecture/cloudflare-request-paths.md`) moves to `www-jp.*` unless decided otherwise.

Decided later the same day (owner): in development the `www-jp.*` routes carry **no** path rule, so
every Core path reaches Rails; with the rule, `/` fell through to the tunnel's 404 because no Edge
Worker answers Core pages in development. Whether production restricts Core paths is still open.
