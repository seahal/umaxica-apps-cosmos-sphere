# Sphere Route Separation Evidence

Date: 2026-11-09 Revision: `44dfa264c91c58121e48800c6f2680464914e8c4` Worktree: existing uncommitted
changes affected the run. No staged changes or commit were created.

## Scope and Result

- `config/routes.rb` draws only `core`, `warp`, `palm`, `mission`, `flipper`, `blazer`, `pghero`,
  `swagger`, `performance`, and `coverband`; the unknown-host route remains last.
- Removed 1,357 tracked files under `app/controllers` (777, including 114 concerns), `app/views`
  (76), `app/helpers` (5), and `test` (499). These were route-owned code and tests without a
  retained route caller, plus tests scoped solely to removed Base/Auth/Visa endpoints.
- Retargeted retained-surface tests for route ownership, regional roots, layout/Vite ownership, Jump
  JWKS publication, and controller lifecycle coverage. Kept shared Jump issuer identifiers.
- Did not move Avatar social pages or migrate RP authentication to the local-cell path.
  `BrowserRpAuthentication` and its legacy Access-database path are unchanged. Retained RP
  authentication, authorization, CSRF and callback ordering were not weakened.
- Existing user changes to TODO/FIXME markers, MessagePack, ADR/docs/plans, and development host
  configuration remain present. No other repository was written.

## Verification

- Test-mode boot: `RAILS_ENV=test bin/rails runner 'puts Rails.version'` printed `8.2.0.alpha`.
- Security suite: 107 runs, 625 assertions, 0 failures, 0 errors. The final post-retarget focused
  group, including `test/security`, completed with 139 runs, 1,922 assertions, 0 failures, and 0
  errors.
- Full serial suite command:

  ```sh
  PARALLEL_WORKERS=1 PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev RAILS_ENV=test bin/rails test
  ```

  Result: 13,321 runs, 96,354 assertions, 85 failures, 17 errors, 0 skips. The suite completed
  against the existing test databases; `primary` resolved in the dev-container environment.

- Baseline: 16,910 runs, 143,639 assertions, 300 failures, 67 errors, 0 skips. The test inventory
  changed substantially through removal of route-owned tests, so run totals are not directly
  comparable.
- Error comparison: all 17 current error test names occur in the baseline; 16 retain the same
  exception type. One retained Palm callback test changes from baseline `ArgumentError` to
  `ActiveRecord::RecordNotFound` at
  `test/controllers/palm/app/oidc/callbacks_controller_test.rb:62`. No new error test name was
  found. The Palm callback is on a retained route and its local-cell behavior remains deferred.
- Failure comparison: 36 records match baseline test name and exception, 10 baseline test names now
  fail with an assertion, and 39 failure names do not occur in the baseline. The new-name failures
  exercise retained RP/shared authentication behavior or the existing architecture baseline; none is
  a test dedicated only to a removed route. The complete list is
  `/tmp/sphere-route-separation-failure-metadata-2026-11-09.tsv` (kind, test name, exception, first
  repository line, baseline comparison).
- `bin/rubocop`: 4,332 files inspected, 0 offenses.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: 0 warnings, 0 errors.
- `git diff --check`: passed.

## Limits

- The full suite still has 85 failures and 17 errors. Their names and first repository lines are in
  the external TSV above; existing and deferred RP/local-cell behavior was not changed to force a
  green suite.
- No database settings, development databases, volumes, or external services were modified.
