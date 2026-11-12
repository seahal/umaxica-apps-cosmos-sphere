# Public surface coverage follow-up

HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`  
The worktree contained extensive pre-existing uncommitted changes. They were preserved; this run
added one test file under `test/coverage/rp_authentication_public_round14/`.

## Changes and focused checks

- Added `foreign_issuer_anchor_rejection_test.rb`. It creates an RP session through the public
  callback committer, then verifies that public `RpRequestAuthenticator.call` rejects that stored
  session when its issuer differs from the active issuer. No private method is called and no schema
  is changed.
- Focused test plus existing authenticator tests and available authentication guards:
  `16 runs, 40 assertions, 0 failures, 0 errors, 0 skips`.
- `bin/rubocop test/coverage/rp_authentication_public_round14/foreign_issuer_anchor_rejection_test.rb`:
  passed.
- The instruction-listed `test/unit/security/ri_routing_contract_test.rb` is absent from this
  worktree; that guard could not be run. `forbidden_rails_patterns_test.rb` and
  `identity_authority_inversion_guard_test.rb` passed in the focused run.

## Full suite results

- `bun run test:coverage`: 34 files and 259 tests passed. Statements 355/355, branches 269/269,
  functions 110/110 and lines 352/352 (all 100%). 46 source files were fully covered and 28 empty
  files were skipped.
- `AUTH_JWT_ISSUER=auth-test-issuer RAILS_ENV=test COVERAGE=true PARALLEL_WORKERS=1 POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_rp_core_app_db,test_rp_warp_app_db,test_rp_palm_app_db,test_rp_core_org_db,test_rp_warp_org_db,test_chronicle_db,test_queue_db,test_storage_db bin/rails test`:
  1,802 runs, 12,839 assertions, 0 failures, 0 errors, 0 skips. SimpleCov exited 2 because its
  existing minimums (lines 98%, branches 93%, methods 97%) were not met. Measured coverage was:
  lines 9,066/9,319 (97.28%), branches 1,326/1,550 (85.54%), methods 1,497/1,592 (94.03%).

The required 99% Minitest target remains unmet. The current report has 253 uncovered lines, while
99% of 9,319 permits at most 93. Four concrete blocker files account for 108 uncovered lines:

- `app/controllers/concerns/redirects_signed_target_support.rb`: 44 private-only lines; no current
  production consumer was found.
- `lib/umaxica/test_environment/database_safety.rb`: 28 environment-construction lines, which
  repository guidance excludes from Minitest.
- `lib/jit_security_jwt_local_keyset_installer.rb`: 18 environment/key-installation lines, also
  excluded from Minitest environment-construction tests.
- `app/controllers/concerns/oidc_sso_initiator.rb`: 18 private lines for prompt/max-age
  normalization; the RP sign-in endpoint does not pass those values and sign-in was not redesigned.

These missed lines alone exceed the 99% line-coverage allowance. No coverage exclusions, threshold
changes, private-method tests, test-only routes, or production behavior changes were used to mask
the gap. The coverage objective remains open.
