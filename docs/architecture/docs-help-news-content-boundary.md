# Publishing Content Route Boundary

Updated 2026-11-09. The accepted
[Cosmos Press Route Ownership specification](../../specs/cosmos-press-route-ownership/spec.md)
assigns the `edit`, `info`, `news`, `help`, and `docs` host-constrained routes and presentation to
Cosmos Press. Sphere no longer draws those route families and has removed their controllers, views,
and route-specific tests.

## Sphere responsibilities that remain

Sphere retains the Publishing database connection, schema, persisted data, models, and domain
operations. These are separate from ownership of the HTTP surfaces. Base's server-to-server owner
API under `/api/v0/publishing/*` remains routed through the Base surface. The `publishing` database
connection will only change under a separate decision.

Sphere no longer serves the public `GET /api/v0/entries` and `GET /api/v0/entries/:public_id`
endpoints on the content hosts. The corresponding operations were removed from the Sphere OpenAPI
descriptions. Requests to those hosts now reach the unknown-host fallback in this application;
Sphere does not redirect them or create replacement endpoints.

OIDC client registrations, redirect URI values, and authentication and authorization logic were
outside this route removal and remain unchanged. Their presence in configuration does not mean
Sphere still serves the retired Edit routes.

## Press implementation status

The Press checkout was not available for this change. The ownership decision and Sphere-side route
removal are recorded here; no claim is made about deployment or runtime behavior in Press.

## Related

- [`content-surface-matrix.md`](content-surface-matrix.md)
- [`publishing-persistence.md`](publishing-persistence.md)
- [`adr/publishing-db-content-authority.md`](../../adr/publishing-db-content-authority.md)
