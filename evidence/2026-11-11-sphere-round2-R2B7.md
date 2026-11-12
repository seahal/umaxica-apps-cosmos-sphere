# Sphere test baseline and round 2

## Revision and working tree

- `git rev-parse HEAD`: `44dfa264c91c58121e48800c6f2680464914e8c4`.
- The working tree contained extensive unrelated uncommitted changes. They were preserved and
  affected test and OpenAPI verification results; no commit was created.
- `config/credentials/development.yml.enc` and `config/credentials/test.yml.enc` were already
  reported modified in the working tree. This task did not read or write their contents. No initial
  hashes were recorded, so byte-for-byte identity against the start of the task cannot be proven.
- No `.env*` values, `.devcontainer/**`, migrations, OIDC client registrations, or Access/Base host
  readers were changed in this round.

## Test baseline and classification

The work order records the earlier baseline as 8,188 runs, 53 failures, and 3,851 errors. In the
current worktree, the parallel full run immediately after the prior surface recovery measured 7,897
runs, 27,431 assertions, 23 failures, and 3,715 errors. Its 3,568 foreign-key errors named three
constraints: `fk_op_org_grants_on_device_session_id` (2,381), `fk_rails_1ddf7a5a54` (1,177), and
`fk_rails_5146d3e196` (10).

A later full serial run, using a private temporary local JWT keyset that was removed after the run,
measured 7,806 runs, 30,804 assertions, 28 failures, 3,376 errors, and zero skips. Classification
from the test report:

- 3,217 error cases were `ActiveRecord::InvalidForeignKey` for
  `fk_op_org_grants_on_device_session_id`, raised during fixture setup.
- The other 159 error cases were: `JitSecurityJwtRegistry::ConfigurationError` 59, `KeyError` 37,
  `OidcClientRegistry::ClientNotFound` 34, `ArgumentError` 24, `JumpRtConfigurationError` 2,
  `NameError` 2, and `ActiveRecord::DeleteRestrictionError` 1.
- The two `NameError` cases named removed `EmailSignUpOtpIssueResult` and the removed
  `ExternalAuthentication::IdentityRepositoryFactory`. The obsolete result-inspection test was
  deleted; retained legacy identity cleanup now queries `ClientExternalIdentity` scoped by owner and
  provider.
- No missing translations or missing fixture files were reported. No tests were skipped.

The 28 assertion-failure identifiers from the serial run were:

- `RootTokenCreationInvariantTest#test_retired_root-session_issuers_leave_no_local_token_writer`
- `IdentityAuthenticationStopRecorderConcurrencyTest#test_Operator_stop_recording_rolls_back_the_epoch_if_event_insertion_fails`
- `JwtTemporalValidationTest#test_client_assertions_enforce_the_fixed_thirty_second_iat_boundary`
- `JumpRtReceiverContractTest#test_vendored_receiver_and_upstream_graph_fixtures_retain_their_pinned_source_hashes`
- `SecurityJwtAccessTokenNegativeCasesTest#test_production_boot_validation_rejects_development_and_test_issuers`
- `OidcClientRegistryServiceTest#test_registers_Edit_and_retained_Base_recovery_clients_only`
- `FlipperUiSurfaceTest` (five developer-host authentication and response-policy cases)
- `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files`
- `I18nRuntimeDefaultCleanupTest#test_runtime_default_cleanup_keys_exist_for_ja_and_en`
- `EventReporterSubscriptionInvariantTest#test_the_known_subscription_is_still_the_CSP_violation_one`
- `Jit::Security::Jwt::RegistryTest` (four registry/configuration cases; the two obsolete
  Auth-surface key tests were moved to Core, and the missing-origin case now tests non-local boot)
- `EnforcementReconciliationJobTest` (two approved-appeal reconciliation cases)
- `OpAuthorityStopConcurrencyTest` (Org and App rollback/idempotency cases)
- `JumpRtIssuerTest#test_raises_a_configuration_error_when_the_active_key_id_or_private_key_is_missing`
- `ActorContextInvariantTest#test_Actor_install_context_is_limited_to_reviewed_lifecycle_boundaries`
- `ObjectPlacementTest` (two placement/role cases)
- `ForbiddenPatternsInvariantTest#test_production_code_does_not_introduce_forbidden_security_patterns`
- `SignRiskOuterTransactionTest#test_org_risk_stop_inside_savepoint_waits_for_outer_rollback`

After that serial run, a read-only inspection found one `OpOrgGrant` in the shared test database and
no orphan at inspection time. The user authorized deletion of exactly that one row and one full
suite rerun. The row was deleted after a preflight confirmed the count was exactly one and no orphan
existed. The rerun below created one `OpOrgGrant` again; that newly created row remains untouched.
It is not an orphan. A further full-suite rerun requires a new authorization to delete exactly the
current row.

The authorized rerun (`PARALLEL_WORKERS=1 bin/rails test`) measured 7,783 runs, 20,953 assertions,
16 failures, 3,893 errors, and zero skips. Its 3,893 error cases were classified as: 3,772
`ActiveRecord::InvalidForeignKey`, 66 `JitSecurityJwtRegistry::ConfigurationError`, 20
`ArgumentError`, 16 `KeyError`, 14 `OidcClientRegistry::ClientNotFound`, 2
`JumpRtConfigurationError`, 2 `NameError`, and 1 `ActiveRecord::DeleteRestrictionError`. The
foreign-key errors again concern `fk_op_org_grants_on_device_session_id` during fixture setup; the
first affected cases are in `OpAuthorityStopConcurrencyTest`. The single retained grant was present
at the post-run read-only check, with its parent present and no orphan. The suite also persisted
this row during its run. The raw test log was kept outside the repository and removed after
classification.

The 16 assertion-failure identifiers were:

- `Security::Invariants::ForbiddenPatternsInvariantTest#test_production_code_does_not_introduce_forbidden_security_patterns`
- `Security::Invariants::EventReporterSubscriptionInvariantTest#test_the_known_subscription_is_still_the_CSP_violation_one`
- `I18nRuntimeDefaultCleanupTest#test_runtime_default_cleanup_keys_exist_for_ja_and_en`
- `JumpRtIssuerTest#test_raises_a_configuration_error_when_the_active_key_id_or_private_key_is_missing`
- `FlipperUiSurfaceTest#test_Flipper_responses_carry_the_engine_policy,_not_the_strict-dynamic_application_policy`
- `FlipperUiSurfaceTest#test_developer_host_rejects_every_request_when_credentials_are_not_configured`
- `FlipperUiSurfaceTest#test_developer_host_serves_the_Flipper_feature_list_to_an_authenticated_operator`
- `FlipperUiSurfaceTest#test_developer_host_rejects_an_unauthenticated_request`
- `FlipperUiSurfaceTest#test_developer_host_rejects_a_wrong_password`
- `JwtTemporalValidationTest#test_client_assertions_enforce_the_fixed_thirty_second_iat_boundary`
- `Security::Invariants::ActorContextInvariantTest#test_Actor_install_context_is_limited_to_reviewed_lifecycle_boundaries`
- `RootTokenCreationInvariantTest#test_retired_root-session_issuers_leave_no_local_token_writer`
- `ObjectPlacementTest#test_every_file_names_its_own_role`
- `ObjectPlacementTest#test_no_hardcoded_path_points_at_a_missing_file`
- `IdentityAuthenticationStopRecorderConcurrencyTest#test_Operator_stop_recording_rolls_back_the_epoch_if_event_insertion_fails`
- `JumpRtReceiverContractTest#test_vendored_receiver_and_upstream_graph_fixtures_retain_their_pinned_source_hashes`

After the full run, the Org concurrency test cleanup was reordered to remove its authority-stop,
grant, root and device-session records before deleting event receipts. This avoids an event cleanup
failure preventing the Org grant cleanup. The targeted RuboCop check and `git diff --check` pass;
the behavior has not been rerun because the latest shared-database row remains and its deletion is
outside the one-row authorization already used.

## Round 2 changes

- Removed the automatic database selector/resolver initializer and its test-only primary-selector
  support. Remaining `connected_to(role: :reading)` sites are listed below.
- Removed Google/Apple sign-up callback events and their legacy ceremony implementation/tests.
  Retained persisted identity and audit records, Apple notification history, and owner-scoped
  cleanup for existing identity rows. No OmniAuth gem or Apple client-secret provider remains.
- Removed obsolete OTP failure-budget code and the retired Auth/Base opaque admission and
  authorization-code Valkey stores. Removed the uncalled `BaseAuthAdmissionCoordinator` and its
  logger type reference. `SignOutNoticeStore` remains because RP sign-out and OIDC logout code still
  issues or consumes those notices.
- Removed the `preference_com` JWT registry/test path while retaining App/Org Preference JWTs,
  ComPreference models, and persisted data. The accepted ADR still documents `preference_com`; it
  was left untouched as required by the work order. The D-82 Base/Auth admission ADR is likewise
  unchanged. D-82 therefore remains an accepted cross-surface design while its former runtime
  implementation is absent from this Sphere tree; revising the ADR is outside the authorized scope.
  Current authentication-capacity and ceremony-boundary docs now state that these are
  historical/out-of-Sphere runtime descriptions.
- The registry test's stale Auth-surface cases now exercise Core's retained Jump keyset. The missing
  Visa Jump-origin check explicitly runs outside local mode, where local boot host resolution is not
  a valid substitute for required deployment configuration. The four registry failures in the
  earlier full run predate these test corrections.
- The source tree contains only `sign_out_notice_store.rb` under `app/services/valkey/auth_state/`;
  `rg` finds no removed coordinator/store references in `app/` or `test/`.

## Verification

- `bin/rails zeitwerk:check`: passed after the final service removal.
- `RAILS_ENV=test bin/rails routes`: exit 0, 158 route rows; no foreign `*.umaxica.*` or `.com` host
  matched. `config/routes/` contains `core.rb`, `warp.rb`, `palm.rb`, and the six operator-tool
  files only.
- `bin/rubocop`: passed, 2,592 files inspected, no offenses.
- `bundle exec erb_lint --lint-all`: passed, 477 files, no errors.
- `git diff --check`: passed after the final source edits and after the concurrency cleanup-order
  change.
- `bundle exec rubocop test/concurrency/op_authority_stop_concurrency_test.rb`: passed, one file, no
  offenses.
- `PARALLEL_WORKERS=1 bin/rails test test/unit/jit/security/jwt/registry_test.rb`: passed, 22 runs,
  91 assertions, zero failures/errors/skips.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign_up_state_machine_dispatch_test.rb`: passed,
  6 runs, 20 assertions, zero failures/errors/skips; the test declares no fixture tables.
- `bun run check`: failed only at `openapi:verify`. Formatting, lint, type checks, dead-code check,
  and OpenAPI lint completed; OpenAPI lint reported one unused `bearerToken` warning. The check's
  bundle step regenerated OpenAPI bundle files from already-uncommitted source changes, after which
  `git diff --exit-code` correctly reported a mismatch. OpenAPI files were not otherwise edited by
  this task and were not restored.
- The authorized full rerun failed with 16 failures and 3,893 errors as classified above. The
  post-run test-created shared row remains, so no further fixture-backed tests or full rerun were
  started.

## Remaining reading-role sites

- `app/controllers/concerns/authentication_base.rb:1703`
- `app/controllers/concerns/preference_browser_state_reader.rb:41,87,115`
- `app/controllers/concerns/preference_transport.rb:93`
- `app/queries/sign_up_stuck_registration_report_query.rb:223`
- `test/controllers/concerns/authentication/audit_writer_test.rb:198,211,262`
- `test/integration/solid_infrastructure_test.rb:49`
- `test/models/flow_expiry_commit_test.rb:37`
- `test/models/security_consumed_jti_test.rb:30`
- `test/operations/rp_callback_committer_test.rb:131`
- `test/operations/rp_cell_session_revoker_test.rb:54`
- `test/operations/rp_refresh_committer_test.rb:172`
- `test/operations/rp_refresh_logout_concurrency_test.rb:169`
- `test/services/rp_request_authenticator_test.rb:98`
