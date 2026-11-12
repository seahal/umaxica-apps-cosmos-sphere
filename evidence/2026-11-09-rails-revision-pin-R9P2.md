# Rails revision pin: completed baseline after approved database creation

Date: 2026-11-09. Sphere HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. This continues
[the initial blocked attempt](2026-11-09-rails-revision-pin-R9P1.md).

The user approved creating the missing test databases. Created exactly the 50 missing configured
`test_*` databases on the existing `primary:5432` target after `DatabaseSafety.verify!`. No
development database was changed or reset. Catalog verification then passed and
`RAILS_ENV=test bin/rails db:test:prepare` completed with exit 0, applying the existing migrations
without importing schema receipts. The standard test runner subsequently prepared its disposable
replica/worker copies.

`bin/rails test` completed with exit 1 and seed 53009 in 1106.375637 seconds:

```text
17164 runs, 149621 assertions, 302 failures, 67 errors, 0 skips
```

All 369 failure/error entries were extracted and reconciled with these totals. Each entry has its
test name, exception type (`Minitest::Assertion` for failures), and first reported application
repository location. The complete inventory is outside the repository:
`/tmp/sphere-rails-revision-pin-R9P1/failures-and-errors.md`. Full output:
`/tmp/sphere-rails-revision-pin-R9P1/rails-test-approved.log`. Preparation and creation output:
`db-test-prepare-approved.log` and `create-databases.log` in the same directory. Temporary artifacts
may be removed by environment cleanup.

The test run used the uncommitted Rails pin and the previously recorded dirty worktree. It finished
before the subsequent GUID retirement/tool-host edits. The Rails revision already matched the
requested revision before the pin, so the lockfile change remained solely `branch` to `ref`; no gem
version changed. `RAILS_ENV=test bin/rails runner 'puts Rails.version'` had succeeded with
`8.2.0.alpha`. `bin/rubocop Gemfile` and `git diff --check` had passed.

Application failures were left unchanged. This is the observed next-work baseline, not a claim that
each failure was independently reproduced before this session. No commit, connection-target change
or write to another repository was performed.
