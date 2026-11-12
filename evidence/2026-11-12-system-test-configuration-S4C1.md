# Rails system-test configuration

- Revision: `44dfa264c91c58121e48800c6f2680464914e8c4`.
- The worktree contained extensive pre-existing changes. This records source inspection and
  configuration edits only; no runtime result was established against the uncommitted tree.
- Inspected Cosmos Access's `test/application_system_test_case.rb`, package and lock entries, and
  `docs/operations/test-environment.md` as the reference.
- Added the corresponding Capybara/Playwright base class with an explicit `SYSTEM_TEST_HOST` instead
  of Access's Auth-only host. Preserved the single-worker guard and optional sandboxed system
  Chromium selection. Existing Ruby gems already supplied the driver and client.
- Added the Playwright JavaScript dependency and copied its two locked package records from Access.
  No dependency installation or lockfile regeneration command was run.
- Updated local/CI coverage selection to omit the explicit `test/` argument so future browser
  scenarios remain outside ordinary coverage execution. No automatic system-test job was added.
- Updated README and test documentation. No browser scenarios were added.
- Read the affected source and diff. At the user's configuration-only boundary, Rails, tests,
  linters, builds, browser provisioning, database preparation, and containers were not executed.
- Ruby client 1.64.0 / CLI 1.64.1 compatibility and actual browser execution remain unverified.
