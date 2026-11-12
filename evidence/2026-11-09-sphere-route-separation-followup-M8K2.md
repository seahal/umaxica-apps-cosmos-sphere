# Sphere Route Separation Follow-up

Date: 2026-11-09  
Revision: `44dfa264c91c58121e48800c6f2680464914e8c4`  
Worktree: existing uncommitted changes affected the run; no commit was created.

## Scope and result

Continued the Sphere route separation recorded in
[T4J8](2026-11-09-sphere-route-separation-T4J8.md). `config/routes.rb` draws `core`, `warp`, `palm`,
and the seven retained operations tools only. The Access database legacy authentication path
remains. Avatar SNS screens and migration of RP authentication to local-cell sessions remain
deferred.

The final serial full-suite run used `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev`,
`RAILS_ENV=test`, `PARALLEL_WORKERS=1`, seed `60280`:

- 13,321 runs, 97,804 assertions, 36 failures, 27 errors, 0 skips.
- Baseline: 16,910 runs, 300 failures, 67 errors.
- Compared by test name and exception class, all 36 failures and 27 errors are present in the
  baseline. New failures: 0. New errors: 0.
- Detailed failure/error names, exception classes, and first repository locations:
  `/tmp/sphere-route-separation-full-test-final-v2-2026-11-09.md`.
- Machine-readable comparison: `/tmp/sphere-route-separation-full-test-final-v2-2026-11-09.tsv`.
- Raw test output was discarded; no credentials, tokens, cookies, or personal data were retained.

The first full run exposed an unhandled OP token request in the Core smoke test after the Visa route
was removed. The test now uses a Faraday fake for the OP token endpoint, preserving the pre-existing
`Minitest::Assertion` result without sending network traffic. The Core smoke failure remains in the
baseline inventory. The retained `ApplicationHelper#get_language` method received a named explicit
visibility declaration; `test/tooling/architecture_baseline_test.rb` then passed (3 runs, 1,618
assertions).

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/security`: 107 runs, 625 assertions, 0 failures, 0 errors.
- `bin/rubocop` on the five touched Ruby files: no offenses.
- `git diff --check`: passed.
- Full `bin/rubocop` and Brakeman are scheduled for the final verification after the remaining
  requested dependency removals.

No development database, volume, or external service was changed.
