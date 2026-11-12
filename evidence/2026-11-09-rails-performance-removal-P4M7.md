# Sphere Rails Revision, RailsDb, and Rails Performance Follow-up

Date: 2026-11-09 Revision: `44dfa264c91c58121e48800c6f2680464914e8c4` Worktree: existing uncommitted
changes affected the checks; no commit was created.

## 1. Route-separation test comparison

The final serial full-suite run before removing the development-only tools is recorded in
[`M8K2`](2026-11-09-sphere-route-separation-followup-M8K2.md): 13,321 runs, 97,804 assertions, 36
failures, 27 errors, and 0 skips. Against the 16,910-run baseline (300 failures, 67 errors), failure
names and exception classes produced 0 new failures and 0 new errors.

The complete failure/error inventory is outside the repository at
`/tmp/sphere-route-separation-full-test-final-v2-2026-11-09.md`; the machine-readable comparison is
`/tmp/sphere-route-separation-full-test-final-v2-2026-11-09.tsv`. Raw output was discarded.

## 2. RailsDb removal

`rails_db` was removed from the Gemfile and lockfile with `bundle install --local`. The lock update
removed `rails_db 2.5.0` and its now-unused `kaminari` family, `ransack`, and `simple_form`; no
other gem versions changed. The earlier lock backup SHA-256 was
`045fd71081b7c105749d848b5ab6595643144cb72344bded4ebad028a55f1213`; the post-RailsDb lock SHA-256
was `2d6be5a6e334460ec84c1937a58a45d3e713728d9cbabb5fa0e0189014431b76`.

The RailsDb engine invariant passed (5 runs, 17 assertions), as did controller inheritance (6 runs,
65 assertions). `RAILS_ENV=test bin/rails routes` exited successfully with no `/rails/db` or RailsDb
route matches. The `/rails/db` forbidden-path guard remains.

## 3. Rails Performance removal

Removed `rails_performance` from the Gemfile and development boot, its route draw, engine
initializer, copied route list, Valkey settings/accessor/responsibility, sanitizer and resilience
patches, and gem-specific tests. `/rails/performance` remains in `FORBIDDEN_MOUNT_PATHS`. The active
route draw list is `core`, `warp`, `palm`, `mission`, `flipper`, `blazer`, `pghero`, `swagger`, and
`coverband`.

Performance-only variables were removed from the writable `.env` and `.env.container.devcontainer`
files without printing their values. The public tool host entries in those files use the selected
Sphere naming rule. The root Compose comment and current architecture/docs were updated; no external
Cloudflare configuration or Valkey data was changed.

`bundle install --local` completed. Compared with the lock backup immediately before this step
(SHA-256 `2d6be5a6e334460ec84c1937a58a45d3e713728d9cbabb5fa0e0189014431b76`), the only removed specs
were `rails_performance 1.6.0` and its sole dependency `browser 6.2.0`. The only direct dependency
removed was `rails_performance`; no gem versions or sources changed. The resulting lock SHA-256 is
`16a2edc1f6fe1f9cf2b2547816e4ce3a6a9b6c8041e177c074e487ed4d6c3905`.

## Verification

- `RAILS_ENV=test bin/rails runner 'puts Rails.version'`: `8.2.0.alpha`.
- `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev bin/rails test test/security`: 107 runs, 621
  assertions, 0 failures, 0 errors, 0 skips.
- The focused mounted-engine invariant: 5 runs, 19 assertions, 0 failures, 0 errors.
- `test/integration/routes/surface_route_ownership_test.rb`: 2 runs, 13 assertions, 0 failures, 0
  errors.
- `bin/rubocop`: 4,327 files inspected, no offenses.
- `bin/rubocop Gemfile`: no offenses.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: exit 0.
- `git diff --check`: passed.
- `config/valkey.yml` parsed as valid YAML.
- `RAILS_ENV=development bin/rails routes`: exit 0; zero `performance` or `/rails/db` route matches.
- `RAILS_ENV=test` Rack requests to `/rails/db` and `/rails/performance` on `localhost`: HTTP 404
  for both.
- The retired performance hostname in development is rejected by HostAuthorization (HTTP 403). This
  prevents access, but does not meet the backlog's requested HTTP 404 for that hostname.

One initial security-suite run inherited the parent shell's old Flipper public hostname and reported
one failure (107 runs, 619 assertions):
`Security::Invariants::MountedEngineInvariantTest#test_every_mounted_Rack_app_is_reviewed_and_carries_its_own_authorization_guard`,
first repository line `test/security/invariants/mounted_engine_invariant_test.rb:115`. Re-running
with the explicitly selected Sphere hostname passed. The ignored local `.env` now contains the
selected public tool host values, but an exported parent-shell value takes precedence. The read-only
CI workflow still carries the old Flipper value.

## Development database reference data and remaining blockers

`primary` resolved. A direct PostgreSQL audit used `BEGIN READ ONLY` against the existing
`development_app_setting_db`, `development_com_setting_db`, `development_org_setting_db`, and
`development_chronicle_db`; each database has only two public base tables (migration metadata), and
all nine required reference tables are absent. Development route listing was run, but no schema
preparation, reference-data insert, or other development-database write was performed. Development
startup calls `ensure_defaults!` for these classes, so booting before owner-approved preparation
could write reference data.

On a later host-shell recheck, `primary` still resolved, but a direct read-only `psql` connection
could not authenticate because that shell had no password configured. No `.env*` file was read, no
credential value was emitted, and the failed connection made no database change; the inventory above
remains the latest successful database audit.

Required fixed IDs currently absent:

- `development_app_setting_db.app_preference_statuses`: IDs `0, 1` (2 rows).
- `development_com_setting_db.com_preference_statuses`: IDs `1, 2` (2 rows).
- `development_org_setting_db.org_preference_statuses`: IDs `1, 2` (2 rows).
- In `development_chronicle_db`, each of `app_preference_chronicle_levels`,
  `com_preference_chronicle_levels`, and `org_preference_chronicle_levels`: IDs `0, 1` (6 rows
  total).
- In `development_chronicle_db`, each of `app_preference_chronicle_events`,
  `com_preference_chronicle_events`, and `org_preference_chronicle_events`: IDs `1–14` (42 rows
  total).

That is 54 required reference rows across nine absent tables. The tables must first be prepared;
this evidence does not authorize schema or data writes. The missing-reference list is left for owner
approval. The development route set confirms the removed route is absent, and the test-environment
request returns 404; the retired development hostname itself returns 403 at HostAuthorization, not
404, so the old-host HTTP 404 criterion remains unmet.

`.github` and `.devcontainer` are read-only mounts in this workspace. Their CI performance variables
and Dev Container performance host aliases remain unedited. Cloudflare tunnel/DNS/Access records
remain untouched and require their separate owner approval. No credential values were read into
output or recorded.

## Final serial suite after both tool removals

`PARALLEL_WORKERS=1 PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev bin/rails test` completed with
13,317 runs, 97,788 assertions, 36 failures, 27 errors, and 0 skips. Compared with the pre-removal
inventory by test name and exception type, there were 0 new failure/error outcomes and 0 prior
outcomes missing from the current inventory. The sanitized failure/error list is saved outside the
repository at `/tmp/sphere-route-separation-full-test-post-tools-2026-11-09.md`; the raw test log
was deleted after extracting test names, exception classes, and first repository paths.
