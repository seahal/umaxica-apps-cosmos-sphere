# Rails revision pin verification

Date: 2026-11-09. Repository: sphere. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`.

## Scope and worktree

Pinned Rails to `9ba8b1edeeacccb1ff5d2497432242eeddf48aed` in Gemfile with the requested
omniauth-rails_csrf_protection/config_delegate explanation. The lockfile already contained this
revision; its only change is `branch: main` to the explicit `ref`. An exact comparison against the
saved original confirmed no other lockfile bytes changed. No other gem versions or constraints
changed. No network install, bundle update, commit, database creation/reset, connection
configuration change, or write to another repository was performed.

Verification used uncommitted Gemfile and Gemfile.lock changes. Pre-existing changes in Compose
configuration, ADRs, development port documentation, a tooling test, plans and specs were preserved.
Results describe this dirty worktree; they are not a clean-HEAD baseline.

## Observed verification

- Runtime: Ruby 4.0.9 inside the existing Podman container (`podman-init` PID 1,
  `/run/.containerenv` present). `primary` resolved to `10.89.12.3`.
- `bundle install --local`: exit 0; 125 dependencies, 362 installed gems.
- `RAILS_ENV=test bin/rails runner 'puts Rails.version'`: exit 0, output `8.2.0.alpha`; no
  config_delegate load failure.
- `bin/rails test`: exit 1 during test loading, before any test executed.
  `ActiveRecord::NoDatabaseError`: `test_publishing_db` does not exist. First application repository
  frame: `test/test_helper.rb:51`.
- Authorized test preparation, `RAILS_ENV=test bin/rails db:test:prepare`: exit 1,
  `Umaxica::TestEnvironment::ConfigurationError`; 50 configured PostgreSQL test databases are
  missing. First application repository frame: `lib/umaxica/test_environment/database_safety.rb:77`.
- `bin/rubocop Gemfile`: exit 0; one file inspected, no offenses.
- `git diff --check`: exit 0.

## External artifacts and remaining blocker

Saved original lockfile: `/tmp/sphere-rails-revision-pin-R9P1/Gemfile.lock.before`. Test
failure/error inventory: `/tmp/sphere-rails-revision-pin-R9P1/failures-and-errors.md`. Full outputs
are in the same external directory as `rails-test.log`, `db-test-prepare.log`, `runner.log`,
`bundle-local.log` and `rubocop.log`. These temporary files are local artifacts and may not survive
environment cleanup.

Executed tests: 0. Minitest did not emit totals; assertion failure and per-test error counts and
test names are unavailable because collection aborted. The external inventory records both
command-level exceptions and locations. No application-test failure can be classified as
pre-existing from this attempt.

Rails pinning and boot acceptance are met. Full-suite completion and its baseline remain blocked by
absent test databases. Database creation requires the user's separate approval; no safety guard was
bypassed. After approved provisioning, repeat test preparation and the full test run, then replace
the incomplete baseline.
