# Prior Cosmos Sphere Operator-Only Scope

> **Superseded:** The owner-approved 2026-11-10 surface hard reset retains `edit.org`, `docs`,
> `news`, `help`, `info`, and the operator tools. See
> [`specs/sphere-operator-tools-hard-reset/spec.md`](../specs/sphere-operator-tools-hard-reset/spec.md)
> and the current inventory at
> [`evidence/2026-11-10-surface-hard-reset-A4V9.md`](../evidence/2026-11-10-surface-hard-reset-A4V9.md).
> The decision below records the earlier, superseded operator-only interpretation.

## Status

Accepted by the project owner on 2026-11-10 as the architecture direction for the hard-reset
cleanup. This decision supersedes the retained application-route scope in
[`cosmos-sphere-surfaces-and-rp-independence.md`](cosmos-sphere-surfaces-and-rp-independence.md).

## Decision

Cosmos Sphere keeps only its operator-tool routes: Mission, Flipper, Blazer, PgHero, Swagger, and
Coverband. The Core, Palm, and Warp controller trees and their routes are retired from this
repository. Auth, Base, Tech, and Visa are also absent. The application does not draw `edit`,
`info`, `news`, `help`, or `docs`: the current README and the accepted Cosmos Press route-ownership
specification assign those surfaces to the separate Cosmos Press repository.

The Rails unknown-host response remains so requests that do not match an operator-tool host do not
fall through to an unrelated application surface. Framework routes remain only when a retained
operator tool or required Rails runtime feature consumes them.

This route/controller reset does not drop databases, remove models or migrations, change schemas, or
delete development database data. A separate follow-up will use the model/database reference report
to scope those removals.

## Consequences

- Sphere no longer serves browser relying parties or end-user, organization, or corporate pages.
- Operator tools remain isolated on their configured hosts and retain their existing host names.
- Database connections, models, and migrations remain temporarily, including any with no current
  route caller, until the separate database/model decision.
- Current documentation and environment configuration must describe only the retained routes.

## Verification

The implementation spec is
[`specs/sphere-operator-tools-hard-reset/spec.md`](../specs/sphere-operator-tools-hard-reset/spec.md).
Route, controller-namespace, removal, database/model-reference, and gate results are recorded in its
scoped evidence record when implementation finishes.
