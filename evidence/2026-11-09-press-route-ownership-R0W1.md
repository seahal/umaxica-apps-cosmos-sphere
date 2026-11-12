# Sphere: Cosmos Press route ownership

Date: 2026-11-09  
Revision: `44dfa264c91c58121e48800c6f2680464914e8c4`  
Worktree: uncommitted changes were present and affected verification. No commit was created.

## Result

Sphere no longer draws `edit`, `info`, `news`, `help`, `docs` or `guid`. The corresponding
controllers, views, route-specific tests and public `/api/v0/entries*` route/OpenAPI contract were
removed. The two Edit HTTP cases were also removed from the shared RP-cell readiness matrix because
they exercised the retired Edit `/dashboard` and `/sign/out` endpoints. OIDC client registration and
redirect values remain unchanged. The route-family absence assertion passes.

Sphere retains its Publishing database connection, schema, data, models, domain queries and the
Base-owned `/api/v0/publishing/*` API. Shared identifier processing and OIDC client registration and
redirect URI values remain. No database connection, schema or data was changed for this task. The
Press checkout was unavailable; this is not a claim that Press has deployed the routes.

## Verification

- `RAILS_ENV=test bin/rails runner 'puts Rails.version'` and the development equivalent both
  reported `8.2.0.alpha`.
- Focused route-removal checks covered default web rate limits, Tech's rejection of an Edit RP
  credential, Vite entrypoint/style inventory, mounted-engine authorization, architecture baseline,
  layout titles and RI routing: 44 runs, 3,053 assertions, 1 failure, 0 errors. The remaining
  `LayoutTitleContractTest` failure was also present in the earlier full-suite inventory.
- `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev bin/rails test` completed: 16,910 runs, 143,639
  assertions, 300 failures, 67 errors, 0 skips. The explicit host value matches the retained tool
  host while this process has an older exported value. The complete test-name,
  failure/exception-type and first repository-line inventory is outside the repository at
  `/tmp/sphere-press-full-test-failures-final.md`. It contains no assertion bodies or raw logs.
- Failure inventory comparison with the preceding full run shows three newly observed names in Base
  dashboard login, Secret audit delivery and DBSC header handling. None touches a removed route
  family. The test sets and seeds differ, so aggregate counts do not prove individual fixes.
- `bin/rails test test/integration/rp_cell_local_session_readiness_test.rb` after removing the two
  retired Edit cases: 18 runs, 70 assertions, 0 failures, 12 errors. Those errors originate at
  `test/support/fetch_metadata_defaults.rb:31`; the same non-Edit RP-cell errors were present in the
  earlier full-suite inventory.
- `bin/rails test test/contracts/openapi_route_coverage_test.rb:84`: 1 run, 6 assertions, 0
  failures, 0 errors; the retired route families have no route draws or controller routes.
- `bin/rubocop app lib config test Gemfile`: 5,374 files inspected, no offenses.
- `git diff --check`: passed.
- `bun run openapi:lint`: passed with one existing warning that `bearerToken` is unused in
  `openapi/app.yml`. `bun run openapi:bundle` updated the three generated bundles; a second bundle
  run produced identical hashes. `bun run openapi:verify` exits nonzero because the generated
  bundles intentionally differ from `HEAD` in this uncommitted change.
- `git grep`-equivalent route checks found no retired-family draws, no `/api/v0/entries` route or
  OpenAPI paths, and no remaining controller/view files under the retired families.
- `bin/rails architecture:baseline` regenerated the debt inventory after deleting files;
  `ArchitectureBaselineTest` passed in the focused run.

## Acceptance and limits

- AC-1 is verified for the Sphere route set.
- AC-2 remains open: the full suite completed but still has 300 failures and 67 errors. The earlier
  full run before route removal had 17,150 runs, 304 failures and 66 errors; the test sets differ
  because route-family tests were removed, so the counts are not directly comparable. The current
  inventory is the next-work baseline. It has complete failure/error names, exception types and
  first repository lines, with no remaining test names for the retired route families.
- No development database was created, reset or deleted; the test suite used test databases only. No
  external service was changed and no other repository was written. `.env*`, `.devcontainer/` and
  `compose*.yaml` were not read or changed for this route-removal slice.
