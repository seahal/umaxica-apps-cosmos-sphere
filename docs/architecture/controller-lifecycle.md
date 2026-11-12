# Controller Lifecycle

## Current Contract

Cosmos Sphere serves the Core app, organization, network, and developer surfaces; the Warp app and
organization surfaces; the Palm app surface; and the Mission, Flipper, Blazer, PgHero, Swagger, and
Coverband operator tools. Each browser surface owns its controller lifecycle, host constraint, and
access checks. Tool engines own their controller lifecycle and access checks.

The root `ApplicationController` supplies the Rails CSRF baseline to mounted tools. It does not
inherit authentication, preference, actor, or session behavior from any application surface.
`UnknownHostsController` handles only the root request for a host that does not match a retained
surface. The runtime route guard refuses controllers without an explicit owner.

## Adding an Endpoint

Any future application-owned endpoint needs an accepted surface owner, a host constraint, an
authentication and authorization contract, and tests for its route boundary. Keep controller
callbacks and request state within the owning surface. See
[controller boundaries](controller-boundaries.md), the [surface matrix](content-surface-matrix.md),
and the accepted [operator-tools-only decision](../../adr/cosmos-sphere-operator-tools-only.md),
whose original scope was later amended to retain the listed Sphere surfaces.
