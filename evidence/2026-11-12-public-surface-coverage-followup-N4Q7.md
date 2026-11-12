# Public-surface coverage progress

HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`  
The worktree contained extensive pre-existing uncommitted changes. They were preserved. This slice
changed tests only; it did not change application code, coverage configuration, JavaScript, or CI.

## Added public-boundary coverage

- Extended `RedirectsJumpGatewayUrl.call` tests for malformed and hostless runtime gateway origins.
- Extended `CommonRedirect#redirect_to_jump_url` tests to verify that an unissuable target and a
  gateway refusal return an explicit 422 response without a redirect.
- Extended authentication-mode tests through the public `enforce_access_policy!` and
  `authenticated_page_response?` methods: default deny raises, guest mode admits an anonymous
  request and refuses an authenticated one, and bare mode is not treated as authenticated HTML.
- No test calls a private method. The tests specify existing behavior; no production behavior was
  changed.

## Verification

- Focused `RedirectsJumpGatewayUrlTest`: `8 runs, 27 assertions, 0 failures, 0 errors, 0 skips`.
- Focused public redirect tests: `5 runs, 30 assertions, 0 failures, 0 errors, 0 skips`.
- Focused authentication-mode tests: `5 runs, 16 assertions, 0 failures, 0 errors, 0 skips`.
- `bin/rubocop` on the three affected test files: passed, no offenses.
- Full Minitest command:
  `AUTH_JWT_ISSUER=auth-test-issuer RAILS_ENV=test COVERAGE=true PARALLEL_WORKERS=1 POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_rp_core_app_db,test_rp_warp_app_db,test_rp_palm_app_db,test_rp_core_org_db,test_rp_warp_org_db,test_chronicle_db,test_queue_db,test_storage_db bin/rails test`
  ran `1,810 runs, 12,862 assertions, 0 failures, 0 errors, 0 skips`. SimpleCov exited 2 because the
  configured thresholds were unmet: lines `9,076/9,319` (97.39%), branches `1,331/1,550` (85.87%),
  and methods `1,497/1,592` (94.03%).
- `bun run test:coverage`: passed, 34 files and 259 tests; statements 355/355, branches 269/269,
  functions 110/110, lines 352/352 (100%).
- One earlier full-suite attempt used two misspelled test database names and stopped at the
  environment's unverified-database guard before tests began. It made no database changes; the
  command above used the verified database list and completed.

## Remaining acceptance blocker

At the required 99%, line coverage can miss at most 93 of 9,319 lines; branch and method coverage
can each miss at most 15. The current report misses 243 lines, 219 branches, and 95 methods.

Four still-uncovered areas total 108 lines, already more than the entire line allowance:

- `app/controllers/concerns/redirects_signed_target_support.rb`: 44 private-only lines and no
  current production consumer.
- `lib/umaxica/test_environment/database_safety.rb`: 28 environment-construction lines; repository
  guidance forbids environment-construction tests.
- `lib/jit_security_jwt_local_keyset_installer.rb`: 18 environment/key-installation lines, subject
  to the same test restriction.
- `app/controllers/concerns/oidc_sso_initiator.rb`: 18 private prompt/max-age normalization lines
  not used by the RP sign-in flow; sign-in was not redesigned.

The private-only signed-target concern also has 50 uncovered branches, exceeding the 15-branch
allowance by itself. These are structural limits under the accepted public/protected-only and
no-environment-construction-test constraints, not failed behavior tests. No exclusion, threshold
change, checker disablement, private-method test, or production-only-for-coverage change was made.
The coverage specification remains open.
