# Public-surface coverage progress: Core API boundaries

HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`  
The worktree still contains extensive pre-existing uncommitted changes. This slice added tests only;
application code, coverage configuration, JavaScript, and CI remain unchanged.

## New coverage

- Added public HTTP checks for Core browser API negotiation: an omitted `Accept` header is served,
  and a JSON request body passes media-type negotiation before the refresh endpoint refuses it at
  the CSRF boundary.
- Focused `test/integration/core_browser_api_boundary_test.rb` passed:
  `15 runs, 61 assertions, 0 failures, 0 errors, 0 skips`.
- RuboCop on the four affected test files and `git diff --check` passed.
- `bun run test:coverage` passed: 34 files, 259 tests; statements 355/355, branches 269/269,
  functions 110/110, and lines 352/352 (100%).

## Full Minitest result

`AUTH_JWT_ISSUER=auth-test-issuer RAILS_ENV=test COVERAGE=true PARALLEL_WORKERS=1 POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_rp_core_app_db,test_rp_warp_app_db,test_rp_palm_app_db,test_rp_core_org_db,test_rp_warp_org_db,test_chronicle_db,test_queue_db,test_storage_db bin/rails test`

- Tests: `1,812 runs, 12,869 assertions, 0 failures, 0 errors, 0 skips`.
- SimpleCov still exits 2 at lines `9,076/9,319` (97.39%), branches `1,332/1,550` (85.94%), and
  methods `1,497/1,592` (94.03%). No Minitest assertion failed.
- The added API cases closed one configured branch. The suite still misses 243 lines, 218 branches,
  and 95 methods; 99% allows at most 93, 15, and 15 respectively.

## Constraint-bound remainder

Four source areas still account for 108 missed lines:

- `app/controllers/concerns/redirects_signed_target_support.rb`: 44 private-only lines and no
  current production consumer.
- `lib/umaxica/test_environment/database_safety.rb`: 28 environment-construction lines.
- `lib/jit_security_jwt_local_keyset_installer.rb`: 18 environment/key-installation lines.
- `app/controllers/concerns/oidc_sso_initiator.rb`: 18 private prompt/max-age paths not used by the
  RP sign-in flow.

The test-environment guidance forbids testing the two setup files; the other private paths have no
public/protected caller under the existing RP contract. The configured SimpleCov report counts 26
uncovered branches in the private-only signed-target concern, already above the 15-branch allowance.
The earlier progress note `2026-11-12-public-surface-coverage-followup-N4Q7.md` reported 50 raw zero
branch counters for that concern; that raw count included branches excluded by SimpleCov's
`ignore :implicit_else`, so 26 is the applicable configured metric. Both counts exceed the
allowance.

No private-method tests, environment-construction tests, exclusions, threshold changes, checker
disablement, or production-only-for-coverage changes were made. The coverage specification remains
open under the public/protected-only constraint.
