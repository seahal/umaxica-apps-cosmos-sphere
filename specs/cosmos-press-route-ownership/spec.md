# Cosmos Press Route Ownership

Status: superseded for this repository by
[the Sphere surface hard reset](../sphere-operator-tools-hard-reset/spec.md) (owner direction
2026-11-10).

## Superseding owner direction

The 2026-11-10 Sphere owner-approved scope keeps `edit.org`, `docs`, `news`, `help`, and `info` in
this repository. The route transfer proposed below is not the current Sphere contract. This file is
preserved as the prior proposal and provenance; it must not be used to remove the retained Sphere
routes.

The content subdomains `edit`, `info`, `news`, `help` and `docs` belong to
`umaxica-apps-cosmos-press`. This repository will stop drawing them and remove their controllers,
views and tests once nothing else uses that code.

Also decided on 2026-11-09 for all four repositories:

- `guid` is retired; this repository stops drawing it as well.
- This repository keeps and owns its `.dev` operator tools on `<tool>-<repository>.umaxica.dev`
  (Sphere uses `<tool>-sphere-jp.umaxica.dev`) as listed in
  `plans/2026-11-08-cloudflare-tunnel-split.md`. Sphere's separate 2026-11-10 owner decision removed
  `rails_performance`; its remaining tools are `mission`, `flipper`, `blazer`, `pghero`, `swagger`,
  and `coverband`. Access's settings are the reference for the other three repositories.

The full decision, observations, risks, acceptance and order are owned by the Press repository:
`specs/cosmos-press-route-ownership/spec.md` in `seahal/umaxica-apps-cosmos-press`.

Out of scope here: OIDC client registrations and redirect URIs, authentication and authorization
logic, database schemas, existing data and `config/database.yml` connections. Removing the
`publishing` connection is a separate later decision.

## Acceptance

- AC-1: This repository does not draw `edit`, `info`, `news`, `help`, `docs` or `guid`.
- AC-2: The application boots and its remaining test suite passes after the removal.

## Earlier Sphere GUID and operator-host slice (2026-11-09)

The earlier slice retired `guid` and updated the seven retained operator tools to
`<tool>-sphere-jp.umaxica.dev`. At that point, removal of `edit`, `info`, `news`, `help` and `docs`
remained deferred; the route-removal continuation below supersedes that status. Shared identifier
generation, persistent data, database connections, OIDC registrations and redirect values were
retained. Access comparison was waived because that checkout was unavailable.

The local `.github/` and `.devcontainer/` mounts were read-only. Corresponding CI/environment-alias
updates were prepared as an external patch and remain unapplied. The earlier evidence and
development-database blockers remain recorded in
[the GUID/tool-host evidence](../../evidence/2026-11-09-guid-retirement-tool-hosts-H7D2.md). Those
database operations are separate from this route-removal work.

## Sphere route-removal implementation (2026-11-09)

Sphere no longer draws `edit`, `info`, `news`, `help` or `docs`. Their controllers, views,
route-specific tests and public `/api/v0/entries*` routes and OpenAPI paths were removed. The
retired Edit HTTP cases were also removed from the shared RP-cell readiness test matrix; the OIDC
client registration remains. The focused route-family absence assertion passes.

Sphere retains the Publishing database connection, schema, data, models, domain queries and
Base-owned `/api/v0/publishing/*` API. Existing shared identifier processing and OIDC client
registration/redirect values remain. This work did not change database connections, schema or data.
The Press checkout was unavailable, so this records the Sphere-side removal and does not assert
Press deployment.

- AC-1: verified in the Sphere route set; no retired family is drawn or routed.
- AC-2: open. Test and development boot checks report Rails `8.2.0.alpha`, but the latest full suite
  completed with 16,910 runs, 143,639 assertions, 300 failures, 67 errors and 0 skips. The current
  failure/error names, exception types and first repository lines are in
  `/tmp/sphere-press-full-test-failures-final.md`. Compared with the prior inventory, the three
  newly observed test names concern Base dashboard login, Secret audit delivery and DBSC header
  behavior; none belongs to the retired route families. Test sets and runtime seeds differ, so the
  counts are not directly comparable.

Verification and current limitations are recorded in
[the route-removal evidence](../../evidence/2026-11-09-press-route-ownership-R0W1.md).
