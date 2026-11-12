# Health Endpoints

## Routed surfaces

Docs, News, Help, and Info expose health and revision endpoints on their app, com, and org host
groups. Edit exposes the same endpoint family on its org host. The operator-tool mounts have no
shared application health route.

| Route                       | Response           | Purpose                                                           |
| --------------------------- | ------------------ | ----------------------------------------------------------------- |
| `GET /health`               | `text/plain`       | Surface-local aggregate snapshot.                                 |
| `GET /health/liveness`      | `text/plain`       | Confirms the Rails process can respond.                           |
| `GET /health/readiness`     | `text/plain`       | Checks the dependencies assigned to the audience profile.         |
| `GET /health/startup`       | `text/plain`       | Confirms Rails completed initialization.                          |
| `GET /api/v0/health.json`   | `application/json` | Machine aggregate; refuses an `Accept` header that excludes JSON. |
| `GET /revision`             | `text/plain`       | Deployment revision.                                              |
| `GET /api/v0/revision.json` | `application/json` | Machine-readable deployment revision.                             |

Health responses use `Cache-Control: no-store`. They identify the route-selected surface and expose
only the public status contract; they do not include host configuration, database topology,
credentials, or exception messages. Readiness failures return unavailable without exposing the
underlying exception.

The routes remain constrained to the retained host groups and are subject to Rails Host
Authorization. They do not provide an unhosted bypass for unknown hosts. Auth, Base, Core, GUID,
Palm, Tech, Visa, and Warp health routes are not served by this repository.
