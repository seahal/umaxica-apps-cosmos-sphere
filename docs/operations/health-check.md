# Health Checks

Docs, News, Help, and Info expose surface-local health and revision endpoints on their app, com, and
org host groups. Edit exposes them on its org host. Use the host values configured for the surface
being checked; routes and Host Authorization enforce the matching host boundary.

`GET /health/liveness` is the process probe. `GET /health/readiness` checks the database roles in
the audience profile, and `GET /health/startup` confirms Rails initialization. Use `GET /health` for
the plain-text aggregate or `GET /api/v0/health.json` for the machine-readable aggregate. The
revision endpoints are documented in [Health Endpoints](../reference/health-endpoints.md).

The unknown-host root response is not a health probe. It returns a machine-readable 404 for an
unclaimed host. Operator tools keep their own authentication and diagnostics and do not share the
application health routes.
