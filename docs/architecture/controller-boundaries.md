# Controller Boundaries

## Current Application Controllers

Cosmos Sphere owns the host-constrained Docs, News, Help, and Info public content routes and the
Edit org Publishing management and relying-party routes. The application controller families are
`Docs`, `News`, `Help`, `Info`, and `Edit`. Each family owns its route set, presentation, and
request boundary.

The root `ApplicationController` remains the base required by Mission Control Jobs inheritance.
`UnknownHostsController` returns the machine-readable 404 for a request that matches no retained
surface or tool host.

Mission, Flipper, Blazer, PgHero, Swagger, and Coverband are mounted operator tools. Their
controllers belong to their mounted engines or Rack applications. Their authentication,
authorization, and request lifecycle remain with those owners and their existing configuration.

## Adding an Application Controller

A new application controller requires a retained surface owner, a route constraint for that surface,
and an explicit request/security contract. Do not restore an Auth, Base, Core, GUID, Palm, Tech,
Visa, or Warp controller namespace as an incidental dependency of another surface.

The current owner-approved scope is recorded in the
[surface hard-reset specification](../../specs/sphere-operator-tools-hard-reset/spec.md) and
[content surface matrix](content-surface-matrix.md). The earlier operator-only ADR is superseded for
application-route ownership; its historical decision remains at
[`cosmos-sphere-operator-tools-only.md`](../../adr/cosmos-sphere-operator-tools-only.md).
