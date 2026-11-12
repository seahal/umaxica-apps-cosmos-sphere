# Public Entrypoints

This inventory covers application routes with an open authentication declaration on Sphere-owned
Core, Warp and Palm surfaces. The categories are enforced by
`test/unit/security/public_entrypoint_inventory_test.rb`. An open declaration does not grant a
session or bypass the action's credential, CSRF, Origin, Fetch Metadata, rate-limit or token checks.
Core serves app, org, net and dev; Warp serves app and org; Palm serves app. Each host retains its
independent trust boundary.

| ID                       | Entrypoints                                                                                                   | Boundary                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `PUBLIC_ROOTS`           | `GET /` on Core, Warp and Palm                                                                                | Host-local landing response; it grants no protected access.                                                              |
| `PUBLIC_DASHBOARD`       | Warp `GET /dashboard`                                                                                         | Preserves the existing Warp open dashboard contract; Palm's dashboard remains private.                                   |
| `PUBLIC_HEALTH`          | `GET /health`, `/health/liveness`, `/health/readiness`, `/health/startup`, `/api/v0/health.json` where routed | Exposes only the [health contract](../reference/health-endpoints.md).                                                    |
| `PUBLIC_REVISION`        | `GET /revision` and `/api/v0/revision.json` where routed                                                      | Returns deployment revision metadata.                                                                                    |
| `PUBLIC_CSP_REPORTS`     | `POST /csp-violation-report`                                                                                  | Browser security telemetry sink; preserves its validation and rate limits.                                               |
| `PUBLIC_WELL_KNOWN`      | `GET /.well-known/jwks.json`                                                                                  | Publishes verification keys only.                                                                                        |
| `PUBLIC_ROBOTS_SITEMAPS` | `GET /robots.txt` and `/sitemap.xml` where routed                                                             | Returns public crawler metadata.                                                                                         |
| `PUBLIC_PREFERENCE`      | Core/Warp app/org `GET` and `PATCH /api/v0/preferences/cookie` and `/theme`                                   | Uses the surface-local preference contract and existing unsafe-request protections.                                      |
| `PUBLIC_OAUTH_OIDC_SSO`  | RP `GET /oidc/callback` and `POST /oidc/closures`                                                             | Callback state, verified tokens and local RP binding control admission and logout. Access remains an external authority. |
| `PUBLIC_SIGN_IN_UP`      | RP `GET` and `POST /sign`, `GET /sign/interruption`                                                           | GET displays passive entry; POST starts the host's own RP authorization flow.                                            |
| `PUBLIC_SIGN_OUT`        | RP sign-out display, confirmation and completion routes                                                       | Mutations preserve session, CSRF and signed handoff checks; local state belongs to the originating RP.                   |
| `PUBLIC_CORE_API`        | Core app/org `GET /api/v0/session`, `POST /api/v0/token/refresh`                                              | The browser credential and refresh contracts remain independently enforced by the actions.                               |
| `PUBLIC_WARP_SETTINGS`   | Warp app/org `GET /settings`                                                                                  | Preserves the existing open settings display contract.                                                                   |
| `PUBLIC_PWA_OFFLINE`     | Warp app/org and Palm app `GET /service-worker` and `/offline`                                                | Rails framework endpoints, outside application authentication metadata; no authority or preference mutation.             |

Operator tools are separate host-constrained mounts with their own authentication boundaries. The
unknown-host root returns a generic machine-readable 404. Foreign Docs, Edit, Help, Info, News,
Auth, Visa, Base, Tech and GUID surfaces, Performance, and every corporate `.com` surface have no
application routes in Sphere. External authority integrations do not create local authority routes.

## Framework development routes

Inertia Rails registers two internal JSON GET routes at `/_inertia/devtools/entries` and
`/_inertia/devtools/entries/:id`, handled by its own `inertia_rails/devtools/entries` controller.
They have no dedicated host constraint; the engine applies its enabled constraint and access
callback. Sphere explicitly enables Devtools only in development in
`config/initializers/inertia_rails.rb`. These exact framework controller routes are excluded from
the application-surface inventory, alongside Rails PWA routes. They do not introduce a Sphere
surface or an application authentication declaration.
