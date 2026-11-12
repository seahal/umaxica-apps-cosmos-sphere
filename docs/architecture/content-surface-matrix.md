# Content Surface Ownership

Updated 2026-11-10. The twelve Publishing data families remain a 3 × 4 matrix:

```text
          info   docs   news   help

app
com
org
```

`app`, `com`, and `org` identify audiences. They do not identify database placement. Each cell is a
physical family in the central `publishing` database; see
[`publishing-persistence.md`](publishing-persistence.md).

## Route and runtime ownership

The current owner-approved surface scope keeps `docs`, `news`, `help`, and `info` in Sphere on their
`app`, `com`, and `org` host groups. Those routes serve the public content roots, health and
revision endpoints, CSP report intake, and read-only published-entry API. `edit.org` remains the
staff Publishing management surface and its independent relying-party boundary.

The earlier
[Cosmos Press Route Ownership specification](../../specs/cosmos-press-route-ownership/spec.md)
described a proposed transfer of these routes. That transfer is not part of the current scope; this
repository continues to own the listed routes and controllers. Auth, Base, Core, GUID, Palm, Tech,
Visa, and Warp routes are retired by the surface hard reset.

The `publishing` connection, schema, data, and models remain in place. The hard reset does not drop
databases or delete models/migrations. The accompanying evidence report records which model
connections still have non-model callers and which are referenced only through models or tests.

## Related

- [`publishing-persistence.md`](publishing-persistence.md)
- [`docs-help-news-content-boundary.md`](docs-help-news-content-boundary.md)
- [`adr/publishing-db-content-authority.md`](../../adr/publishing-db-content-authority.md)
