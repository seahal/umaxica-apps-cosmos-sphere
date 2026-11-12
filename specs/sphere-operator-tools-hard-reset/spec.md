# Cosmos Sphere Surface Hard Reset

Status: implementing (owner-approved 2026-11-10).

## Purpose

Leave this repository serving only its owner-designated surfaces while removing the foreign or
retired application surfaces and code that becomes unreachable. Retain Edit (org), Docs, News, Help,
Info, and the six operator tools. Retire the Auth, Base, Core, Palm, Tech, Visa, Warp, and GUID
controller/routes. The current owner-approved scope supersedes the earlier Sphere interpretation
that Docs, News, Help, Info, and Edit should transfer to Cosmos Press.

## Scope

- Remove routes, controllers, views, tests, and exclusive helpers/concerns for retired surfaces.
- Retain Docs, News, Help, and Info content routes on their app/com/org host groups; retain the Edit
  org publishing-management and relying-party routes.
- Retain the Mission, Flipper, Blazer, PgHero, Swagger, and Coverband operator-tool mounts.
- Remove host configuration, URL readers, environment entries, and current documentation for retired
  surfaces. Keep external host configuration still required by the retained Edit relying party.
- Remove newly dead services, values, jobs, policies, adapters, and concerns to a fixed point.
- Keep models, migrations, database schemas, and development database data unchanged. Produce a
  per-abstract-record database/model reference report for the follow-up removal step.
- Do not commit or perform external writes.

## Acceptance

- AC-1: `bin/rails routes` contains the retained content, Edit, operator-tool, and unknown-host
  routes; it contains no Auth, Base, Core, GUID, Palm, Tech, Visa, or Warp route.
- AC-2: No Auth, Base, Core, GUID, Palm, Tech, Visa, or Warp controller namespace remains. Docs,
  News, Help, Info, and Edit remain routed. Root infrastructure controllers remain only when a
  retained route or operator engine calls them.
- AC-3: No retired surface host entries or URL variables remain in runtime configuration,
  development host authorization, checked-in environment templates, Compose, or CI. Retained surface
  hosts remain authorized.
- AC-4: No newly dead non-model implementation remains after the consumer scan reaches a fixed
  point. Models and migrations are preserved and included in the database report.
- AC-5: `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
  `bundle exec erb_lint --lint-all`, and `bin/rails test` pass, with pre-existing failures
  identified separately.
- AC-6: The requested report and full-HEAD evidence record exist at
  `evidence/YYYY-MM-DD-surface-hard-reset-XXXX.md`; no database is dropped.

## Material Constraints

- Existing unrelated worktree changes are preserved and may affect verification results.
- Historical ADRs, evidence, and archive material retain their historical meaning; current docs are
  updated or superseded instead of rewriting that history.
- The canonical operator host names mentioned in route comments are inventory-only and are not
  changed by this work.
