# Public-surface coverage follow-up: verifier and callback boundaries

HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`  
The worktree contained extensive pre-existing uncommitted changes. This follow-up preserved them and
made localized test and evidence edits only. No production code, coverage configuration, JavaScript,
or CI files changed in this slice.

## Tests added or strengthened

- `test/coverage/values_services_adapters_lib_round2/jump_verifier_boundary_contract_test.rb`
  exercises `JumpRtReturnVerifier.call` with a misconfigured non-HTTPS JWKS origin. It asserts the
  verifier fails closed as `jwks_unavailable` before making an outbound request. The first run
  exposed an incorrect expected error (`invalid_signature`); the observed contract was
  `jwks_unavailable`, and the corrected focused suite passed.
- `test/coverage/controllers_round2/callback_requests_test.rb` now supplies a same-byte-length
  invalid OIDC issuer for its public callback request, exercising the equal-length issuer compare
  while preserving the existing rejection and no-exchange assertions. The browser callback matrix
  also verifies that a logged-out `sid` tombstone and an already-enrolled `sid` refuse to issue a
  new RP session.
- `test/services/rp_request_authenticator_test.rb` sends a valid Access token and live session
  through `RpRequestAuthenticator.call` after the referenced tombstone has lost its identity
  binding. The authenticator refuses the inconsistent session without returning a principal.
- `test/tooling/umaxica_architecture_cops_test.rb` uses RuboCop's public Commissioner runner to
  cover empty class bodies, receiver/dynamic-argument visibility declarations, unrelated blocks, and
  hook-like calls with arguments without calling cop private methods or adding a test helper.
- `test/coverage/runtime_values_round3/origin_contracts_test.rb` explicitly rejects an HTTPS origin
  using the exact `localhost` host through `ConfigValues.public_https_origin`.
- `test/coverage/controllers_round4/credential_failure_requests_test.rb` posts an invalid access
  cookie to the real Core logout endpoint and asserts an unauthorized response before any OP token
  revocation call.
- `test/services/jump_rt/return_policy_test.rb` checks through the public policy method that
  duplicate issuer origins raise `JumpRtConfigurationError` instead of selecting an ambiguous
  namespace.
- `test/lib/runtime_role_route_ownership_test.rb` exercises public `RuntimeRole.serves?` behavior
  with closed and invalid RP admission states. It confirms closed admission refuses browser routes
  while retaining health, revision, and back-channel routes, and that an unsupported state raises
  `RuntimeRole::UnknownRole`.
- `test/unit/security/observability_redactor_test.rb` verifies through the public redaction API that
  a non-HTTP URL containing user information is replaced with `[FILTERED]`.
- `test/values/rp_deployment_binding_value_test.rb` verifies through the public client-ID resolver
  that the registered `us` deployment region is accepted and an unsupported `eu` region raises
  `RpDeploymentBindingValue::UnknownRegion`.
- `test/coverage/oidc_client_runtime_round3/client_authority_and_local_origin_test.rb` exercises
  public client-key configuration validation with a public client and confirms the registry does not
  request a private signer for it.
- `test/models/concerns/retainable_test.rb` verifies through `valid?` that a negative-infinite
  creation timestamp fails validation even when the finite discard and purge deadlines are valid.
- `test/coverage/resolvers_and_auth_values_round5/redirect_target_public_boundaries_test.rb` covers
  public redirect-resolver rejection of an unescaped control character and an authority with user
  information but no host.
- `test/unit/jit/security/jwt/registry_test.rb` verifies through `reload!` that an RP process
  accepts public-only key material for a different cell while requiring its own client signer, and
  that only the explicit local policy permits duplicate `default` kids. Its registry fixture now
  pins OIDC client credential values to its supplied inputs to avoid ambient encrypted credentials
  changing those behavior tests.
- No test calls a private or protected method. There were no production changes in this slice, so no
  production red/green cycle was applicable; the initial focused assertion mismatch and its
  correction are recorded above.
- An exploratory callback case with a very large negative numeric `auth_time` returned 302 rather
  than rejection: Ruby `Time.at` represents that integer in this runtime. The case was removed; it
  did not establish an invalid-state boundary and no production change was made.
- An exploratory callback test tried to age the pending-flow timestamp in the integration test's
  post-response session object. That did not change the browser's encrypted session cookie, so the
  public callback correctly followed its original live flow; the test was removed. The normal flow
  also signs state with the same TTL and verifies that signature first, so a state token naturally
  expires no later than its pending entry. No private method or cookie implementation was used to
  force the branch.

## Verification

- Focused Jump verifier test: `7 runs, 59 assertions, 0 failures, 0 errors, 0 skips`.
- Focused callback test passed after adding the tombstone and already-enrolled cases; the combined
  callback and authenticator focused run passed with
  `10 runs, 186 assertions, 0 failures, 0 errors, 0 skips`.
- Focused architecture-cop tests: `18 runs, 35 assertions, 0 failures, 0 errors, 0 skips`.
- Focused origin contract tests: `6 runs, 106 assertions, 0 failures, 0 errors, 0 skips`.
- Focused logout credential tests: `3 runs, 24 assertions, 0 failures, 0 errors, 0 skips`.
- Focused Jump return policy tests: `23 runs, 109 assertions, 0 failures, 0 errors, 0 skips`.
- Focused runtime-role route ownership tests:
  `9 runs, 97 assertions, 0 failures, 0 errors, 0 skips`.
- Focused observability redactor tests: `15 runs, 36 assertions, 0 failures, 0 errors, 0 skips`.
- Focused RP deployment binding tests: `3 runs, 16 assertions, 0 failures, 0 errors, 0 skips`.
- Focused OIDC client authority and origin tests:
  `8 runs, 61 assertions, 0 failures, 0 errors, 0 skips`.
- Focused Retainable and redirect-target tests passed together:
  `26 runs, 161 assertions, 0 failures, 0 errors, 0 skips`.
- Focused JWT registry tests: `24 runs, 102 assertions, 0 failures, 0 errors, 0 skips`.
- After the exploratory callback case was removed, the focused callback suite was rerun and passed
  with the same result.
- Focused architecture-cop tests: `16 runs, 31 assertions, 0 failures, 0 errors, 0 skips`.
- RuboCop on the modified test files passed with no offenses; `git diff --check` passed.
- Full command:

  ```bash
  AUTH_JWT_ISSUER=auth-test-issuer RAILS_ENV=test COVERAGE=true PARALLEL_WORKERS=1 POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_rp_core_app_db,test_rp_warp_app_db,test_rp_palm_app_db,test_rp_core_org_db,test_rp_warp_org_db,test_chronicle_db,test_queue_db,test_storage_db bin/rails test
  ```

  The latest run completed with `1,828 runs, 12,971 assertions, 0 failures, 0 errors, 0 skips`. The
  command exited 2 because SimpleCov did not meet its current configured minimums (98% lines, 93%
  branches, 97% methods). Coverage was lines `9,081/9,319` (97.44%), branches `1,351/1,550`
  (87.16%), methods `1,497/1,592` (94.03%). Since the previous run, covered lines increased by 5,
  covered branches by 3, and covered methods stayed unchanged. The latest report has 238 missed
  lines, 199 missed branches, and 95 missed methods.

- Current Vitest verification: `bun run test:coverage` passed with 34 test files and 259 tests; all
  46 production files had 100% statements, branches, functions, and lines. Twenty-eight empty files
  were skipped by the reporter.

## Remaining constraint-bound minimum

The 99% threshold for each of the three Minitest metrics permits at most 93 missed lines, 15 missed
branches, and 15 missed methods at the measured totals. The following already-uncovered areas
account for 108 lines and 17 methods, exceeding both allowances before any other gaps are counted:

- `app/controllers/concerns/redirects_signed_target_support.rb`: 44 missed lines, 26 missed
  branches, and 8 missed methods; the concern has no current production consumer, so its private
  implementation has no public/protected caller to exercise.
- `lib/umaxica/test_environment/database_safety.rb`: 28 missed lines, 10 missed branches, and 2
  missed methods; this is test-environment construction, which the repository rules forbid testing
  from Minitest.
- `lib/jit_security_jwt_local_keyset_installer.rb`: 18 missed lines, 9 missed branches, and 5 missed
  methods; this installs local environment key material and is also environment construction.
- `app/controllers/concerns/oidc_sso_initiator.rb`: 18 missed lines; its uncovered prompt and
  max-age paths have no caller in the current RP sign-in flow; it has 18 missed branches and 2
  missed methods.

The signed-target concern alone has 26 missed branches, more than the 15-branch allowance. These
constraints make all three requested 99% Minitest metric thresholds unattainable with
public/protected tests alone, no coverage exclusions, no tests of environment construction, and no
production changes made solely to raise coverage. The specification remains open; the reachable
public test improvements continue, but this slice does not claim the target is met.

## Additional reachability check

- A public callback test temporarily removed `PORT` to explore the HTTPS-default branch. The request
  failed earlier in `OidcSsoInitiator#oidc_token_url`, where `OutboundHttp::LocalBackChannel` reads
  the required `PORT` with `ENV.fetch`; the test could not reach the callback branch and was
  removed. This preserves the configured environment contract and does not add an
  environment-construction test.
- One focused launch initially named only two databases in `POSTGRESQL_TEST_PREPARE_DATABASES`; the
  environment guard rejected that incomplete allowlist before loading tests. Rerunning with all nine
  verified writable test databases succeeded. No database was dropped or recreated by this focused
  test run.
