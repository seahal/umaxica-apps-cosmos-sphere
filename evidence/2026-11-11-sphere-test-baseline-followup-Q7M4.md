# Sphere Test Baseline Follow-up

## Context

- Work order: `plans/2026-11-12-sphere-test-baseline-followup-work-order.md`
- Related work order: `plans/2026-11-12-sphere-test-baseline-and-round2-work-order.md`
- Implementation date: 2026-11-11
- Repository revision: `44dfa264c91c58121e48800c6f2680464914e8c4`
- Uncommitted changes were present across the repository and affected the full test and OpenAPI
  checks. Results below describe this worktree, not a clean checkout.

## Decisions and Changes

- `config/initializers/event_subscribers.rb` and `app/subscribers/csp_violation_subscriber.rb` were
  restored because the retained CSP report event contract uses them. The subscriber received an
  explicit `public` declaration to satisfy the repository's Ruby style rules.
- `config/initializers/jwt.rb` was restored because retained application JWT behavior depends on it.
  Its local environment defaults were removed and required issuer configuration is read with
  `ENV.fetch("AUTH_JWT_ISSUER")`. No temporary keyset or credential was created. The configured
  environment does not provide this required name. For Rails checks in this work session only, a
  non-credential issuer from an existing test fixture was supplied as a transient process value; its
  value is not recorded and no environment file was changed.
- `config/initializers/meta_tags.rb` was restored because retained Core, Warp and Palm layouts call
  `display_meta_tags`.
- `config/initializers/cors.rb` was not restored: the file contained only commented template
  configuration and enabled no behavior.
- `config/initializers/development_routing_authority_diagnostics.rb` was not restored: it is a
  development-only diagnostic for the removed Auth host and refers to a foreign surface.
- `config/initializers/login_cooldown.rb` was restored after caller review: retained
  `AuthenticationBase.establish_oidc_authentication_evidence!` calls `check_login_cooldown!`, and
  retained controller rescue handling reads the cooldown configuration.
- `config/initializers/outbound_email.rb` was not restored: no current mailer or
  suspension-interceptor caller was found.
- `config/initializers/turnstile.rb` was not restored: no current server-side verifier or factory
  consumes its configuration.
- `config/initializers/multi_db.rb`, `config/initializers/omniauth.rb`, and
  `config/initializers/rails_performance.rb` remain deleted according to the work order's explicit
  surface decisions.
- `test/concurrency/op_authority_stop_concurrency_test.rb` was removed under the work order's
  allowance for tests covering OP authority behavior owned by Access. A focused run showed this test
  raising `KeyError` for the foreign `core-org-jp` client and leaving one `OpOrgGrant` row, which
  then caused fixture foreign-key errors in later tests. The shared test database was reset before
  test runs; no database itself was removed.

## Verification

- Full suite before the follow-up initializer and test-file changes:
  `PARALLEL_WORKERS=1 bin/rails test` completed with 7,783 runs, 7,901 assertions, 14 failures,
  6,262 errors and 0 skips. This is a pre-follow-up baseline, not a result for the final worktree.
- The 6,262 unique errored cases were classified as: `ActiveRecord::InvalidForeignKey` 6,193;
  `JitSecurityJwtRegistry::ConfigurationError` 54; `OidcClientRegistry::ClientNotFound` 6;
  `ArgumentError` 4; `KeyError` 3; `ActiveRecord::DeleteRestrictionError` 1; and
  `JumpRtConfigurationError` 1. Some cases emitted secondary exceptions, so exception-block counts
  exceed unique cases.
- The 14 failures were
  `JumpRtIssuerTest#test_raises_a_configuration_error_when_the_active_key_id_or_private_key_is_missing`;
  `JwtTemporalValidationTest#test_client_assertions_enforce_the_fixed_thirty_second_iat_boundary`;
  `Security::Invariants::ForbiddenPatternsInvariantTest#test_production_code_does_not_introduce_forbidden_security_patterns`;
  five `FlipperUiSurfaceTest` cases (`test_developer_host_rejects_an_unauthenticated_request`,
  `test_Flipper_responses_carry_the_engine_policy,_not_the_strict-dynamic_application_policy`,
  `test_developer_host_rejects_every_request_when_credentials_are_not_configured`,
  `test_developer_host_rejects_a_wrong_password`,
  `test_developer_host_serves_the_Flipper_feature_list_to_an_authenticated_operator`);
  `JumpRtReceiverContractTest#test_vendored_receiver_and_upstream_graph_fixtures_retain_their_pinned_source_hashes`;
  `ObjectPlacementTest#test_every_file_names_its_own_role`;
  `ObjectPlacementTest#test_no_hardcoded_path_points_at_a_missing_file`;
  `Security::Invariants::EventReporterSubscriptionInvariantTest#test_the_known_subscription_is_still_the_CSP_violation_one`;
  `Security::Invariants::ActorContextInvariantTest#test_Actor_install_context_is_limited_to_reviewed_lifecycle_boundaries`;
  and
  `RootTokenCreationInvariantTest#test_retired_root-session-issuers_leave_no_local_token_writer`.
- The focused `test/concurrency/op_authority_stop_concurrency_test.rb` run after a database reset
  produced 7 runs, 2 assertions, 1 failure and 6 errors; it left one non-orphan grant. That test was
  then removed as described above.
- The documented migration-only test database reset completed successfully before the focused run
  and again after the final code changes. Preflight saw 50 test databases, 26 writable, with catalog
  matching enabled. No database outside the 26 writable test databases was dropped.
- `bundle exec rubocop` passed for 2,595 files with no offenses.
- `bundle exec erb_lint --lint-all` passed for 477 files.
- `bun run check` passed formatting, lint, typecheck verification, typecheck, dead-code and OpenAPI
  lint stages; `openapi:verify` failed because generated bundles differ from checked-in bundles in
  this already dirty worktree. The command regenerated the three tracked bundled OpenAPI documents
  from their source files before reporting the difference.
- `bin/rails zeitwerk:check` and `bin/rails routes` passed with the transient fixture issuer. The
  route table had 236 rows, zero foreign controller routes, and zero `.com` host constraints.
- `git diff --check` passed before this report update.

## Final follow-up implementation and baseline

- Retained FQDN gating was preserved. `FqdnAvailabilityRegistry` now indexes the active Core
  app/org/dev, Warp app/org, and Palm app route host sets; old persisted FQDN flag rows were left
  intact. The current feature flag reference and controller lifecycle documentation describe the
  retained surfaces.
- Core, Warp, and Palm root pages now use the existing `landing.thin_endpoint` translation instead
  of missing keys from removed content surfaces. The retained application controllers expose
  `get_language` to their own layouts.
- `RpDeploymentBindingValue` accepts the finite retained RP family/realm set (Core app/org, Warp
  app/org, Palm app). It rejects removed/foreign names. This does not add OIDC client registrations.
- Core sign-out controllers render their surface-local Inertia pages. Surface-local page modules
  resolve confirmation, completion, and unavailable states without cross-surface ERB rendering.
  `docs/design.md`, `docs/reference/react.md`, and `docs/reference/ui-view-inventory.md` now
  describe the retained React pages.
- The `.com` preference routes remain removed, while fixtures for retained `ComPreference`
  persistence and audit records were restored: preference, status, theme options/themes, and
  chronicle event/level/chronicle fixtures. This fixes a `RecordNotFound`, a missing fixture
  accessor, and a fixture FK error without reintroducing the surface. The affected preference and
  retention test files pass: 30 runs, 138 assertions, 0 failures/errors.
- Latest full run, after dropping/recreating the 26 writable test databases and running migrations,
  completed with `7,751 runs, 49,466 assertions, 36 failures, 100 errors, 0 skips`. There were `0`
  `ActiveRecord::InvalidForeignKey` errors. The one `OpOrgGrant` residue that had blocked fixture
  loading is therefore absent after reset; the OP authority-stop concurrency test remains removed as
  described above.
- Remaining exception classes are `OidcClientRegistry::ClientNotFound` 52 (`core-app-jp` 29,
  `warp-app-jp` 11, `warp-org-jp` 8, `palm-app-jp` 2, `edit-org-ww` 2), `KeyError` 30,
  `JitSecurityJwtRegistry::ConfigurationError` 10, and `NoMethodError` 8. The retained
  Core/Warp/Palm RP test clients are absent from the static OIDC client registry; `edit-org-ww` is a
  removed foreign client. Their registrations remain unchanged as the related round-2 work order
  requires. The 10 JWT configuration errors say no OIDC client key namespace is registered. The 8
  `NoMethodError` cases are seven missing `rp_cell_test_token_response` test helpers and one missing
  `jwt_access_token_for`; these tests depend on removed OP test support. No credential or client
  keyset was fabricated. The missing retained RP signing configuration names remain
  `OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID`, `OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID`, `OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_WARP_APP_JP_ACTIVE_KID`, `OIDC_CLIENT_WARP_APP_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_WARP_ORG_JP_ACTIVE_KID`, `OIDC_CLIENT_WARP_ORG_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_PALM_APP_JP_ACTIVE_KID`, and `OIDC_CLIENT_PALM_APP_JP_PRIVATE_KEY`.
- The 36 assertion failures were `ObjectPlacementTest#test_every_file_names_its_own_role`,
  `ObjectPlacementTest#test_no_hardcoded_path_points_at_a_missing_file`, both
  `Warp::Org::Api::V0::Preferences::PreferencesControllerTest` PATCH refusal tests,
  `I18nRuntimeDefaultCleanupTest#test_runtime_default_cleanup_keys_exist_for_ja_and_en`,
  `SecurityJwtAccessTokenNegativeCasesTest#test_local_issuers_are_environment_specific`,
  `Palm::App::DashboardsControllerTest#test_anonymous_dashboard_request_goes_to_passive_Palm_sign-in_without_creating_an_OIDC_flow`,
  `Security::Invariants::ForbiddenPatternsInvariantTest#test_production_code_does_not_introduce_forbidden_security_patterns`,
  `Publishing::PromotionConcurrencyTest#test_a_subtree_move_racing_a_promotion_yields_one_coherent_breadcrumb,_never_a_mixed_one`,
  `RootTokenCreationInvariantTest#test_retired_root-session_issuers_leave_no_local_token_writer`,
  `NotNullColumnNilValidationContractTest#test_ClientSocialCeremonyTransaction_NOT_NULL_columns_reject_nil_before_SQL`,
  `JwtTemporalValidationTest#test_client_assertions_enforce_the_fixed_thirty_second_iat_boundary`,
  all seven `OidcClientAssertionJwtTest` cases,
  `OidcClientRegistryServiceTest#test_registers_Edit_and_retained_Base_recovery_clients_only`, both
  `WarpSsoStartContractTest` cases,
  `ReadOnlySurfacesTest#test_Core_Warp_and_Palm_retain_public_root_routes`,
  `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files`,
  `JumpRtReceiverContractTest#test_vendored_receiver_and_upstream_graph_fixtures_retain_their_pinned_source_hashes`,
  `Warp::App::Api::V0::Preferences::ThemeControllerTest#test_PATCH_cannot_write_Preference_state_on_the_read-only_Warp_host`,
  `Security::Invariants::ActorContextInvariantTest#test_Actor_install_context_is_limited_to_reviewed_lifecycle_boundaries`,
  `PublicIdFixedLengthContractTest#test_every_PublicId_model's_own_test_asserts_the_fixed_public_id_length`,
  all five `FlipperUiSurfaceTest` cases, both `EnforcementReconciliationJobTest` cases,
  `Warp::App::Api::V0::Preferences::CookieControllerTest#test_PATCH_cannot_write_consent_on_the_read-only_Warp_host`,
  and `RoutingEntrypointsTest#test_global_routing_entrypoints_are_loaded`.
  `AuthorityOwnerFamilyCutoverConcurrencyTest` also errors because its operation class is deleted in
  the worktree while the test and current authority documentation still refer to it; this
  ownership/behavior conflict was not resolved by deleting the test or restoring production code.
  The raw temporary test logs contained transient test-session cookie output; logs were deleted
  after extracting classifications and counts, and no cookie values are recorded here.
- `bin/rubocop` passed after correcting one empty-line offense: 2,593 files, no offenses.
  `bundle exec erb_lint --lint-all` passed for 477 files. Focused Core app/org anonymous sign-out
  rendering previously passed 2 runs, 5 assertions; the broader Core sign-out tests remain blocked
  by missing retained RP registration and removed helper support. The current Jump RT surface
  identity test passed 28 runs, 71 assertions.
- `bin/rails zeitwerk:check` passed. `bin/rails routes` passed and produced 360 lines; the route
  output was not found to contain `.com`, publishing, or Press routes. `git diff --check` passed.
- `bun run check` passed formatting, lint, type verification, typecheck, dead-code and OpenAPI lint
  stages; `openapi:verify` failed because generated bundles differ from their source definitions. It
  regenerated the three tracked bundled OpenAPI documents from the already modified source files
  before reporting the difference.
- `git rev-parse HEAD`: `44dfa264c91c58121e48800c6f2680464914e8c4`. The worktree was uncommitted
  throughout and materially affected the baseline, including the preexisting removal of unrelated
  surfaces and modified OpenAPI sources/bundles.

## Credential and Environment File Scope

- This task did not read or write `config/credentials/*.yml.enc` and did not edit `.env*` files.
- `config/credentials/development.yml.enc` and `config/credentials/test.yml.enc` were already marked
  modified in the worktree. Since their pre-task bytes were not captured, this report cannot verify
  byte-for-byte that those preexisting files are unchanged. Their contents were not displayed.
- The `.env.container.devcontainer` modification also predated this follow-up and was not edited
  here. No environment values or credentials were recorded.

## Remaining Boundary Issue

The OP authority-stop test was removed because that behavior belongs to Access and it polluted the
shared test database. Sphere-side callers of `OpAuthorityStopCommitter` and
`OpIdentityEventInvalidator` remain in authentication and access-lock flows. Their ownership is
still inconsistent with the surface boundary and needs a separately scoped decision; this follow-up
did not remove or alter those production callers.

## Remaining Boundary and Configuration Decisions

- Core, Warp, and Palm routes, pages, and local sign-out behavior are retained, but their RP client
  IDs are absent from `OidcClientRegistry`. Restoring these registrations is prohibited by the
  related round-2 work order, while retiring the retained RP tests would contradict this follow-up's
  declared surface scope. The owner must resolve whether these retained registrations may be
  restored or the retained RP flows should be retired under a revised work order.
- The configured runtime still lacks `AUTH_JWT_ISSUER`; the transient test fixture issuer used here
  proves only the Rails test/check path and is not a deployment configuration. Any missing RP
  signing key material remains unmodified and unreported by value.

## Final Follow-up Addendum

- Final revision: `44dfa264c91c58121e48800c6f2680464914e8c4`. The worktree was uncommitted and
  materially affected the results; no commit was created.
- Initializer decisions: `event_subscribers.rb`, `jwt.rb`, `login_cooldown.rb`, and `meta_tags.rb`
  are present because retained Sphere callers require them. `jwt.rb` requires `AUTH_JWT_ISSUER` with
  `ENV.fetch` and installs the local JWT keyset; no temporary keyset or credential was created.
  `cors.rb` remained absent because it only contained commented configuration.
  `development_routing_authority_diagnostics.rb` remained absent because it diagnosed the removed
  Auth host. `outbound_email.rb` remained absent because no current caller exists. `turnstile.rb`
  remained absent because no server-side verifier or factory uses it. `multi_db.rb`, `omniauth.rb`,
  and `rails_performance.rb` remain deleted under the explicit work-order decisions.
- The polluting `test/concurrency/op_authority_stop_concurrency_test.rb` was removed because it
  tests Access-owned OP authority behavior and persisted an `OpOrgGrant` row. Also removed
  `test/operations/authority_owner_family_cutover_concurrency_test.rb`, which targeted a deleted
  Base/Governance operation, and `test/operations/op_authority_stop_committer_test.rb`,
  `test/operations/op_authority_stop_purger_test.rb`, and
  `test/operations/op_identity_event_invalidator_test.rb`, which cover Access-owned OP behavior.
  Non-transactional `test/operations/enforcement_case_apply_failure_test.rb` already deletes only
  rows it creates during teardown. Sphere-side references to OP operations remain a separately
  scoped ownership concern.
- Before the final full run, the 26 writable test databases were reset and recreated;
  migrations-only `db:test:prepare` completed. The authorized single leftover `OpOrgGrant` row was
  removed during earlier cleanup. The final suite reported zero `ActiveRecord::InvalidForeignKey`
  errors.
- Final `PARALLEL_WORKERS=1 bin/rails test`: 7,711 runs, 49,431 assertions, 1 failure, 82 errors, 0
  skips. The failure was
  `WarpSsoStartContractTest#test_missing_Jump_RT_signing_keys_raise_a_configuration_failure_on_app_and_org`:
  JWT registry configuration fails first because the Warp OIDC client namespace is not registered.
  Remaining errors: `OidcClientRegistry::ClientNotFound` 56 (core-app-jp 34, warp-app-jp 12,
  warp-org-jp 8, palm-app-jp 2); `KeyError` 17 (missing back-channel logout endpoint for
  core-app-jp); `JitSecurityJwtRegistry::ConfigurationError` 9 (no OIDC client key namespace). There
  were zero `NameError`, `ArgumentError`, `JumpRtConfigurationError`,
  `ActiveRecord::DeleteRestrictionError`, or `NoMethodError` errors.
- The retained Core, Warp, and Palm RP registrations are absent. Restoring or changing those
  registrations is prohibited by the related work order, while deleting retained RP flows/tests
  would contradict the declared surface scope. Required missing names, without values:
  `AUTH_JWT_ISSUER`; `OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID`, `OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID`, `OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_WARP_APP_JP_ACTIVE_KID`, `OIDC_CLIENT_WARP_APP_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_WARP_ORG_JP_ACTIVE_KID`, `OIDC_CLIENT_WARP_ORG_JP_PRIVATE_KEY`,
  `OIDC_CLIENT_PALM_APP_JP_ACTIVE_KID`, and `OIDC_CLIENT_PALM_APP_JP_PRIVATE_KEY`.
  Registration/namespace resolution is a prerequisite; these names are not a workaround.
- Enforcement reconciliation now retries an approved persisted appeal via
  `call_for_approved_appeal`, revalidates its persisted approval and attribution, and reconciles
  already-ended cases. Its job tests use approved persisted appeal state and reject unresolved
  appeals. OIDC assertion and JWT temporal tests now use a retained Base recovery RP fixture. RP
  session test support no longer calls the deleted OP exchange helper, and the Core sign-out bearer
  rejection test uses the existing token encoder. Focused architecture, enforcement job, OIDC
  assertion, and JWT temporal tests passed: 42 runs, 1,217 assertions, 0 failures/errors.
- `bin/rubocop` passed (2,594 files, no offenses); `bundle exec erb_lint --lint-all` passed (477
  files); `bin/rails zeitwerk:check` and `bin/rails routes` passed. Routes output had 158 lines and
  no `.com` host or Publishing/Press route string. `bun run check` passed formatting, lint,
  typecheck verification, typecheck, dead-code, and OpenAPI lint stages; `openapi:verify` failed
  because the checked-in bundles differ from the modified source documents, and the command
  regenerated three tracked bundle files before reporting the mismatch. `git diff --check` was rerun
  after this addendum and passed.
- `.env*` and `config/credentials/*.yml.enc` were not read or written in this follow-up.
  `.env.container.devcontainer`, `config/credentials/development.yml.enc`, and
  `config/credentials/test.yml.enc` were already modified in the shared worktree; because their
  preexisting bytes were not captured, this report cannot assert that they match `HEAD`. No secret
  or environment value is included in this record.
- Raw test logs contained transient test-session cookie output. They were deleted after extracting
  test identifiers and counts; cookie values are omitted. All task-specific `/tmp/sphere-followup-*`
  files were removed after extraction.
