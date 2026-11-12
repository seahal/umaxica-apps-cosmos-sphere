# Sphere Surface Recovery Evidence

Date: 2026-11-11  
HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`  
Worktree: uncommitted changes affected implementation and verification. The pre-existing worktree
contained extensive uncommitted edits; no commit was made.  
Task: `plans/2026-11-11-sphere-surface-recovery-work-order.md`

## Outcome

The repository routes Core app/org/net/dev, Warp app/org, Palm app, and the six named operator
tools. Warp has no `.com` route. `config/routes/` contains `core.rb`, `warp.rb`, `palm.rb`, and
`mission.rb`, `flipper.rb`, `blazer.rb`, `pghero.rb`, `coverband.rb`, `swagger.rb`.
`app/controllers/` contains only `core`, `warp`, `palm`, and `concerns` directories plus shared
top-level files. The current `README.md` describes those Sphere surfaces.

Direct recovery restored 435 paths that had been deleted from the worktree and are present in the
final state. Foreign-surface removal deleted 191 controller/concern paths, 59 view/style paths, 50
test/support paths, and five route files. A further 27 E2E files for retired or unconfigured
surfaces were removed. The controller and test agents removed exclusive code and support after
checking callers. Models, migrations, schema files, credentials, Compose, and `.devcontainer/**`
were preserved. `.env*` files had URL-variable rows removed only; values were never read into the
report. A comparison confirmed `.devcontainer/**` and root Compose files are unchanged by this work.

README troubleshooting and acknowledgement text now describes the explicit per-surface WebAuthn RP
configuration rather than deriving origins from the external authentication-service URL. Current
test-location documentation lists the surviving Minitest and Vitest suites; closed browser-test
specifications remain historical.

The following existing OIDC integration host readers remain because Core, Warp, and Palm use the
external Access authority and Base recovery RP contract. They do not register local foreign routes.
The model inventory retains foreign-owned models as required and does not authorize deleting their
databases.

## Verification

- `bin/rails zeitwerk:check`: passed (`All is good!`).
- `bin/rails routes`: passed. The application route inventory and
  `Security::PublicEntrypointInventoryTest` confirm no Docs, Edit, Help, Info, News, Auth, Visa,
  Base, Tech, GUID, Performance, or `.com` application surface routes.
- `bin/rubocop`: passed, 2,754 files inspected, no offenses.
- `bundle exec erb_lint --lint-all`: passed, 477 files, no errors.
- Frontend Vitest: passed, 45 files / 507 tests. Vite test-mode build passed.
- `bun run check`: format, lint, typecheck, dead-code, OpenAPI lint, and bundle generation ran.
  `openapi:verify` failed because the existing uncommitted OpenAPI source and bundled-file changes
  do not match the HEAD comparison. OpenAPI files were already modified before this task and are
  outside its surface scope.
- Focused route/security/registry suite:
  `bin/rails test test/integration/routes/core_route_contract_test.rb test/integration/routes/warp_route_contract_test.rb test/unit/security/public_entrypoint_inventory_test.rb test/values/oidc_client_registry_test.rb`
  passed: 23 tests, 304 assertions.
- Full `bin/rails test`: completed with 8,188 tests, 26,844 assertions, 53 failures, 3,851 errors, 0
  skips. The dominant error occurs during global fixture loading: `ActiveRecord::InvalidForeignKey`
  for `op_org_grants` referencing a missing `operator_device_sessions` row. A second observed
  instance was an `operator_capability_grants` row referencing a missing operator. Fixture triage
  confirmed `operators.yml` and `operator_device_sessions.yml` exist in both HEAD and the worktree;
  neither was removed by this change. No `op_org_grants.yml` or `operator_capability_grants.yml`
  fixture exists in HEAD or the worktree. This makes retained test-database rows a plausible source,
  but does not prove it. `bin/rails db:test:prepare` completed, but does not clear existing test
  data; retesting after it produced the same fixture failure. The work order prohibits dropping
  databases, so test database data was not reset. The focused tests that do not load the global
  fixture set pass. The full-suite failures cannot be reliably classified as caused by this change
  versus the pre-existing modified test/database state.
- A one-worker reproduction,
  `PARALLEL_WORKERS=1 bin/rails test test/models/operator_step_up_commit_test.rb`, failed before
  assertions while loading fixtures with the same `op_org_grants` foreign-key error (2 errors, 0
  assertions). Read-only `bin/rails runner -e test` counts confirmed one retained `OpOrgGrant` row
  linked to an `operator_device_sessions` row that is not part of that table's two declared fixture
  rows. The operator device-session table has a fixture set, while `op_org_grants` has no fixture
  file. No row values were read or changed. This confirms retained test-database state is involved
  in the fixture-loading conflict. Its origin predates the current read and cannot be established
  from this worktree.

## Surface hosts

- Core: `www-jp.umaxica.app` and `www-jp.umaxica.org`; local app/org/net/dev hosts are
  `core.*.localhost`.
- Warp: `warp-jp.umaxica.app` and `warp-jp.umaxica.org`; local app/org hosts are `warp.*.localhost`.
- Palm: `palm-jp.umaxica.app`; local app host is `palm.app.localhost`.
- Operator tools: Mission, Flipper, Blazer, PgHero, Coverband, and Swagger, constrained to their
  operator hosts.

## Restored paths

These are the final paths restored from HEAD after the erroneous deletion. Paths absent from the
final worktree are excluded.

- `app/adapters/mcp_liveness_tool.rb`
- `app/adapters/mcp_service_info_tool.rb`
- `app/adapters/mcp_version_tool.rb`
- `app/controllers/concerns/auth_io_keys.rb`
- `app/controllers/concerns/authentication_base.rb`
- `app/controllers/concerns/authentication_bulletin_gate.rb`
- `app/controllers/concerns/authentication_client.rb`
- `app/controllers/concerns/authentication_cookie_name.rb`
- `app/controllers/concerns/authentication_cookie_service.rb`
- `app/controllers/concerns/authentication_cookie_store.rb`
- `app/controllers/concerns/authentication_current_resource_resolver.rb`
- `app/controllers/concerns/authentication_device_binding.rb`
- `app/controllers/concerns/authentication_jwks_rendering.rb`
- `app/controllers/concerns/authentication_jwt_tokens.rb`
- `app/controllers/concerns/authentication_logout_all_sessions.rb`
- `app/controllers/concerns/authentication_logoutable.rb`
- `app/controllers/concerns/authentication_operator.rb`
- `app/controllers/concerns/authentication_redirects.rb`
- `app/controllers/concerns/authentication_sequence_gate.rb`
- `app/controllers/concerns/authentication_token.rb`
- `app/controllers/concerns/authentication_token_service.rb`
- `app/controllers/concerns/authentication_withdrawal_gate.rb`
- `app/controllers/concerns/authorization_client.rb`
- `app/controllers/concerns/browser_navigation_request.rb`
- `app/controllers/concerns/core_browser_api_boundary.rb`
- `app/controllers/concerns/dbsc_canonical_url.rb`
- `app/controllers/concerns/mcp_endpoint.rb`
- `app/controllers/concerns/preference_browser_api.rb`
- `app/controllers/concerns/preference_browser_state_reader.rb`
- `app/controllers/concerns/preference_web_cookie_actions.rb`
- `app/controllers/concerns/preference_web_cookie_endpoint.rb`
- `app/controllers/concerns/preference_web_theme_actions.rb`
- `app/controllers/concerns/preference_web_theme_endpoint.rb`
- `app/controllers/concerns/redirects_signed_target_support.rb`
- `app/controllers/concerns/robots.rb`
- `app/controllers/concerns/session_boundary_not_found.rb`
- `app/controllers/concerns/sign_in_welcome_gate.rb`
- `app/controllers/concerns/sign_out_inertia_pages.rb`
- `app/controllers/concerns/sitemap.rb`
- `app/controllers/concerns/step_up_ceremony_logging.rb`
- `app/controllers/concerns/surface_chrome.rb`
- `app/controllers/concerns/surface_inertia_page.rb`
- `app/controllers/concerns/verification_base.rb`
- `app/controllers/concerns/verification_client.rb`
- `app/controllers/concerns/verification_operator.rb`
- `app/controllers/concerns/verification_step_up_guard.rb`
- `app/controllers/concerns/warp_dashboard_page.rb`
- `app/controllers/concerns/warp_settings_page.rb`
- `app/controllers/core/app/api/v0/base_controller.rb`
- `app/controllers/core/app/api/v0/healths_controller.rb`
- `app/controllers/core/app/api/v0/preferences/cookies_controller.rb`
- `app/controllers/core/app/api/v0/preferences/themes_controller.rb`
- `app/controllers/core/app/api/v0/revisions_controller.rb`
- `app/controllers/core/app/api/v0/sessions_controller.rb`
- `app/controllers/core/app/api/v0/token/refreshes_controller.rb`
- `app/controllers/core/app/application_controller.rb`
- `app/controllers/core/app/bare_controller.rb`
- `app/controllers/core/app/csp_violation_reports_controller.rb`
- `app/controllers/core/app/health/livenesses_controller.rb`
- `app/controllers/core/app/health/readinesses_controller.rb`
- `app/controllers/core/app/health/startups_controller.rb`
- `app/controllers/core/app/healths_controller.rb`
- `app/controllers/core/app/oidc/callbacks_controller.rb`
- `app/controllers/core/app/oidc/closures_controller.rb`
- `app/controllers/core/app/revisions_controller.rb`
- `app/controllers/core/app/roots_controller.rb`
- `app/controllers/core/app/sign/entries_controller.rb`
- `app/controllers/core/app/sign/interruptions_controller.rb`
- `app/controllers/core/app/sign/outs_controller.rb`
- `app/controllers/core/app/well_known/jwks_controller.rb`
- `app/controllers/core/dev/api/v0/healths_controller.rb`
- `app/controllers/core/dev/api/v0/revisions_controller.rb`
- `app/controllers/core/dev/bare_controller.rb`
- `app/controllers/core/dev/csp_violation_reports_controller.rb`
- `app/controllers/core/dev/health/livenesses_controller.rb`
- `app/controllers/core/dev/health/readinesses_controller.rb`
- `app/controllers/core/dev/health/startups_controller.rb`
- `app/controllers/core/dev/healths_controller.rb`
- `app/controllers/core/dev/revisions_controller.rb`
- `app/controllers/core/dev/roots_controller.rb`
- `app/controllers/core/net/api/v0/healths_controller.rb`
- `app/controllers/core/net/api/v0/revisions_controller.rb`
- `app/controllers/core/net/bare_controller.rb`
- `app/controllers/core/net/csp_violation_reports_controller.rb`
- `app/controllers/core/net/health/livenesses_controller.rb`
- `app/controllers/core/net/health/readinesses_controller.rb`
- `app/controllers/core/net/health/startups_controller.rb`
- `app/controllers/core/net/healths_controller.rb`
- `app/controllers/core/net/revisions_controller.rb`
- `app/controllers/core/net/roots_controller.rb`
- `app/controllers/core/org/api/v0/base_controller.rb`
- `app/controllers/core/org/api/v0/healths_controller.rb`
- `app/controllers/core/org/api/v0/preferences/cookies_controller.rb`
- `app/controllers/core/org/api/v0/preferences/themes_controller.rb`
- `app/controllers/core/org/api/v0/revisions_controller.rb`
- `app/controllers/core/org/api/v0/sessions_controller.rb`
- `app/controllers/core/org/api/v0/token/refreshes_controller.rb`
- `app/controllers/core/org/application_controller.rb`
- `app/controllers/core/org/bare_controller.rb`
- `app/controllers/core/org/csp_violation_reports_controller.rb`
- `app/controllers/core/org/health/livenesses_controller.rb`
- `app/controllers/core/org/health/readinesses_controller.rb`
- `app/controllers/core/org/health/startups_controller.rb`
- `app/controllers/core/org/healths_controller.rb`
- `app/controllers/core/org/oidc/callbacks_controller.rb`
- `app/controllers/core/org/oidc/closures_controller.rb`
- `app/controllers/core/org/revisions_controller.rb`
- `app/controllers/core/org/roots_controller.rb`
- `app/controllers/core/org/sign/entries_controller.rb`
- `app/controllers/core/org/sign/interruptions_controller.rb`
- `app/controllers/core/org/sign/outs_controller.rb`
- `app/controllers/core/org/well_known/jwks_controller.rb`
- `app/controllers/palm/app/api/v0/healths_controller.rb`
- `app/controllers/palm/app/api/v0/revisions_controller.rb`
- `app/controllers/palm/app/application_controller.rb`
- `app/controllers/palm/app/bare_controller.rb`
- `app/controllers/palm/app/csp_violation_reports_controller.rb`
- `app/controllers/palm/app/dashboards_controller.rb`
- `app/controllers/palm/app/health/livenesses_controller.rb`
- `app/controllers/palm/app/health/readinesses_controller.rb`
- `app/controllers/palm/app/health/startups_controller.rb`
- `app/controllers/palm/app/healths_controller.rb`
- `app/controllers/palm/app/oidc/callbacks_controller.rb`
- `app/controllers/palm/app/oidc/closures_controller.rb`
- `app/controllers/palm/app/revisions_controller.rb`
- `app/controllers/palm/app/robots_controller.rb`
- `app/controllers/palm/app/roots_controller.rb`
- `app/controllers/palm/app/sign/entries_controller.rb`
- `app/controllers/palm/app/sign/interruptions_controller.rb`
- `app/controllers/palm/app/sign/out/completions_controller.rb`
- `app/controllers/palm/app/sign/outs_controller.rb`
- `app/controllers/palm/app/sitemaps_controller.rb`
- `app/controllers/palm/app/well_known/jwks_controller.rb`
- `app/controllers/warp/app/api/v0/healths_controller.rb`
- `app/controllers/warp/app/api/v0/preferences/cookies_controller.rb`
- `app/controllers/warp/app/api/v0/preferences/themes_controller.rb`
- `app/controllers/warp/app/api/v0/revisions_controller.rb`
- `app/controllers/warp/app/application_controller.rb`
- `app/controllers/warp/app/bare_controller.rb`
- `app/controllers/warp/app/csp_violation_reports_controller.rb`
- `app/controllers/warp/app/dashboards_controller.rb`
- `app/controllers/warp/app/health/livenesses_controller.rb`
- `app/controllers/warp/app/health/readinesses_controller.rb`
- `app/controllers/warp/app/health/startups_controller.rb`
- `app/controllers/warp/app/healths_controller.rb`
- `app/controllers/warp/app/mcps_controller.rb`
- `app/controllers/warp/app/oidc/callbacks_controller.rb`
- `app/controllers/warp/app/oidc/closures_controller.rb`
- `app/controllers/warp/app/revisions_controller.rb`
- `app/controllers/warp/app/robots_controller.rb`
- `app/controllers/warp/app/roots_controller.rb`
- `app/controllers/warp/app/settings_controller.rb`
- `app/controllers/warp/app/sign/entries_controller.rb`
- `app/controllers/warp/app/sign/interruptions_controller.rb`
- `app/controllers/warp/app/sign/outs_controller.rb`
- `app/controllers/warp/app/sitemaps_controller.rb`
- `app/controllers/warp/app/well_known/jwks_controller.rb`
- `app/controllers/warp/org/api/v0/healths_controller.rb`
- `app/controllers/warp/org/api/v0/preferences/cookies_controller.rb`
- `app/controllers/warp/org/api/v0/preferences/themes_controller.rb`
- `app/controllers/warp/org/api/v0/revisions_controller.rb`
- `app/controllers/warp/org/application_controller.rb`
- `app/controllers/warp/org/bare_controller.rb`
- `app/controllers/warp/org/csp_violation_reports_controller.rb`
- `app/controllers/warp/org/dashboards_controller.rb`
- `app/controllers/warp/org/health/livenesses_controller.rb`
- `app/controllers/warp/org/health/readinesses_controller.rb`
- `app/controllers/warp/org/health/startups_controller.rb`
- `app/controllers/warp/org/healths_controller.rb`
- `app/controllers/warp/org/mcps_controller.rb`
- `app/controllers/warp/org/oidc/callbacks_controller.rb`
- `app/controllers/warp/org/oidc/closures_controller.rb`
- `app/controllers/warp/org/revisions_controller.rb`
- `app/controllers/warp/org/robots_controller.rb`
- `app/controllers/warp/org/roots_controller.rb`
- `app/controllers/warp/org/settings_controller.rb`
- `app/controllers/warp/org/sign/entries_controller.rb`
- `app/controllers/warp/org/sign/interruptions_controller.rb`
- `app/controllers/warp/org/sign/outs_controller.rb`
- `app/controllers/warp/org/sitemaps_controller.rb`
- `app/controllers/warp/org/well_known/jwks_controller.rb`
- `app/errors/already_authenticated_error.rb`
- `app/errors/blank_public_identifier_error.rb`
- `app/helpers/session_timestamp_helper.rb`
- `app/lib/dpop_proof_verifier.rb`
- `app/lib/sign_in_flow_binding_codec.rb`
- `app/operations/acme_refresh_token_issuer.rb`
- `app/policies/sign_in/sequence_policy.rb`
- `app/queries/step_up_bootstrap_eligibility_query.rb`
- `app/resolvers/post_authentication_routing_resolver.rb`
- `app/resolvers/redirects_navigation_target_resolver.rb`
- `app/resolvers/sign_entry_sentry_resolver.rb`
- `app/resolvers/step_up_methods_resolver.rb`
- `app/serializers/dbsc_header_serializer.rb`
- `app/serializers/health_status_serializer.rb`
- `app/services/auth_authorization_header.rb`
- `app/services/base_auth_admission_coordinator.rb`
- `app/services/core_browser_credential_contract.rb`
- `app/services/csp_violation_report_intake.rb`
- `app/services/dbsc_verification_service.rb`
- `app/services/dpop_nonce_service.rb`
- `app/services/dpop_request_verifier.rb`
- `app/services/sign_in_checkpoint_participant.rb`
- `app/services/sign_in_cycle_locator.rb`
- `app/services/sign_in_guardrail_participant.rb`
- `app/services/sign_in_selector_participant.rb`
- `app/services/sign_in_sequence_carrier.rb`
- `app/values/authentication_epoch_value.rb`
- `app/values/dbsc_header_parser.rb`
- `app/values/logout_result.rb`
- `app/values/mcp_surface_identity.rb`
- `app/values/preference_browser_controls_registry.rb`
- `app/values/preference_write_result.rb`
- `app/values/sign_in_result.rb`
- `app/views/core/app/.keep`
- `app/views/core/dev/.keep`
- `app/views/core/dev/roots/index.html.erb`
- `app/views/core/net/.keep`
- `app/views/core/org/.keep`
- `app/views/layouts/core/app/application.html.erb`
- `app/views/layouts/core/app/inertia.html.erb`
- `app/views/layouts/core/org/application.html.erb`
- `app/views/layouts/core/org/inertia.html.erb`
- `app/views/layouts/palm/app/application.html.erb`
- `app/views/layouts/palm/app/inertia.html.erb`
- `app/views/layouts/shared/_cloudflare_turnstile_api.html.erb`
- `app/views/layouts/warp/app/application.html.erb`
- `app/views/layouts/warp/app/inertia.html.erb`
- `app/views/layouts/warp/org/application.html.erb`
- `app/views/layouts/warp/org/inertia.html.erb`
- `app/views/palm/app/sitemaps/show.xml.builder`
- `app/views/pwa/offline.html.erb`
- `app/views/pwa/service-worker.js`
- `app/views/shared/ui/_button.html.erb`
- `app/views/shared/ui/_presentation_labels.html.erb`
- `app/views/warp/app/sitemaps/show.xml.builder`
- `app/views/warp/org/sitemaps/show.xml.builder`
- `config/initializers/inertia_rails.rb`
- `config/routes/core.rb`
- `config/routes/palm.rb`
- `config/routes/warp.rb`
- `gait/components/chrome/cookie_banner.test.tsx`
- `gait/components/chrome/theme_controls.test.tsx`
- `gait/components/confirm_dialog.test.tsx`
- `gait/components/ui/button.test.tsx`
- `gait/components/ui/choice.test.tsx`
- `gait/components/ui/dialog.test.tsx`
- `gait/components/ui/document_locale.test.tsx`
- `gait/components/ui/error_list.test.tsx`
- `gait/components/ui/links.test.tsx`
- `gait/components/ui/nav_list.test.tsx`
- `gait/components/ui/page.test.tsx`
- `gait/components/ui/select.test.tsx`
- `gait/components/ui/text_field.test.tsx`
- `gait/controllers/application.test.ts`
- `gait/controllers/cookie_banner_controller.test.ts`
- `gait/controllers/cookie_consent_controller.test.ts`
- `gait/controllers/cookie_toggle_controller.test.ts`
- `gait/controllers/history_back_controller.test.ts`
- `gait/controllers/index.test.ts`
- `gait/controllers/otp_resend_controller.test.ts`
- `gait/controllers/passkey_ceremony.test.ts`
- `gait/controllers/passkey_registration_controller.test.ts`
- `gait/controllers/step_up_passkey_controller.test.ts`
- `gait/controllers/theme_controller.test.ts`
- `gait/controllers/theme_toggle_controller.test.ts`
- `gait/controllers/turnstile_controller.test.ts`
- `gait/controllers/unsaved_changes_controller.test.ts`
- `gait/controllers/webauthn_utils.test.ts`
- `gait/entrypoints/inertia.test.ts`
- `gait/entrypoints/theme_cookie.test.ts`
- `gait/features/auth/passkeys/webauthn.test.ts`
- `gait/features/auth/session/sign_out_interaction.test.tsx`
- `gait/features/auth/session/sign_out_screens.test.tsx`
- `gait/features/dashboards/warp_dashboard.test.tsx`
- `gait/features/dashboards/warp_settings.test.tsx`
- `gait/features/landing/surface_root_landing.test.tsx`
- `gait/features/ui_gallery/ui_gallery.test.tsx`
- `gait/layouts/surface_layout.test.tsx`
- `gait/lib/cookies.test.ts`
- `gait/lib/csrf.test.ts`
- `gait/lib/payload.test.ts`
- `gait/lib/request.test.ts`
- `gait/lib/theme.test.ts`
- `gait/lib/turnstile.test.ts`
- `gait/pwa/register.test.ts`
- `gait/setup.ts`
- `gait/support/ceremony.ts`
- `gait/support/dom.ts`
- `gait/support/events.ts`
- `gait/support/http.ts`
- `gait/support/present.ts`
- `gait/support/stimulus.ts`
- `gait/support/webauthn.ts`
- `src/components/ConfirmDialog.tsx`
- `src/components/chrome/CookieBanner.tsx`
- `src/components/chrome/ThemeControls.tsx`
- `src/components/ui/Button.tsx`
- `src/components/ui/ButtonLink.tsx`
- `src/components/ui/Card.tsx`
- `src/components/ui/Checkbox.tsx`
- `src/components/ui/DescriptionList.tsx`
- `src/components/ui/Dialog.tsx`
- `src/components/ui/DocumentLocale.tsx`
- `src/components/ui/ErrorList.tsx`
- `src/components/ui/NavList.tsx`
- `src/components/ui/Page.tsx`
- `src/components/ui/RadioGroup.tsx`
- `src/components/ui/Select.tsx`
- `src/components/ui/Table.tsx`
- `src/components/ui/TextField.tsx`
- `src/components/ui/TextLink.tsx`
- `src/components/ui/buttonStyles.ts`
- `src/controllers/application.ts`
- `src/controllers/cookie_banner_controller.ts`
- `src/controllers/cookie_consent_controller.ts`
- `src/controllers/cookie_toggle_controller.ts`
- `src/controllers/history_back_controller.ts`
- `src/controllers/index.ts`
- `src/controllers/otp_resend_controller.ts`
- `src/controllers/passkey_ceremony.ts`
- `src/controllers/passkey_registration_controller.ts`
- `src/controllers/step_up_passkey_controller.ts`
- `src/controllers/theme_controller.ts`
- `src/controllers/theme_toggle_controller.ts`
- `src/controllers/turnstile_controller.ts`
- `src/controllers/unsaved_changes_controller.ts`
- `src/controllers/webauthn_utils.ts`
- `src/entrypoints/application.ts`
- `src/entrypoints/core/dev.ts`
- `src/entrypoints/inertia/core_app.tsx`
- `src/entrypoints/inertia/core_org.tsx`
- `src/entrypoints/inertia/palm_app.tsx`
- `src/entrypoints/inertia/warp_app.tsx`
- `src/entrypoints/inertia/warp_org.tsx`
- `src/entrypoints/palm/app.ts`
- `src/entrypoints/react_islands.tsx`
- `src/entrypoints/warp/app.ts`
- `src/entrypoints/warp/org.ts`
- `src/features/auth/SurfaceDashboard.tsx`
- `src/features/auth/passkeys/invisibleTurnstile.ts`
- `src/features/auth/passkeys/webauthn.ts`
- `src/features/auth/session/SignOutCompleted.tsx`
- `src/features/auth/session/SignOutConfirmation.tsx`
- `src/features/auth/session/SignOutUnavailable.tsx`
- `src/features/dashboards/WarpDashboard.tsx`
- `src/features/dashboards/WarpSettings.tsx`
- `src/features/identity/CredentialWarning.tsx`
- `src/features/landing/RootLanding.tsx`
- `src/features/ui_gallery/UiGallery.tsx`
- `src/inertia/surface.ts`
- `src/layouts/SurfaceLayout.tsx`
- `src/lib/cookies.ts`
- `src/lib/csrf.ts`
- `src/lib/payload.ts`
- `src/lib/request.ts`
- `src/lib/step_up_challenge.ts`
- `src/lib/theme.ts`
- `src/lib/turnstile.ts`
- `src/pages/core/app/roots/index.tsx`
- `src/pages/core/org/roots/index.tsx`
- `src/pages/palm/app/.gitkeep`
- `src/pages/palm/app/dashboards/show.tsx`
- `src/pages/palm/app/roots/index.tsx`
- `src/pages/palm/app/sign/outs/complete.tsx`
- `src/pages/palm/app/sign/outs/edit.tsx`
- `src/pages/palm/app/sign/outs/unavailable.tsx`
- `src/pages/warp/app/.gitkeep`
- `src/pages/warp/app/dashboards/show.tsx`
- `src/pages/warp/app/roots/index.tsx`
- `src/pages/warp/app/settings/show.tsx`
- `src/pages/warp/app/sign/outs/complete.tsx`
- `src/pages/warp/app/sign/outs/edit.tsx`
- `src/pages/warp/app/sign/outs/unavailable.tsx`
- `src/pages/warp/org/.gitkeep`
- `src/pages/warp/org/dashboards/show.tsx`
- `src/pages/warp/org/roots/index.tsx`
- `src/pages/warp/org/settings/show.tsx`
- `src/pages/warp/org/sign/outs/complete.tsx`
- `src/pages/warp/org/sign/outs/edit.tsx`
- `src/pwa/register.ts`
- `src/styles/surfaces/core_app.css`
- `src/styles/surfaces/core_dev.css`
- `src/styles/surfaces/core_org.css`
- `src/styles/surfaces/palm_app.css`
- `src/styles/surfaces/warp_app.css`
- `src/styles/surfaces/warp_org.css`
- `src/theme_cookie.ts`
- `src/types/browser-globals.d.ts`
- `src/types/globals.d.ts`
- `src/types/inertia.ts`
- `test/controllers/core/app/jwks_controller_test.rb`
- `test/controllers/core/app/roots_controller_test.rb`
- `test/controllers/core/app/sign/outs_controller_test.rb`
- `test/controllers/core/bff_surface_smoke_test.rb`
- `test/controllers/core/dev/roots_controller_test.rb`
- `test/controllers/core/org/jwks_controller_test.rb`
- `test/controllers/core/org/roots_controller_test.rb`
- `test/controllers/core/org/sign/outs_controller_test.rb`
- `test/controllers/core/route_naming_test.rb`
- `test/controllers/core/web_edge_surface_smoke_test.rb`
- `test/controllers/palm/app/dashboards_controller_test.rb`
- `test/controllers/palm/app/oidc/callbacks_controller_test.rb`
- `test/controllers/palm/app/oidc_boundary_test.rb`
- `test/controllers/palm/app/roots_controller_test.rb`
- `test/controllers/palm/app/sign/out/completions_controller_test.rb`
- `test/controllers/palm/app/sign/outs_controller_test.rb`
- `test/controllers/warp/app/api/v0/preferences/cookie_controller_test.rb`
- `test/controllers/warp/app/api/v0/preferences/theme_controller_test.rb`
- `test/controllers/warp/app/dashboards_controller_test.rb`
- `test/controllers/warp/app/roots_controller_test.rb`
- `test/controllers/warp/app/settings_controller_test.rb`
- `test/controllers/warp/app/sign/outs_controller_test.rb`
- `test/controllers/warp/org/api/v0/preferences/preferences_controller_test.rb`
- `test/controllers/warp/org/dashboards_controller_test.rb`
- `test/controllers/warp/org/roots_controller_test.rb`
- `test/controllers/warp/org/settings_controller_test.rb`
- `test/controllers/warp/org/sign/outs_controller_test.rb`
- `test/integration/core_access_refusal_refresh_retention_test.rb`
- `test/integration/core_browser_api_boundary_test.rb`
- `test/integration/core_browser_api_surfaces_test.rb`
- `test/integration/core_browser_origin_boundary_test.rb`
- `test/integration/core_rp_browser_flow_test.rb`
- `test/integration/core_rp_cookie_surface_contract_test.rb`
- `test/integration/palm_jump_sign_entry_test.rb`
- `test/integration/routes/core_route_contract_test.rb`
- `test/integration/routes/palm_route_contract_test.rb`
- `test/integration/routes/warp_route_contract_test.rb`
- `test/integration/warp_sso_start_contract_test.rb`
- `test/security/invariants/core_route_host_source_invariant_test.rb`
- `test/support/inertia_page_object.rb`
- `test/support/oidc_state_test_support.rb`
- `test/support/rp_cell_sign_out_helper.rb`
- `test/unit/core_browser_credential_contract_test.rb`
- `vitest.config.ts`
- `README.md (restored from HEAD, then rewritten for Sphere surfaces)`
- `AGENTS.md (restored from HEAD)`

## Database/model reference inventory

The static source scan classified 765 persisted model classes across 22 abstract-record database
owners. `USED` means a production non-model reference; `ONLY-VIA-MODELS` means references only from
other models/associations; `UNUSED` means neither was found. The scan excludes tests, fixtures,
migrations, locales, and historical docs. It is conservative: dynamic/polymorphic references and
framework conventions can be missed, and comments can create false positives. No model, migration,
schema, or database was removed.

# Sphere model reference inventory

Static source snapshot during uncommitted Sphere surface recovery. No models, migrations or
databases were changed.

`USED` means an explicit model constant occurs in production non-model code under app/, lib/ or
config/. `ONLY-VIA-MODELS` means a constant or statically inferred association appears only in other
model files (including concerns). `UNUSED` means neither was found. Tests, fixtures, migrations,
locale data and historical documents are excluded from use classification. Comments may cause
conservative false positives; polymorphic associations, relative constants inside nested namespaces,
indirect framework conventions and dynamic resolution can cause false negatives. Abstract alias
Record classes are grouped under their inherited connection owner. This is a review inventory, not
authorization to remove databases or models.

## AppSettingRecord — `app_setting`

| Status          | Count |
| --------------- | ----: |
| USED            |    27 |
| ONLY-VIA-MODELS |     2 |
| UNUSED          |     0 |

| Model                                 | Status          | Reference examples                                                                                                                    |
| ------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `AppPreference`                       | USED            | `app/values/security_jwt_preference_token_codec.rb`, `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/preference_base.rb` |
| `AppPreferenceAdultContentGate`       | ONLY-VIA-MODELS | `app/models/app_preference.rb`, `app/models/app_preference_adult_content_gate_option.rb`                                              |
| `AppPreferenceAdultContentGateOption` | ONLY-VIA-MODELS | `app/models/app_preference_adult_content_gate.rb`                                                                                     |
| `AppPreferenceBrowserBinding`         | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `AppPreferenceConsentReceipt`         | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `AppPreferenceCookie`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceCurrency`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceCurrencyOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceDateFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceDateFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceDensity`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceDensityOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceLanguage`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceLanguageOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceMotion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceMotionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferencePageSize`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferencePageSizeOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceRegion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceRegionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceStatus`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb`                       |
| `AppPreferenceTheme`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceThemeOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceTimeFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceTimeFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceTimezone`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceTimezoneOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `AppPreferenceWebPush`                | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `AppPreferenceWebPushOption`          | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |

## AppSignalRecord — `app_signal`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     1 |
| UNUSED          |     0 |

| Model                      | Status          | Reference examples                                     |
| -------------------------- | --------------- | ------------------------------------------------------ |
| `ClientNotificationRecord` | USED            | `app/services/retention_cross_database_child_purge.rb` |
| `MemberNotification`       | ONLY-VIA-MODELS | `app/models/client_notification_record.rb`             |

## AppZenithRecord — `app_zenith`

| Status          | Count |
| --------------- | ----: |
| USED            |    64 |
| ONLY-VIA-MODELS |    47 |
| UNUSED          |     3 |

| Model                                       | Status          | Reference examples                                                                                                                                                               |
| ------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AppEnforcementAppeal`                      | USED            | `app/jobs/enforcement_reconciliation_job.rb`                                                                                                                                     |
| `AppEnforcementAuthenticationMethodEffect`  | ONLY-VIA-MODELS | `app/models/app_enforcement_case.rb`                                                                                                                                             |
| `AppEnforcementCase`                        | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/enforcement_case_end_operation.rb`, `app/operations/client_secret_credential_purger.rb`                         |
| `AppEnforcementIdentifierEffect`            | ONLY-VIA-MODELS | `app/models/app_enforcement_case.rb`                                                                                                                                             |
| `AppEnforcementPrincipalEffect`             | ONLY-VIA-MODELS | `app/models/app_enforcement_case.rb`                                                                                                                                             |
| `AppEnforcementPrincipalLink`               | ONLY-VIA-MODELS | `app/models/app_enforcement_case.rb`                                                                                                                                             |
| `AppIdentityAuthenticationEvent`            | USED            | `app/operations/op_identity_event_invalidator.rb`, `app/operations/identity_authentication_stop_recorder.rb`, `app/jobs/op_identity_event_delivery_job.rb`                       |
| `Client`                                    | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`     |
| `ClientAccount`                             | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                               |
| `ClientAppleNotificationEvent`              | ONLY-VIA-MODELS | `app/models/client_external_identity.rb`, `app/models/client.rb`                                                                                                                 |
| `ClientAuthorityLock`                       | USED            | `app/operations/enterprise_creator.rb`, `app/operations/client_persona_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                         |
| `ClientBanner`                              | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientBulletin`                            | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientContactAuditOutbox`                  | USED            | `app/jobs/contact_audit_delivery_job.rb`                                                                                                                                         |
| `ClientEmail`                               | USED            | `app/operations/email_identifier_purger.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/services/identifier_hmac_emergency_rotation.rb`                       |
| `ClientEmailHistory`                        | ONLY-VIA-MODELS | `app/models/client.rb`, `app/models/concerns/email_dead_identifier_history.rb`                                                                                                   |
| `ClientEmailStatus`                         | USED            | `app/services/sign_up_artifact_cleanup.rb`, `app/queries/sign_up_stuck_registration_report_query.rb`, `app/queries/step_up_bootstrap_eligibility_query.rb`                       |
| `ClientEnforcementRecoveryCeremony`         | USED            | `app/operations/enforcement_case_end_operation.rb`                                                                                                                               |
| `ClientExternalIdentity`                    | USED            | `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/services/sign_up_artifact_cleanup.rb`, `app/queries/authentication_credential_inventory.rb`                        |
| `ClientIdentifierRotationAudit`             | UNUSED          |                                                                                                                                                                                  |
| `ClientIdentity`                            | USED            | `app/operations/client_persona_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                             |
| `ClientIdentityState`                       | USED            | `app/operations/client_persona_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                             |
| `ClientMember`                              | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberDeletion`                      | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberDiscovery`                     | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberImpersonation`                 | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberObservation`                   | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberRevocation`                    | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMemberSuspension`                    | ONLY-VIA-MODELS | `app/models/member.rb`, `app/models/client.rb`                                                                                                                                   |
| `ClientMembership`                          | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientMfaStatus`                           | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientOidcIdentityBinding`                 | ONLY-VIA-MODELS | `app/models/client_identity.rb`                                                                                                                                                  |
| `ClientPasskey`                             | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/services/sign_up_artifact_cleanup.rb`                |
| `ClientPasskeyAuditOutbox`                  | USED            | `app/jobs/passkey_audit_delivery_job.rb`                                                                                                                                         |
| `ClientPasskeyStatus`                       | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/services/sign_up_artifact_cleanup.rb`                |
| `ClientPersona`                             | USED            | `app/operations/client_persona_creator.rb`, `app/resolvers/avatar_permission_resolver.rb`, `app/resolvers/avatar_access_grant_resolver.rb`                                       |
| `ClientPersonaAdministrationGrant`          | ONLY-VIA-MODELS | `app/models/client_persona.rb`, `app/models/client.rb`                                                                                                                           |
| `ClientPersonaAuthorityCutover`             | USED            | `app/queries/authority_owner_migration_inventory.rb`                                                                                                                             |
| `ClientPersonaDelegationGrant`              | ONLY-VIA-MODELS | `app/models/client_persona.rb`, `app/models/client.rb`                                                                                                                           |
| `ClientPersonaLifecycle`                    | USED            | `app/operations/client_persona_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                 |
| `ClientPersonaOwnership`                    | USED            | `app/operations/client_persona_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                 |
| `ClientPersonaOwnershipTransferRequest`     | ONLY-VIA-MODELS | `app/models/client_persona.rb`                                                                                                                                                   |
| `ClientPersonaUsageGrant`                   | ONLY-VIA-MODELS | `app/models/client_persona.rb`, `app/models/client.rb`                                                                                                                           |
| `ClientPersonaViewGrant`                    | ONLY-VIA-MODELS | `app/models/client_persona.rb`, `app/models/client.rb`                                                                                                                           |
| `ClientPreference`                          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceAdultContentGate`          | ONLY-VIA-MODELS | `app/models/client_preference.rb`, `app/models/client_preference_adult_content_gate_option.rb`                                                                                   |
| `ClientPreferenceAdultContentGateOption`    | ONLY-VIA-MODELS | `app/models/client_preference_adult_content_gate.rb`                                                                                                                             |
| `ClientPreferenceCurrency`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceCurrencyOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceDateFormat`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceDateFormatOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceDensity`                   | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceDensityOption`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceLanguage`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceLanguageOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceMotion`                    | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceMotionOption`              | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferencePageSize`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferencePageSizeOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceRegion`                    | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceRegionOption`              | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceStatus`                    | ONLY-VIA-MODELS | `app/models/client_preference.rb`                                                                                                                                                |
| `ClientPreferenceTheme`                     | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceThemeOption`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceTimeFormat`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceTimeFormatOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceTimezone`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPreferenceTimezoneOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                          |
| `ClientPrivacyRequest`                      | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                |
| `ClientPrivacyRequestStatus`                | ONLY-VIA-MODELS | `app/models/client_privacy_request.rb`                                                                                                                                           |
| `ClientProcessorErasureNotification`        | USED            | `app/jobs/processor_erasure_notification_job.rb`, `app/jobs/processor_erasure_notification_retry_job.rb`, `app/jobs/retention_purge_job.rb`                                      |
| `ClientProcessorErasureNotificationAttempt` | ONLY-VIA-MODELS | `app/models/client_processor_erasure_notification.rb`                                                                                                                            |
| `ClientProcessorErasureNotificationStatus`  | ONLY-VIA-MODELS | `app/models/client_processor_erasure_notification.rb`                                                                                                                            |
| `ClientProfile`                             | ONLY-VIA-MODELS | `app/models/client_profile_status.rb`, `app/models/client.rb`                                                                                                                    |
| `ClientProfileStatus`                       | ONLY-VIA-MODELS | `app/models/client_profile.rb`                                                                                                                                                   |
| `ClientRegistrationCompletion`              | ONLY-VIA-MODELS | `app/models/client_sign_up_flow.rb`, `app/models/client_registration_completion_method.rb`                                                                                       |
| `ClientRegistrationCompletionMethod`        | ONLY-VIA-MODELS | `app/models/client_registration_completion.rb`                                                                                                                                   |
| `ClientRetentionHold`                       | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                |
| `ClientRetentionHoldStatus`                 | ONLY-VIA-MODELS | `app/models/client_retention_hold.rb`                                                                                                                                            |
| `ClientSecretAuditOutbox`                   | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`, `app/operations/client_secret_credential_purger.rb` |
| `ClientSecretCredential`                    | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`, `app/operations/client_secret_claim_finalizer.rb`   |
| `ClientSecretIssuance`                      | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/client_secret_issuance_expiry_invalidator.rb`, `app/operations/client_secret_credential_purger.rb` |
| `ClientSecurityMode`                        | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientSocialAuditOutbox`                   | USED            | `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/jobs/social_audit_delivery_job.rb`                                                                                 |
| `ClientSocialLinkSourceReceipt`             | UNUSED          |                                                                                                                                                                                  |
| `ClientStatus`                              | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/enterprise_creator.rb`, `app/operations/client_persona_creator.rb`                                 |
| `ClientTelephone`                           | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/services/identifier_hmac_emergency_rotation.rb`                   |
| `ClientTelephoneHistory`                    | ONLY-VIA-MODELS | `app/models/client.rb`, `app/models/concerns/telephone_dead_identifier_history.rb`                                                                                               |
| `ClientTelephoneStatus`                     | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/services/sign_up_artifact_cleanup.rb`, `app/queries/sign_up_stuck_registration_report_query.rb`               |
| `ClientTotpCredential`                      | USED            | `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/queries/authentication_credential_inventory.rb`                                                                    |
| `ClientTotpCredentialStatus`                | USED            | `app/operations/withdrawal_personal_data_anonymizer.rb`, `app/queries/authentication_credential_inventory.rb`                                                                    |
| `ClientVisibility`                          | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `ClientWithdrawalCeremony`                  | UNUSED          |                                                                                                                                                                                  |
| `ClientWithdrawalFlow`                      | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                |
| `ClientWithdrawalFlowEvent`                 | ONLY-VIA-MODELS | `app/models/client_withdrawal_flow.rb`                                                                                                                                           |
| `ClientWithdrawalFlowStatus`                | ONLY-VIA-MODELS | `app/models/client_withdrawal_flow_event.rb`, `app/models/client_withdrawal_flow.rb`                                                                                             |
| `CoreAppClientBridge`                       | ONLY-VIA-MODELS | `app/models/client.rb`                                                                                                                                                           |
| `Enterprise`                                | USED            | `app/operations/enterprise_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                                 |
| `EnterpriseAdministrationGrant`             | ONLY-VIA-MODELS | `app/models/enterprise.rb`, `app/models/client.rb`                                                                                                                               |
| `EnterpriseAuthorityCutover`                | USED            | `app/queries/authority_owner_migration_inventory.rb`                                                                                                                             |
| `EnterpriseDelegationGrant`                 | ONLY-VIA-MODELS | `app/models/enterprise.rb`, `app/models/client.rb`                                                                                                                               |
| `EnterpriseLifecycle`                       | USED            | `app/operations/enterprise_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                     |
| `EnterpriseOwnership`                       | USED            | `app/operations/enterprise_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                     |
| `EnterpriseOwnershipTransferRequest`        | ONLY-VIA-MODELS | `app/models/enterprise.rb`                                                                                                                                                       |
| `EnterpriseUnit`                            | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                               |
| `EnterpriseUnitClosure`                     | ONLY-VIA-MODELS | `app/models/enterprise_unit.rb`, `app/models/concerns/collective_unit.rb`                                                                                                        |
| `EnterpriseViewGrant`                       | ONLY-VIA-MODELS | `app/models/enterprise.rb`, `app/models/client.rb`                                                                                                                               |
| `Member`                                    | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                |
| `MemberStatus`                              | ONLY-VIA-MODELS | `app/models/member.rb`                                                                                                                                                           |
| `PersonaAssignment`                         | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                               |
| `PersonaMembership`                         | USED            | `app/resolvers/avatar_permission_resolver.rb`, `app/services/avatar_owner_membership_lock_service.rb`, `app/values/acme_selector_surface_config_value.rb`                        |
| `PersonaMembershipKind`                     | USED            | `app/resolvers/avatar_permission_resolver.rb`, `app/values/acme_selector_surface_config_value.rb`                                                                                |
| `PersonaMembershipRevokeReason`             | ONLY-VIA-MODELS | `app/models/persona_membership.rb`                                                                                                                                               |
| `PersonaMembershipState`                    | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                               |

## AvatarRecord — `avatar`

| Status          | Count |
| --------------- | ----: |
| USED            |    19 |
| ONLY-VIA-MODELS |    25 |
| UNUSED          |     1 |

| Model                                        | Status          | Reference examples                                                                                                                                                                                 |
| -------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Avatar`                                     | USED            | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`, `app/operations/avatar_moniker_writer_operation.rb`, `app/operations/avatar_ownership_cutover_operation.rb`                |
| `AvatarAgentBinding`                         | USED            | `app/services/base_selector_bootstrap_authority.rb`, `app/services/avatar_provisioning/create.rb`, `app/services/avatar_backfill/audit_legacy_client_bindings.rb`                                  |
| `AvatarAssignment`                           | USED            | `app/services/retention_cross_database_child_purge.rb`                                                                                                                                             |
| `AvatarBlock`                                | ONLY-VIA-MODELS | `app/models/avatar.rb`                                                                                                                                                                             |
| `AvatarBureauAgentGrant`                     | USED            | `app/resolvers/avatar_access_grant_resolver.rb`                                                                                                                                                    |
| `AvatarBureauOwnershipPeriod`                | USED            | `app/operations/avatar_concrete_ownership_backfill_operation.rb`, `app/resolvers/avatar_permission_resolver.rb`, `app/resolvers/avatar_access_grant_resolver.rb`                                   |
| `AvatarBureauToBureauTransferDetail`         | ONLY-VIA-MODELS | `app/models/avatar_transfer_reservation.rb`                                                                                                                                                        |
| `AvatarBureauToEnterpriseTransferDetail`     | ONLY-VIA-MODELS | `app/models/avatar_transfer_reservation.rb`                                                                                                                                                        |
| `AvatarCapability`                           | USED            | `app/services/base_selector_bootstrap_authority.rb`, `app/services/avatar_provisioning/create.rb`, `lib/tasks/object_storage.rake`                                                                 |
| `AvatarEnterpriseOwnershipPeriod`            | USED            | `app/operations/avatar_concrete_ownership_backfill_operation.rb`, `app/resolvers/avatar_permission_resolver.rb`, `app/resolvers/avatar_access_grant_resolver.rb`                                   |
| `AvatarEnterprisePersonaGrant`               | USED            | `app/resolvers/avatar_access_grant_resolver.rb`                                                                                                                                                    |
| `AvatarEnterpriseToBureauTransferDetail`     | ONLY-VIA-MODELS | `app/models/avatar_transfer_reservation.rb`                                                                                                                                                        |
| `AvatarEnterpriseToEnterpriseTransferDetail` | ONLY-VIA-MODELS | `app/models/avatar_transfer_reservation.rb`                                                                                                                                                        |
| `AvatarFollow`                               | ONLY-VIA-MODELS | `app/models/avatar.rb`                                                                                                                                                                             |
| `AvatarGroup`                                | USED            | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`, `app/operations/avatar_ownership_cutover_operation.rb`, `app/queries/avatar_group_ownership_transition_inventory_query.rb` |
| `AvatarGroupConcreteOwnershipPeriod`         | USED            | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`, `app/queries/avatar_group_ownership_transition_inventory_query.rb`                                                         |
| `AvatarGroupOwnershipPeriod`                 | USED            | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`, `app/queries/avatar_group_ownership_transition_inventory_query.rb`                                                         |
| `AvatarLifecycleEvent`                       | ONLY-VIA-MODELS | `app/models/avatar.rb`                                                                                                                                                                             |
| `AvatarLifecycleState`                       | USED            | `app/services/avatar_provisioning/create.rb`                                                                                                                                                       |
| `AvatarMembership`                           | ONLY-VIA-MODELS | `app/models/avatar_membership_status.rb`, `app/models/avatar.rb`, `app/models/avatar_role.rb`                                                                                                      |
| `AvatarMembershipStatus`                     | ONLY-VIA-MODELS | `app/models/avatar_membership.rb`                                                                                                                                                                  |
| `AvatarMoniker`                              | USED            | `app/operations/avatar_moniker_writer_operation.rb`                                                                                                                                                |
| `AvatarMute`                                 | ONLY-VIA-MODELS | `app/models/avatar.rb`                                                                                                                                                                             |
| `AvatarOwnershipCutover`                     | USED            | `app/operations/avatar_ownership_cutover_operation.rb`                                                                                                                                             |
| `AvatarOwnershipPeriod`                      | USED            | `app/operations/avatar_concrete_ownership_backfill_operation.rb`, `app/queries/avatar_ownership_transition_inventory_query.rb`                                                                     |
| `AvatarOwnershipStatus`                      | ONLY-VIA-MODELS | `app/models/avatar_ownership_period.rb`, `app/models/avatar_ownership_period_source.rb`, `app/models/avatar.rb`                                                                                    |
| `AvatarOwnershipTransfer`                    | ONLY-VIA-MODELS | `app/models/avatar.rb`                                                                                                                                                                             |
| `AvatarPermission`                           | ONLY-VIA-MODELS | `app/models/avatar_role_permission.rb`, `app/models/avatar_role.rb`                                                                                                                                |
| `AvatarPersonaBinding`                       | USED            | `app/services/base_selector_bootstrap_authority.rb`, `app/services/avatar_provisioning/create.rb`, `app/services/avatar_backfill/audit_legacy_client_bindings.rb`                                  |
| `AvatarPurgeDeferral`                        | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                                  |
| `AvatarRole`                                 | ONLY-VIA-MODELS | `app/models/avatar_role_permission.rb`, `app/models/avatar_membership.rb`, `app/models/avatar_permission.rb`                                                                                       |
| `AvatarRolePermission`                       | ONLY-VIA-MODELS | `app/models/avatar_permission.rb`, `app/models/avatar_role.rb`                                                                                                                                     |
| `AvatarTransferReservation`                  | ONLY-VIA-MODELS | `app/models/avatar_bureau_to_bureau_transfer_detail.rb`, `app/models/avatar_enterprise_to_enterprise_transfer_detail.rb`, `app/models/avatar_enterprise_to_bureau_transfer_detail.rb`              |
| `GroupAvatarMembership`                      | ONLY-VIA-MODELS | `app/models/avatar_group.rb`, `app/models/avatar.rb`                                                                                                                                               |
| `Handle`                                     | USED            | `app/services/avatar_provisioning/create.rb`, `lib/tasks/object_storage.rake`                                                                                                                      |
| `HandleAssignment`                           | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/handle_assignment_status.rb`, `app/models/handle.rb`                                                                                                           |
| `HandleAssignmentStatus`                     | ONLY-VIA-MODELS | `app/models/handle_assignment.rb`                                                                                                                                                                  |
| `HandleStatus`                               | USED            | `app/services/base_selector_bootstrap_authority.rb`, `app/services/avatar_provisioning/create.rb`                                                                                                  |
| `MemberAvatarAccess`                         | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarDeletion`                       | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarExtraction`                     | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarImpersonation`                  | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarOversight`                      | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarSuspension`                     | ONLY-VIA-MODELS | `app/models/avatar.rb`, `app/models/member.rb`                                                                                                                                                     |
| `MemberAvatarVisibility`                     | UNUSED          |                                                                                                                                                                                                    |

## ChronicleRecord — `chronicle`

| Status          | Count |
| --------------- | ----: |
| USED            |    21 |
| ONLY-VIA-MODELS |     1 |
| UNUSED          |     0 |

| Model                         | Status          | Reference examples                                                                                                                                                         |
| ----------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AccountAccessEvent`          | USED            | `app/operations/enforcement_case_end_operation.rb`, `app/services/administrative_access_lock.rb`, `app/jobs/enforcement_reconciliation_job.rb`                             |
| `AppPreferenceChronicle`      | USED            | `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`                      |
| `AppPreferenceChronicleEvent` | USED            | `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb` |
| `AppPreferenceChronicleLevel` | USED            | `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb`                                                            |
| `Chronicle`                   | USED            | `app/operations/client_secret_credential_purger.rb`, `app/operations/chronicle_intent_writer.rb`, `app/operations/withdrawal_personal_data_anonymizer.rb`                  |
| `ChronicleOutboxEntry`        | USED            | `app/controllers/concerns/authentication_audit_writer.rb`                                                                                                                  |
| `ChronicleRetentionPolicy`    | USED            | `app/policies/chronicle_record_policy.rb`, `app/jobs/contact_audit_delivery_job.rb`, `app/jobs/client_secret_audit_delivery_job.rb`                                        |
| `ChronicleVisibility`         | USED            | `app/operations/chronicle_intent_writer.rb`                                                                                                                                |
| `ChronicleVisibilityContext`  | USED            | `app/operations/chronicle_intent_writer.rb`                                                                                                                                |
| `ClientChronicle`             | USED            | `app/jobs/retention_purge_job.rb`, `app/jobs/social_audit_delivery_job.rb`, `app/controllers/concerns/authorization_audit.rb`                                              |
| `ClientChronicleEvent`        | USED            | `app/jobs/social_audit_delivery_job.rb`, `app/controllers/concerns/authorization_audit.rb`, `app/controllers/concerns/authentication_audit_writer.rb`                      |
| `ClientChronicleLevel`        | USED            | `app/jobs/social_audit_delivery_job.rb`, `app/controllers/concerns/authentication_audit_writer.rb`                                                                         |
| `ComPreferenceChronicle`      | USED            | `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`                                                         |
| `ComPreferenceChronicleEvent` | USED            | `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb` |
| `ComPreferenceChronicleLevel` | USED            | `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb`                                                            |
| `EnforcementEvent`            | ONLY-VIA-MODELS | `app/models/concerns/enforcement_case_applicable.rb`                                                                                                                       |
| `OperatorChronicle`           | USED            | `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/authorization_audit.rb`, `app/controllers/concerns/authentication_audit_writer.rb`                            |
| `OperatorChronicleEvent`      | USED            | `app/controllers/concerns/authorization_audit.rb`, `app/controllers/concerns/authentication_audit_writer.rb`                                                               |
| `OperatorChronicleLevel`      | USED            | `app/controllers/concerns/authentication_audit_writer.rb`                                                                                                                  |
| `OrgPreferenceChronicle`      | USED            | `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`                      |
| `OrgPreferenceChronicleEvent` | USED            | `app/controllers/concerns/authentication_audit_writer.rb`, `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb` |
| `OrgPreferenceChronicleLevel` | USED            | `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb`                                                            |

## ComSettingRecord — `com_setting`

| Status          | Count |
| --------------- | ----: |
| USED            |    27 |
| ONLY-VIA-MODELS |     2 |
| UNUSED          |     0 |

| Model                                 | Status          | Reference examples                                                                                                                                                                    |
| ------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ComPreference`                       | USED            | `app/values/security_jwt_preference_token_codec.rb`, `app/controllers/concerns/preference_base.rb`, `app/controllers/concerns/preference_class_registry.rb`                           |
| `ComPreferenceAdultContentGate`       | ONLY-VIA-MODELS | `app/models/com_preference.rb`, `app/models/com_preference_adult_content_gate_option.rb`                                                                                              |
| `ComPreferenceAdultContentGateOption` | ONLY-VIA-MODELS | `app/models/com_preference_adult_content_gate.rb`                                                                                                                                     |
| `ComPreferenceBrowserBinding`         | USED            | `app/controllers/concerns/preference_browser_binding.rb`, `app/controllers/concerns/preference_browser_state_reader.rb`                                                               |
| `ComPreferenceConsentReceipt`         | USED            | `app/controllers/concerns/preference_web_cookie_endpoint.rb`, `app/controllers/concerns/preference_browser_binding.rb`, `app/controllers/concerns/preference_browser_state_reader.rb` |
| `ComPreferenceCookie`                 | USED            | `app/controllers/concerns/preference_browser_binding.rb`, `app/controllers/concerns/preference_class_registry.rb`, `app/controllers/concerns/preference_browser_state_reader.rb`      |
| `ComPreferenceCurrency`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceCurrencyOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceDateFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceDateFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceDensity`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceDensityOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceLanguage`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceLanguageOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceMotion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceMotionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferencePageSize`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferencePageSizeOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceRegion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceRegionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceStatus`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`, `app/controllers/concerns/preference_browser_state_reader.rb`, `config/initializers/preference_reference_defaults.rb`        |
| `ComPreferenceTheme`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceThemeOption`            | USED            | `app/controllers/concerns/preference_web_theme_endpoint.rb`, `app/controllers/concerns/preference_class_registry.rb`                                                                  |
| `ComPreferenceTimeFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceTimeFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceTimezone`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceTimezoneOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                               |
| `ComPreferenceWebPush`                | USED            | `app/controllers/concerns/preference_base.rb`, `app/controllers/concerns/preference_browser_state_reader.rb`                                                                          |
| `ComPreferenceWebPushOption`          | USED            | `app/controllers/concerns/preference_base.rb`, `app/controllers/concerns/preference_browser_state_reader.rb`                                                                          |

## OccurrenceRecord — `occurrence`

| Status          | Count |
| --------------- | ----: |
| USED            |    13 |
| ONLY-VIA-MODELS |    39 |
| UNUSED          |     0 |

| Model                         | Status          | Reference examples                                                                                         |
| ----------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------- |
| `AreaClientOccurrence`        | ONLY-VIA-MODELS | `app/models/area_occurrence.rb`, `app/models/client_occurrence.rb`                                         |
| `AreaDomainOccurrence`        | ONLY-VIA-MODELS | `app/models/domain_occurrence.rb`, `app/models/area_occurrence.rb`                                         |
| `AreaEmailOccurrence`         | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/area_occurrence.rb`                                          |
| `AreaIpOccurrence`            | ONLY-VIA-MODELS | `app/models/ip_occurrence.rb`, `app/models/area_occurrence.rb`                                             |
| `AreaOccurrence`              | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `AreaOccurrenceStatus`        | ONLY-VIA-MODELS | `app/models/area_occurrence.rb`                                                                            |
| `AreaOperatorOccurrence`      | ONLY-VIA-MODELS | `app/models/operator_occurrence.rb`, `app/models/area_occurrence.rb`                                       |
| `AreaTelephoneOccurrence`     | ONLY-VIA-MODELS | `app/models/telephone_occurrence.rb`, `app/models/area_occurrence.rb`                                      |
| `AreaVisitorOccurrence`       | ONLY-VIA-MODELS | `app/models/visitor_occurrence.rb`, `app/models/area_occurrence.rb`                                        |
| `AreaZipOccurrence`           | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/area_occurrence.rb`                                            |
| `ClientOccurrence`            | USED            | `app/services/sign_risk_engine.rb`, `app/services/sign_risk_emitter.rb`, `app/jobs/retention_purge_job.rb` |
| `ClientOccurrenceStatus`      | USED            | `app/services/sign_risk_emitter.rb`                                                                        |
| `ClientZipOccurrence`         | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/client_occurrence.rb`                                          |
| `DomainClientOccurrence`      | ONLY-VIA-MODELS | `app/models/domain_occurrence.rb`, `app/models/client_occurrence.rb`                                       |
| `DomainEmailOccurrence`       | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/domain_occurrence.rb`                                        |
| `DomainIpOccurrence`          | ONLY-VIA-MODELS | `app/models/domain_occurrence.rb`, `app/models/ip_occurrence.rb`                                           |
| `DomainOccurrence`            | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `DomainOccurrenceStatus`      | ONLY-VIA-MODELS | `app/models/domain_occurrence.rb`                                                                          |
| `DomainOperatorOccurrence`    | ONLY-VIA-MODELS | `app/models/operator_occurrence.rb`, `app/models/domain_occurrence.rb`                                     |
| `DomainTelephoneOccurrence`   | ONLY-VIA-MODELS | `app/models/telephone_occurrence.rb`, `app/models/domain_occurrence.rb`                                    |
| `DomainZipOccurrence`         | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/domain_occurrence.rb`                                          |
| `EmailClientOccurrence`       | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/client_occurrence.rb`                                        |
| `EmailIpOccurrence`           | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/ip_occurrence.rb`                                            |
| `EmailOccurrence`             | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `EmailOccurrenceStatus`       | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`                                                                           |
| `EmailOperatorOccurrence`     | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/operator_occurrence.rb`                                      |
| `EmailTelephoneOccurrence`    | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/telephone_occurrence.rb`                                     |
| `EmailVisitorOccurrence`      | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/visitor_occurrence.rb`                                       |
| `EmailZipOccurrence`          | ONLY-VIA-MODELS | `app/models/email_occurrence.rb`, `app/models/zip_occurrence.rb`                                           |
| `IpClientOccurrence`          | ONLY-VIA-MODELS | `app/models/ip_occurrence.rb`, `app/models/client_occurrence.rb`                                           |
| `IpOccurrence`                | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `IpOccurrenceStatus`          | ONLY-VIA-MODELS | `app/models/ip_occurrence.rb`                                                                              |
| `IpOperatorOccurrence`        | ONLY-VIA-MODELS | `app/models/operator_occurrence.rb`, `app/models/ip_occurrence.rb`                                         |
| `IpTelephoneOccurrence`       | ONLY-VIA-MODELS | `app/models/telephone_occurrence.rb`, `app/models/ip_occurrence.rb`                                        |
| `IpVisitorOccurrence`         | ONLY-VIA-MODELS | `app/models/visitor_occurrence.rb`, `app/models/ip_occurrence.rb`                                          |
| `IpZipOccurrence`             | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/ip_occurrence.rb`                                              |
| `JwtAnomalyEvent`             | USED            | `app/subscribers/jwt_anomaly_subscriber.rb`                                                                |
| `JwtOccurrence`               | USED            | `app/subscribers/jwt_anomaly_subscriber.rb`, `app/jobs/retention_purge_job.rb`                             |
| `JwtOccurrenceStatus`         | ONLY-VIA-MODELS | `app/models/jwt_occurrence.rb`                                                                             |
| `OperatorClientOccurrence`    | ONLY-VIA-MODELS | `app/models/operator_occurrence.rb`, `app/models/client_occurrence.rb`                                     |
| `OperatorOccurrence`          | USED            | `app/services/sign_risk_engine.rb`, `app/services/sign_risk_emitter.rb`, `app/jobs/retention_purge_job.rb` |
| `OperatorOccurrenceStatus`    | USED            | `app/services/sign_risk_emitter.rb`                                                                        |
| `OperatorTelephoneOccurrence` | ONLY-VIA-MODELS | `app/models/operator_occurrence.rb`, `app/models/telephone_occurrence.rb`                                  |
| `OperatorZipOccurrence`       | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/operator_occurrence.rb`                                        |
| `TelephoneClientOccurrence`   | ONLY-VIA-MODELS | `app/models/telephone_occurrence.rb`, `app/models/client_occurrence.rb`                                    |
| `TelephoneOccurrence`         | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `TelephoneOccurrenceStatus`   | ONLY-VIA-MODELS | `app/models/telephone_occurrence.rb`                                                                       |
| `TelephoneZipOccurrence`      | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`, `app/models/telephone_occurrence.rb`                                       |
| `VisitorOccurrence`           | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `VisitorOccurrenceStatus`     | ONLY-VIA-MODELS | `app/models/visitor_occurrence.rb`                                                                         |
| `ZipOccurrence`               | USED            | `app/jobs/retention_purge_job.rb`                                                                          |
| `ZipOccurrenceStatus`         | ONLY-VIA-MODELS | `app/models/zip_occurrence.rb`                                                                             |

## OpBaseAppRecord — `op_base_app`

| Status          | Count |
| --------------- | ----: |
| USED            |    41 |
| ONLY-VIA-MODELS |    15 |
| UNUSED          |     9 |

| Model                                       | Status          | Reference examples                                                                                                                                                                |
| ------------------------------------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ClientAuthAdmissionBinding`                | USED            | `app/operations/auth_admission_binding_purger.rb`, `app/services/base_auth_admission_coordinator.rb`                                                                              |
| `ClientAuthAdmissionBindingStatus`          | ONLY-VIA-MODELS | `app/models/client_auth_admission_binding.rb`                                                                                                                                     |
| `ClientAuthCeremonySession`                 | USED            | `app/operations/client_secret_claim_finalizer.rb`, `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/services/base_auth_admission_coordinator.rb`            |
| `ClientAuthCeremonySessionStatus`           | ONLY-VIA-MODELS | `app/models/client_auth_ceremony_session.rb`                                                                                                                                      |
| `ClientDeviceSession`                       | USED            | `app/operations/op_authority_stop_committer.rb`, `app/resolvers/step_up_evidence_resolver.rb`, `app/resolvers/step_up_evidence_verifier.rb`                                       |
| `ClientDpopProofState`                      | USED            | `app/jobs/dpop_proof_state_purge_job.rb`                                                                                                                                          |
| `ClientEmailCeremonyTransaction`            | USED            | `app/operations/identity_email_ceremony_transaction_purger.rb`                                                                                                                    |
| `ClientEmergencySignInOperation`            | UNUSED          |                                                                                                                                                                                   |
| `ClientOauthCallbackState`                  | UNUSED          |                                                                                                                                                                                   |
| `ClientOidcAuthorizationTransaction`        | USED            | `app/operations/client_secret_claim_finalizer.rb`, `app/operations/client_secret_sign_in_receipt_purger.rb`, `app/operations/auth_admission_binding_purger.rb`                    |
| `ClientOidcAuthorizationTransactionStatus`  | ONLY-VIA-MODELS | `app/models/client_oidc_authorization_transaction.rb`                                                                                                                             |
| `ClientOidcConnection`                      | ONLY-VIA-MODELS | `app/models/client_token.rb`, `app/models/client.rb`                                                                                                                              |
| `ClientPasskeyCeremonyTransaction`          | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/operations/identity_passkey_ceremony_transaction_purger.rb`, `app/values/webauthn/surface.rb`              |
| `ClientSecretCredentialCeremonyTransaction` | USED            | `app/operations/identity_secret_credential_ceremony_transaction_purger.rb`                                                                                                        |
| `ClientSecretSignInReceipt`                 | USED            | `app/operations/client_secret_claim_finalizer.rb`, `app/operations/client_secret_sign_in_receipt_purger.rb`, `app/operations/oidc_authorization_transaction_purger.rb`            |
| `ClientSensitiveAdmission`                  | UNUSED          |                                                                                                                                                                                   |
| `ClientSensitiveAdmissionAuditAttempt`      | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                             |
| `ClientSensitiveAdmissionAuditOutbox`       | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                             |
| `ClientSessionLimitResolutionState`         | ONLY-VIA-MODELS | `app/models/client_session_limit_resolution_transaction.rb`, `app/models/concerns/session_limit_resolution_transactionable.rb`                                                    |
| `ClientSessionLimitResolutionTransaction`   | USED            | `app/operations/client_secret_claim_finalizer.rb`, `app/operations/oidc_authorization_transaction_purger.rb`, `app/jobs/retention_purge_job.rb`                                   |
| `ClientSignInFlow`                          | USED            | `app/operations/client_secret_claim_finalizer.rb`, `app/operations/client_secret_sign_in_receipt_purger.rb`, `app/operations/oidc_authorization_transaction_purger.rb`            |
| `ClientSignInFlowState`                     | ONLY-VIA-MODELS | `app/models/client_sign_in_flow.rb`                                                                                                                                               |
| `ClientSignUpFlow`                          | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/auth_admission_binding_purger.rb`, `app/operations/client_secret_issuance_purger.rb`                |
| `ClientSignUpFlowCleanupStatus`             | ONLY-VIA-MODELS | `app/models/client_sign_up_flow.rb`, `app/models/concerns/sign_up_flow_ticket.rb`                                                                                                 |
| `ClientSignUpFlowStatus`                    | ONLY-VIA-MODELS | `app/models/client_sign_up_flow.rb`, `app/models/client_telephone.rb`, `app/models/client.rb`                                                                                     |
| `ClientSocialCeremonyTransaction`           | USED            | `app/operations/identity_social_ceremony_transaction_purger.rb`                                                                                                                   |
| `ClientStepUpAuditOutbox`                   | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                             |
| `ClientStepUpAuditOutboxAttempt`            | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                             |
| `ClientStepUpAuditOutboxDeliveryState`      | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                             |
| `ClientStepUpCeremonyTransaction`           | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/operations/auth_admission_binding_purger.rb` |
| `ClientStepUpCommit`                        | USED            | `app/controllers/concerns/authentication_session_revoker.rb`                                                                                                                      |
| `ClientStepUpContext`                       | ONLY-VIA-MODELS | `app/models/client_step_up_context_transition.rb`, `app/models/client_step_up_context_state.rb`                                                                                   |
| `ClientStepUpContextState`                  | ONLY-VIA-MODELS | `app/models/client_step_up_context_transition.rb`, `app/models/client_step_up_context.rb`                                                                                         |
| `ClientStepUpContextTransition`             | ONLY-VIA-MODELS | `app/models/client_step_up_context_state.rb`, `app/models/client_step_up_context.rb`                                                                                              |
| `ClientStepUpSession`                       | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/jobs/retention_purge_job.rb`                                                                               |
| `ClientTelephoneCeremonyTransaction`        | USED            | `app/operations/identity_telephone_ceremony_transaction_purger.rb`                                                                                                                |
| `ClientToken`                               | USED            | `app/operations/client_secret_passkey_reservation_issuer.rb`, `app/operations/op_identity_event_invalidator.rb`, `app/operations/client_secret_claim_finalizer.rb`                |
| `ClientTokenBindingMethod`                  | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                 |
| `ClientTokenDbscStatus`                     | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                 |
| `ClientTokenKind`                           | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                 |
| `ClientTokenStatus`                         | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                 |
| `ClientTotpCeremonyTransaction`             | USED            | `app/operations/identity_totp_ceremony_transaction_purger.rb`, `app/operations/identity_step_up_ceremony_transaction_purger.rb`                                                   |
| `ClientVerification`                        | USED            | `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/verification_base.rb`                                                                                                |
| `ClientVisaSensitiveAdmission`              | USED            | `app/adapters/visa_sensitive_admission_client.rb`                                                                                                                                 |
| `ClientVisaSocialLinkAdmission`             | UNUSED          |                                                                                                                                                                                   |
| `IdentityPasskeyCeremonyCandidate`          | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`                                                                                                                  |
| `IdentitySecretCredentialCeremonyCandidate` | UNUSED          |                                                                                                                                                                                   |
| `IdentitySocialCeremonyCandidate`           | UNUSED          |                                                                                                                                                                                   |
| `IdentityTotpCeremonyCandidate`             | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`                                                                                                                  |
| `LogoutTransaction`                         | UNUSED          |                                                                                                                                                                                   |
| `OpAppAuthorityStop`                        | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                   |
| `OpAppAuthorityStopCause`                   | ONLY-VIA-MODELS | `app/models/op_app_authority_stop.rb`                                                                                                                                             |
| `OpAppAuthorityStopEpochCutoff`             | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                   |
| `OpAppAuthorityStopGrantTarget`             | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                   |
| `OpAppAuthorityStopParticipant`             | USED            | `app/operations/op_authority_stop_committer.rb`, `app/jobs/op_outbox_dispatch_job.rb`                                                                                             |
| `OpAppAuthorityStopParticipantStatus`       | ONLY-VIA-MODELS | `app/models/op_app_authority_stop_participant.rb`                                                                                                                                 |
| `OpAppAuthorityStopRootTarget`              | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                   |
| `OpAppAuthorityStopScope`                   | ONLY-VIA-MODELS | `app/models/op_app_authority_stop.rb`                                                                                                                                             |
| `OpAppConsumedJti`                          | UNUSED          |                                                                                                                                                                                   |
| `OpAppGrant`                                | USED            | `app/operations/op_authority_stop_committer.rb`, `app/resolvers/step_up_evidence_resolver.rb`, `app/resolvers/step_up_evidence_verifier.rb`                                       |
| `OpAppGrantLogoutHint`                      | ONLY-VIA-MODELS | `app/models/op_app_grant.rb`                                                                                                                                                      |
| `OpAppInboundEventReceipt`                  | USED            | `app/operations/op_identity_event_invalidator.rb`                                                                                                                                 |
| `SecurityConsumedJti`                       | USED            | `app/values/oidc_client_assertion_jwt.rb`, `app/jobs/security_consumed_jti_purge_job.rb`                                                                                          |
| `SecurityOneTimeReveal`                     | USED            | `app/services/identity_one_time_reveal.rb`, `app/jobs/security_one_time_reveal_purge_job.rb`                                                                                      |
| `TurnstileReplay`                           | UNUSED          |                                                                                                                                                                                   |

## OpBaseOrgRecord — `op_base_org`

| Status          | Count |
| --------------- | ----: |
| USED            |    34 |
| ONLY-VIA-MODELS |    14 |
| UNUSED          |     5 |

| Model                                         | Status          | Reference examples                                                                                                                                                                 |
| --------------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OpOrgAuthorityStop`                          | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                    |
| `OpOrgAuthorityStopCause`                     | ONLY-VIA-MODELS | `app/models/op_org_authority_stop.rb`                                                                                                                                              |
| `OpOrgAuthorityStopEpochCutoff`               | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                    |
| `OpOrgAuthorityStopGrantTarget`               | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                    |
| `OpOrgAuthorityStopParticipant`               | USED            | `app/operations/op_authority_stop_committer.rb`, `app/jobs/op_outbox_dispatch_job.rb`                                                                                              |
| `OpOrgAuthorityStopParticipantStatus`         | ONLY-VIA-MODELS | `app/models/op_org_authority_stop_participant.rb`                                                                                                                                  |
| `OpOrgAuthorityStopRootTarget`                | USED            | `app/operations/op_authority_stop_committer.rb`                                                                                                                                    |
| `OpOrgAuthorityStopScope`                     | ONLY-VIA-MODELS | `app/models/op_org_authority_stop.rb`                                                                                                                                              |
| `OpOrgConsumedJti`                            | UNUSED          |                                                                                                                                                                                    |
| `OpOrgGrant`                                  | USED            | `app/operations/op_authority_stop_committer.rb`, `app/resolvers/step_up_evidence_resolver.rb`, `app/resolvers/step_up_evidence_verifier.rb`                                        |
| `OpOrgGrantLogoutHint`                        | ONLY-VIA-MODELS | `app/models/op_org_grant.rb`                                                                                                                                                       |
| `OpOrgInboundEventReceipt`                    | USED            | `app/operations/op_identity_event_invalidator.rb`                                                                                                                                  |
| `OperatorAuthAdmissionBinding`                | USED            | `app/operations/auth_admission_binding_purger.rb`, `app/services/base_auth_admission_coordinator.rb`                                                                               |
| `OperatorAuthAdmissionBindingStatus`          | ONLY-VIA-MODELS | `app/models/operator_auth_admission_binding.rb`                                                                                                                                    |
| `OperatorAuthCeremonySession`                 | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/services/base_auth_admission_coordinator.rb`                                                                |
| `OperatorAuthCeremonySessionStatus`           | ONLY-VIA-MODELS | `app/models/operator_auth_ceremony_session.rb`                                                                                                                                     |
| `OperatorDeviceSession`                       | USED            | `app/operations/op_authority_stop_committer.rb`, `app/resolvers/step_up_evidence_resolver.rb`, `app/resolvers/step_up_evidence_verifier.rb`                                        |
| `OperatorDpopProofState`                      | USED            | `app/jobs/dpop_proof_state_purge_job.rb`                                                                                                                                           |
| `OperatorEmailCeremonyTransaction`            | USED            | `app/operations/identity_email_ceremony_transaction_purger.rb`                                                                                                                     |
| `OperatorOauthCallbackState`                  | UNUSED          |                                                                                                                                                                                    |
| `OperatorOidcAuthorizationTransaction`        | USED            | `app/operations/auth_admission_binding_purger.rb`, `app/operations/oidc_authorization_transaction_purger.rb`, `app/services/base_auth_admission_coordinator.rb`                    |
| `OperatorOidcAuthorizationTransactionStatus`  | ONLY-VIA-MODELS | `app/models/operator_oidc_authorization_transaction.rb`                                                                                                                            |
| `OperatorOidcConnection`                      | ONLY-VIA-MODELS | `app/models/operator.rb`, `app/models/operator_token.rb`                                                                                                                           |
| `OperatorPasskeyCeremonyCandidate`            | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`                                                                                                                   |
| `OperatorPasskeyCeremonyTransaction`          | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/operations/identity_passkey_ceremony_transaction_purger.rb`, `app/values/webauthn/surface.rb`               |
| `OperatorSecretCredentialCeremonyTransaction` | USED            | `app/operations/identity_secret_credential_ceremony_transaction_purger.rb`                                                                                                         |
| `OperatorSensitiveAdmission`                  | UNUSED          |                                                                                                                                                                                    |
| `OperatorSensitiveAdmissionAuditAttempt`      | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                              |
| `OperatorSensitiveAdmissionAuditOutbox`       | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                              |
| `OperatorSessionLimitResolutionState`         | ONLY-VIA-MODELS | `app/models/operator_session_limit_resolution_transaction.rb`, `app/models/concerns/session_limit_resolution_transactionable.rb`                                                   |
| `OperatorSessionLimitResolutionTransaction`   | USED            | `app/operations/oidc_authorization_transaction_purger.rb`, `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/session_limit_gate.rb`                                     |
| `OperatorSignInFlow`                          | USED            | `app/operations/oidc_authorization_transaction_purger.rb`, `app/services/sign_in_cycle_locator.rb`, `app/services/sign_in_selector_participant.rb`                                 |
| `OperatorSignInFlowState`                     | ONLY-VIA-MODELS | `app/models/operator_sign_in_flow.rb`                                                                                                                                              |
| `OperatorSignUpFlow`                          | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                                  |
| `OperatorSignUpFlowStatus`                    | ONLY-VIA-MODELS | `app/models/operator_sign_up_flow.rb`                                                                                                                                              |
| `OperatorStepUpAuditOutbox`                   | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                              |
| `OperatorStepUpAuditOutboxAttempt`            | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                              |
| `OperatorStepUpAuditOutboxDeliveryState`      | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                                                                              |
| `OperatorStepUpCeremonyTransaction`           | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/operations/auth_admission_binding_purger.rb`, `app/services/base_auth_admission_coordinator.rb`             |
| `OperatorStepUpCommit`                        | USED            | `app/controllers/concerns/authentication_session_revoker.rb`                                                                                                                       |
| `OperatorStepUpContext`                       | ONLY-VIA-MODELS | `app/models/operator_step_up_context_state.rb`, `app/models/operator_step_up_context_transition.rb`                                                                                |
| `OperatorStepUpContextState`                  | ONLY-VIA-MODELS | `app/models/operator_step_up_context.rb`, `app/models/operator_step_up_context_transition.rb`                                                                                      |
| `OperatorStepUpContextTransition`             | ONLY-VIA-MODELS | `app/models/operator_step_up_context.rb`, `app/models/operator_step_up_context_state.rb`                                                                                           |
| `OperatorStepUpSession`                       | USED            | `app/operations/identity_step_up_ceremony_transaction_purger.rb`, `app/jobs/retention_purge_job.rb`                                                                                |
| `OperatorTelephoneCeremonyTransaction`        | USED            | `app/operations/identity_telephone_ceremony_transaction_purger.rb`, `app/queries/operator_telephone_legacy_reference_inventory.rb`, `lib/tasks/operator_telephone_public_ids.rake` |
| `OperatorToken`                               | USED            | `app/operations/op_identity_event_invalidator.rb`, `app/operations/enforcement_case_end_operation.rb`, `app/operations/enforcement_case_apply_operation.rb`                        |
| `OperatorTokenBindingMethod`                  | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                  |
| `OperatorTokenDbscStatus`                     | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                  |
| `OperatorTokenKind`                           | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                  |
| `OperatorTokenStatus`                         | USED            | `app/controllers/concerns/authentication_base.rb`                                                                                                                                  |
| `OperatorVerification`                        | USED            | `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/verification_base.rb`                                                                                                 |
| `OperatorVisaSensitiveAdmission`              | UNUSED          |                                                                                                                                                                                    |
| `OrganizationInvitation`                      | UNUSED          |                                                                                                                                                                                    |

## OrgSettingRecord — `org_setting`

| Status          | Count |
| --------------- | ----: |
| USED            |    27 |
| ONLY-VIA-MODELS |     2 |
| UNUSED          |     0 |

| Model                                 | Status          | Reference examples                                                                                                                    |
| ------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `OrgPreference`                       | USED            | `app/values/security_jwt_preference_token_codec.rb`, `app/jobs/retention_purge_job.rb`, `app/controllers/concerns/preference_base.rb` |
| `OrgPreferenceAdultContentGate`       | ONLY-VIA-MODELS | `app/models/org_preference_adult_content_gate_option.rb`, `app/models/org_preference.rb`                                              |
| `OrgPreferenceAdultContentGateOption` | ONLY-VIA-MODELS | `app/models/org_preference_adult_content_gate.rb`                                                                                     |
| `OrgPreferenceBrowserBinding`         | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `OrgPreferenceConsentReceipt`         | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `OrgPreferenceCookie`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceCurrency`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceCurrencyOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceDateFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceDateFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceDensity`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceDensityOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceLanguage`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceLanguageOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceMotion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceMotionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferencePageSize`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferencePageSizeOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceRegion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceRegionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceStatus`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`, `config/initializers/preference_reference_defaults.rb`                       |
| `OrgPreferenceTheme`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceThemeOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceTimeFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceTimeFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceTimezone`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceTimezoneOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                               |
| `OrgPreferenceWebPush`                | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |
| `OrgPreferenceWebPushOption`          | USED            | `app/controllers/concerns/preference_browser_state_reader.rb`                                                                         |

## OrgSignalRecord — `org_signal`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     1 |
| UNUSED          |     0 |

| Model                        | Status          | Reference examples                                     |
| ---------------------------- | --------------- | ------------------------------------------------------ |
| `OperatorNotification`       | ONLY-VIA-MODELS | `app/models/operator_notification_record.rb`           |
| `OperatorNotificationRecord` | USED            | `app/services/retention_cross_database_child_purge.rb` |

## OrgZenithRecord — `org_zenith`

| Status          | Count |
| --------------- | ----: |
| USED            |    56 |
| ONLY-VIA-MODELS |    38 |
| UNUSED          |     3 |

| Model                                      | Status          | Reference examples                                                                                                                                                         |
| ------------------------------------------ | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Agent`                                    | USED            | `app/operations/agent_creator.rb`, `app/resolvers/avatar_permission_resolver.rb`, `app/resolvers/avatar_access_grant_resolver.rb`                                          |
| `AgentAdministrationGrant`                 | ONLY-VIA-MODELS | `app/models/agent.rb`, `app/models/operator.rb`                                                                                                                            |
| `AgentAssignment`                          | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                         |
| `AgentAuthorityCutover`                    | USED            | `app/queries/authority_owner_migration_inventory.rb`                                                                                                                       |
| `AgentDelegationGrant`                     | ONLY-VIA-MODELS | `app/models/agent.rb`, `app/models/operator.rb`                                                                                                                            |
| `AgentLifecycle`                           | USED            | `app/operations/agent_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                    |
| `AgentMembership`                          | USED            | `app/resolvers/avatar_permission_resolver.rb`, `app/services/avatar_owner_membership_lock_service.rb`, `app/values/acme_selector_surface_config_value.rb`                  |
| `AgentMembershipKind`                      | USED            | `app/resolvers/avatar_permission_resolver.rb`, `app/values/acme_selector_surface_config_value.rb`                                                                          |
| `AgentMembershipRevokeReason`              | ONLY-VIA-MODELS | `app/models/agent_membership.rb`                                                                                                                                           |
| `AgentMembershipState`                     | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                         |
| `AgentOwnership`                           | USED            | `app/operations/agent_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                    |
| `AgentOwnershipTransferRequest`            | ONLY-VIA-MODELS | `app/models/agent.rb`                                                                                                                                                      |
| `AgentUsageGrant`                          | ONLY-VIA-MODELS | `app/models/agent.rb`, `app/models/operator.rb`                                                                                                                            |
| `AgentViewGrant`                           | ONLY-VIA-MODELS | `app/models/agent.rb`, `app/models/operator.rb`                                                                                                                            |
| `Bureau`                                   | USED            | `app/operations/bureau_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                               |
| `BureauAdministrationGrant`                | ONLY-VIA-MODELS | `app/models/bureau.rb`, `app/models/operator.rb`                                                                                                                           |
| `BureauAuthorityCutover`                   | USED            | `app/queries/authority_owner_migration_inventory.rb`                                                                                                                       |
| `BureauDelegationGrant`                    | ONLY-VIA-MODELS | `app/models/bureau.rb`, `app/models/operator.rb`                                                                                                                           |
| `BureauLifecycle`                          | USED            | `app/operations/bureau_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                   |
| `BureauOwnership`                          | USED            | `app/operations/bureau_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                                                   |
| `BureauOwnershipTransferRequest`           | ONLY-VIA-MODELS | `app/models/bureau.rb`                                                                                                                                                     |
| `BureauUnit`                               | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                         |
| `BureauUnitClosure`                        | ONLY-VIA-MODELS | `app/models/bureau_unit.rb`, `app/models/concerns/collective_unit.rb`                                                                                                      |
| `BureauViewGrant`                          | ONLY-VIA-MODELS | `app/models/bureau.rb`, `app/models/operator.rb`                                                                                                                           |
| `CoreOrgOperatorBridge`                    | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `Department`                               | ONLY-VIA-MODELS | `app/models/organization_status.rb`, `app/models/department_status.rb`, `app/models/operator_organization.rb`                                                              |
| `DepartmentStatus`                         | ONLY-VIA-MODELS | `app/models/department.rb`                                                                                                                                                 |
| `Division`                                 | ONLY-VIA-MODELS | `app/models/division_status.rb`, `app/models/operator_organization.rb`                                                                                                     |
| `DivisionStatus`                           | ONLY-VIA-MODELS | `app/models/division.rb`                                                                                                                                                   |
| `Operator`                                 | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/op_identity_event_invalidator.rb`, `app/operations/enforcement_case_end_operation.rb`                     |
| `OperatorAccount`                          | USED            | `app/values/acme_selector_surface_config_value.rb`                                                                                                                         |
| `OperatorAuthorityLock`                    | USED            | `app/operations/agent_creator.rb`, `app/operations/bureau_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`                                                |
| `OperatorBanner`                           | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `OperatorBulletin`                         | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `OperatorCapabilityGrant`                  | USED            | `app/policies/enforcement_case_policy.rb`, `app/policies/application_policy.rb`, `lib/tasks/operator_capabilities.rake`                                                    |
| `OperatorEmail`                            | USED            | `app/operations/email_identifier_purger.rb`, `app/services/identifier_hmac_emergency_rotation.rb`, `app/queries/authentication_credential_inventory.rb`                    |
| `OperatorEmailHistory`                     | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                          |
| `OperatorEmailStatus`                      | USED            | `app/queries/authentication_credential_inventory.rb`                                                                                                                       |
| `OperatorEntraIdentity`                    | USED            | `app/services/retention_cross_database_child_purge.rb`                                                                                                                     |
| `OperatorEntraIdentityState`               | ONLY-VIA-MODELS | `app/models/operator_entra_identity.rb`                                                                                                                                    |
| `OperatorIdentifierRotationAudit`          | UNUSED          |                                                                                                                                                                            |
| `OperatorIdentity`                         | USED            | `app/operations/agent_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                                |
| `OperatorIdentityState`                    | USED            | `app/operations/agent_creator.rb`, `app/queries/authority_owner_migration_inventory.rb`, `app/values/acme_selector_surface_config_value.rb`                                |
| `OperatorLifecycleRequest`                 | UNUSED          |                                                                                                                                                                            |
| `OperatorMfaStatus`                        | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `OperatorOidcIdentityBinding`              | ONLY-VIA-MODELS | `app/models/operator_identity.rb`                                                                                                                                          |
| `OperatorOrganization`                     | ONLY-VIA-MODELS | `app/models/division.rb`, `app/models/organization_status.rb`, `app/models/department.rb`                                                                                  |
| `OperatorPasskey`                          | USED            | `app/services/retention_cross_database_child_purge.rb`, `app/queries/authentication_credential_inventory.rb`, `app/values/webauthn/surface.rb`                             |
| `OperatorPasskeyAuditOutbox`               | USED            | `app/jobs/passkey_audit_delivery_job.rb`                                                                                                                                   |
| `OperatorPasskeyStatus`                    | USED            | `app/queries/authentication_credential_inventory.rb`, `app/values/webauthn/surface.rb`                                                                                     |
| `OperatorPreference`                       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceAdultContentGate`       | ONLY-VIA-MODELS | `app/models/operator_preference.rb`, `app/models/operator_preference_adult_content_gate_option.rb`                                                                         |
| `OperatorPreferenceAdultContentGateOption` | ONLY-VIA-MODELS | `app/models/operator_preference_adult_content_gate.rb`                                                                                                                     |
| `OperatorPreferenceCurrency`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceCurrencyOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceDateFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceDateFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceDensity`                | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceDensityOption`          | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceLanguage`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceLanguageOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceMotion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceMotionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferencePageSize`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferencePageSizeOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceRegion`                 | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceRegionOption`           | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceStatus`                 | ONLY-VIA-MODELS | `app/models/operator_preference.rb`                                                                                                                                        |
| `OperatorPreferenceTheme`                  | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceThemeOption`            | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceTimeFormat`             | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceTimeFormatOption`       | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceTimezone`               | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorPreferenceTimezoneOption`         | USED            | `app/controllers/concerns/preference_class_registry.rb`                                                                                                                    |
| `OperatorSecretCredential`                 | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                          |
| `OperatorSecretCredentialKind`             | ONLY-VIA-MODELS | `app/models/operator_secret_credential.rb`, `app/models/concerns/operator_secret_credential_kinds.rb`                                                                      |
| `OperatorSecretCredentialStatus`           | ONLY-VIA-MODELS | `app/models/operator_secret_credential.rb`, `app/models/concerns/secret_credential.rb`                                                                                     |
| `OperatorSecurityMode`                     | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `OperatorStatus`                           | USED            | `app/operations/agent_creator.rb`, `app/operations/bureau_creator.rb`, `app/resolvers/avatar_permission_resolver.rb`                                                       |
| `OperatorTelephone`                        | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/operator_telephone_public_id_backfill_operation.rb`, `app/services/identifier_hmac_emergency_rotation.rb` |
| `OperatorTelephoneHistory`                 | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                          |
| `OperatorTelephoneStatus`                  | USED            | `app/queries/authentication_credential_inventory.rb`                                                                                                                       |
| `OperatorVisibility`                       | ONLY-VIA-MODELS | `app/models/operator.rb`                                                                                                                                                   |
| `OperatorWorkspaceAccount`                 | USED            | `app/jobs/retention_purge_job.rb`                                                                                                                                          |
| `OperatorWorkspaceAccountMembership`       | ONLY-VIA-MODELS | `app/models/operator.rb`, `app/models/operator_workspace_account.rb`                                                                                                       |
| `OperatorWorkspaceAccountStatus`           | ONLY-VIA-MODELS | `app/models/operator_workspace_account.rb`                                                                                                                                 |
| `OrgEnforcementAppeal`                     | USED            | `app/jobs/enforcement_reconciliation_job.rb`                                                                                                                               |
| `OrgEnforcementAuthenticationMethodEffect` | ONLY-VIA-MODELS | `app/models/org_enforcement_case.rb`                                                                                                                                       |
| `OrgEnforcementCase`                       | USED            | `app/operations/telephone_identifier_purger.rb`, `app/operations/email_identifier_purger.rb`, `app/jobs/retention_purge_job.rb`                                            |
| `OrgEnforcementIdentifierEffect`           | ONLY-VIA-MODELS | `app/models/org_enforcement_case.rb`                                                                                                                                       |
| `OrgEnforcementPrincipalEffect`            | ONLY-VIA-MODELS | `app/models/org_enforcement_case.rb`                                                                                                                                       |
| `OrgEnforcementPrincipalLink`              | ONLY-VIA-MODELS | `app/models/org_enforcement_case.rb`                                                                                                                                       |
| `OrgIamOperationOutcome`                   | UNUSED          |                                                                                                                                                                            |
| `OrgIdentityAuthenticationEvent`           | USED            | `app/operations/op_identity_event_invalidator.rb`, `app/operations/identity_authentication_stop_recorder.rb`, `app/jobs/op_identity_event_delivery_job.rb`                 |
| `OrganizationEntraConnection`              | ONLY-VIA-MODELS | `app/models/operator_entra_identity.rb`, `app/models/organization_entra_connection_state.rb`                                                                               |
| `OrganizationEntraConnectionState`         | ONLY-VIA-MODELS | `app/models/organization_entra_connection.rb`                                                                                                                              |
| `OrganizationStatus`                       | ONLY-VIA-MODELS | `app/models/operator_organization.rb`                                                                                                                                      |

## PublishingRecord — `publishing`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |   144 |
| UNUSED          |    12 |

| Model                                                       | Status          | Reference examples                                                                                                                                                                              |
| ----------------------------------------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Publishing::Docs::App::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Docs::App::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/app/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/docs/app/revision_single_taxonomy_assignment.rb` |
| `Publishing::Docs::App::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Docs::App::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/app/version_single_taxonomy_assignment.rb`, `app/models/publishing/docs/app/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::Docs::App::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Docs::App::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Docs::App::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::App::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Docs::Com::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Docs::Com::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/com/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/docs/com/revision_single_taxonomy_assignment.rb` |
| `Publishing::Docs::Com::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Docs::Com::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/com/version_single_taxonomy_assignment.rb`, `app/models/publishing/docs/com/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::Docs::Com::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Docs::Com::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Docs::Com::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Com::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Docs::Org::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Docs::Org::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/org/revision_single_taxonomy_assignment.rb`, `app/models/publishing/docs/org/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::Docs::Org::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Docs::Org::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/docs/org/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/docs/org/version_single_taxonomy_assignment.rb`   |
| `Publishing::Docs::Org::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Docs::Org::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Docs::Org::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Docs::Org::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Help::App::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Help::App::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/app/revision_single_taxonomy_assignment.rb`, `app/models/publishing/help/app/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::Help::App::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Help::App::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/app/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/help/app/version_single_taxonomy_assignment.rb`   |
| `Publishing::Help::App::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Help::App::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Help::App::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::App::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Help::Com::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Help::Com::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/com/revision_single_taxonomy_assignment.rb`, `app/models/publishing/help/com/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::Help::Com::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Help::Com::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/com/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/help/com/version_single_taxonomy_assignment.rb`   |
| `Publishing::Help::Com::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Help::Com::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Help::Com::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Com::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Help::Org::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Help::Org::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/org/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/help/org/revision_single_taxonomy_assignment.rb` |
| `Publishing::Help::Org::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Help::Org::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/help/org/version_single_taxonomy_assignment.rb`, `app/models/publishing/help/org/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::Help::Org::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Help::Org::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Help::Org::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Help::Org::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Info::App::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Info::App::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/app/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/info/app/revision_single_taxonomy_assignment.rb` |
| `Publishing::Info::App::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Info::App::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/app/version_single_taxonomy_assignment.rb`, `app/models/publishing/info/app/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::Info::App::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Info::App::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Info::App::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::App::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Info::Com::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Info::Com::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/com/revision_single_taxonomy_assignment.rb`, `app/models/publishing/info/com/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::Info::Com::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Info::Com::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/com/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/info/com/version_single_taxonomy_assignment.rb`   |
| `Publishing::Info::Com::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Info::Com::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Info::Com::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Com::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::Info::Org::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::Info::Org::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/org/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/info/org/revision_single_taxonomy_assignment.rb` |
| `Publishing::Info::Org::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::Info::Org::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/info/org/version_single_taxonomy_assignment.rb`, `app/models/publishing/info/org/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::Info::Org::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::Info::Org::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::Info::Org::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::Info::Org::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::MediaFile`                                     | USED            | `lib/tasks/object_storage.rake`                                                                                                                                                                 |
| `Publishing::News::App::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::News::App::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/app/revision_multiple_taxonomy_assignment.rb`, `app/models/publishing/news/app/revision_single_taxonomy_assignment.rb` |
| `Publishing::News::App::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::News::App::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/app/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/news/app/version_single_taxonomy_assignment.rb`   |
| `Publishing::News::App::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::News::App::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::News::App::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::App::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::News::Com::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::News::Com::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/com/revision_single_taxonomy_assignment.rb`, `app/models/publishing/news/com/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::News::Com::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::News::Com::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/com/version_multiple_taxonomy_assignment.rb`, `app/models/publishing/news/com/version_single_taxonomy_assignment.rb`   |
| `Publishing::News::Com::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::News::Com::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::News::Com::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Com::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |
| `Publishing::News::Org::Entry`                              | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_entry_slug_record.rb`, `app/models/concerns/publishing_publication_record.rb`                                      |
| `Publishing::News::Org::EntryRevision`                      | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/org/revision_single_taxonomy_assignment.rb`, `app/models/publishing/news/org/revision_multiple_taxonomy_assignment.rb` |
| `Publishing::News::Org::EntrySlug`                          | UNUSED          |                                                                                                                                                                                                 |
| `Publishing::News::Org::EntryVersion`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/publishing/news/org/version_single_taxonomy_assignment.rb`, `app/models/publishing/news/org/version_multiple_taxonomy_assignment.rb`   |
| `Publishing::News::Org::Publication`                        | ONLY-VIA-MODELS | `app/models/concerns/publishing_entry_record.rb`, `app/models/concerns/publishing_entry_version_record.rb`                                                                                      |
| `Publishing::News::Org::RevisionMediaUsage`                 | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::RevisionMultipleTaxonomyAssignment` | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::RevisionSingleTaxonomyAssignment`   | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::TaxonomyTerm`                       | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`                                                                                     |
| `Publishing::News::Org::VersionMediaUsage`                  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::VersionMultipleTaxonomyAssignment`  | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::VersionSingleTaxonomyAssignment`    | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`                                                                                                                                                     |
| `Publishing::News::Org::Vocabulary`                         | ONLY-VIA-MODELS | `app/models/publishing/content_families.rb`, `app/models/concerns/publishing_family_taxonomy_assignment.rb`, `app/models/concerns/publishing_taxonomy_term_record.rb`                           |

## RpBaseAppRecord — `rp_base_app`

| Status          | Count |
| --------------- | ----: |
| USED            |    11 |
| ONLY-VIA-MODELS |     1 |
| UNUSED          |     1 |

| Model                              | Status          | Reference examples                                                                                                                 |
| ---------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `RpBaseAppCallbackState`           | UNUSED          |                                                                                                                                    |
| `RpBaseAppEventReceipt`            | ONLY-VIA-MODELS | `app/models/rp_base_app_op_session_binding.rb`                                                                                     |
| `RpBaseAppIdentityBinding`         | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseAppOpSessionBinding`        | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseAppPrincipal`               | USED            | `app/resolvers/step_up_evidence_resolver.rb`, `app/values/rp_step_up_cell_registry.rb`                                             |
| `RpBaseAppSession`                 | USED            | `app/resolvers/step_up_evidence_resolver.rb`, `app/services/rp_request_authenticator.rb`, `app/values/rp_step_up_cell_registry.rb` |
| `RpBaseAppSessionSelection`        | USED            | `app/controllers/concerns/browser_rp_authentication.rb`                                                                            |
| `RpStepUpAuditOutbox`              | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpStepUpAuditOutboxAttempt`       | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpStepUpAuditOutboxDeliveryState` | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpStepUpState`                    | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpStepUpStateStatus`              | USED            | `app/operations/rp_step_up_state_transition_writer.rb`, `app/values/rp_step_up_cell_registry.rb`                                   |
| `RpStepUpStateTransition`          | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |

## RpBaseOrgRecord — `rp_base_org`

| Status          | Count |
| --------------- | ----: |
| USED            |    11 |
| ONLY-VIA-MODELS |     2 |
| UNUSED          |     1 |

| Model                                     | Status          | Reference examples                                                                                                                 |
| ----------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `RpBaseOrgCallbackState`                  | UNUSED          |                                                                                                                                    |
| `RpBaseOrgEventReceipt`                   | ONLY-VIA-MODELS | `app/models/rp_base_org_op_session_binding.rb`                                                                                     |
| `RpBaseOrgIdentityBinding`                | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseOrgOpSessionBinding`               | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseOrgPrincipal`                      | USED            | `app/resolvers/step_up_evidence_resolver.rb`, `app/values/rp_step_up_cell_registry.rb`                                             |
| `RpBaseOrgSession`                        | USED            | `app/resolvers/step_up_evidence_resolver.rb`, `app/services/rp_request_authenticator.rb`, `app/values/rp_step_up_cell_registry.rb` |
| `RpBaseOrgSessionAvatarSelection`         | ONLY-VIA-MODELS | `app/models/rp_base_org_session_selection.rb`                                                                                      |
| `RpBaseOrgSessionSelection`               | USED            | `app/controllers/concerns/browser_rp_authentication.rb`                                                                            |
| `RpBaseOrgStepUpAuditOutbox`              | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpBaseOrgStepUpAuditOutboxAttempt`       | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpBaseOrgStepUpAuditOutboxDeliveryState` | USED            | `app/values/step_up_audit_outbox_sources_registry.rb`                                                                              |
| `RpBaseOrgStepUpState`                    | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseOrgStepUpStateStatus`              | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |
| `RpBaseOrgStepUpStateTransition`          | USED            | `app/values/rp_step_up_cell_registry.rb`                                                                                           |

## RpCoreAppRecord — `rp_core_app`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpCoreAppCallbackState`    | UNUSED          |                                                                                                                              |
| `RpCoreAppEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_core_app_op_session_binding.rb`                                                                               |
| `RpCoreAppIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_core_app_op_session_binding.rb`, `app/models/rp_core_app_principal.rb`                                        |
| `RpCoreAppOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_core_app_identity_binding.rb`, `app/models/rp_core_app_event_receipt.rb`, `app/models/rp_core_app_session.rb` |
| `RpCoreAppPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_core_app_identity_binding.rb`                                                                                 |
| `RpCoreAppSession`          | USED            | `app/operations/rp_callback_committer.rb`, `app/services/rp_request_authenticator.rb`                                        |

## RpCoreOrgRecord — `rp_core_org`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpCoreOrgCallbackState`    | UNUSED          |                                                                                                                              |
| `RpCoreOrgEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_core_org_op_session_binding.rb`                                                                               |
| `RpCoreOrgIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_core_org_principal.rb`, `app/models/rp_core_org_op_session_binding.rb`                                        |
| `RpCoreOrgOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_core_org_event_receipt.rb`, `app/models/rp_core_org_identity_binding.rb`, `app/models/rp_core_org_session.rb` |
| `RpCoreOrgPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_core_org_identity_binding.rb`                                                                                 |
| `RpCoreOrgSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |

## RpEditOrgRecord — `rp_edit_org`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpEditOrgCallbackState`    | UNUSED          |                                                                                                                              |
| `RpEditOrgEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_edit_org_op_session_binding.rb`                                                                               |
| `RpEditOrgIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_edit_org_principal.rb`, `app/models/rp_edit_org_op_session_binding.rb`                                        |
| `RpEditOrgOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_edit_org_event_receipt.rb`, `app/models/rp_edit_org_session.rb`, `app/models/rp_edit_org_identity_binding.rb` |
| `RpEditOrgPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_edit_org_identity_binding.rb`                                                                                 |
| `RpEditOrgSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |

## RpPalmAppRecord — `rp_palm_app`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpPalmAppCallbackState`    | UNUSED          |                                                                                                                              |
| `RpPalmAppEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_palm_app_op_session_binding.rb`                                                                               |
| `RpPalmAppIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_palm_app_principal.rb`, `app/models/rp_palm_app_op_session_binding.rb`                                        |
| `RpPalmAppOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_palm_app_event_receipt.rb`, `app/models/rp_palm_app_identity_binding.rb`, `app/models/rp_palm_app_session.rb` |
| `RpPalmAppPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_palm_app_identity_binding.rb`                                                                                 |
| `RpPalmAppSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |

## RpTechOrgRecord — `rp_tech_org`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpTechOrgCallbackState`    | UNUSED          |                                                                                                                              |
| `RpTechOrgEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_tech_org_op_session_binding.rb`                                                                               |
| `RpTechOrgIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_tech_org_op_session_binding.rb`, `app/models/rp_tech_org_principal.rb`                                        |
| `RpTechOrgOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_tech_org_identity_binding.rb`, `app/models/rp_tech_org_session.rb`, `app/models/rp_tech_org_event_receipt.rb` |
| `RpTechOrgPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_tech_org_identity_binding.rb`                                                                                 |
| `RpTechOrgSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |

## RpWarpAppRecord — `rp_warp_app`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpWarpAppCallbackState`    | UNUSED          |                                                                                                                              |
| `RpWarpAppEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_warp_app_op_session_binding.rb`                                                                               |
| `RpWarpAppIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_warp_app_op_session_binding.rb`, `app/models/rp_warp_app_principal.rb`                                        |
| `RpWarpAppOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_warp_app_event_receipt.rb`, `app/models/rp_warp_app_session.rb`, `app/models/rp_warp_app_identity_binding.rb` |
| `RpWarpAppPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_warp_app_identity_binding.rb`                                                                                 |
| `RpWarpAppSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |

## RpWarpOrgRecord — `rp_warp_org`

| Status          | Count |
| --------------- | ----: |
| USED            |     1 |
| ONLY-VIA-MODELS |     4 |
| UNUSED          |     1 |

| Model                       | Status          | Reference examples                                                                                                           |
| --------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RpWarpOrgCallbackState`    | UNUSED          |                                                                                                                              |
| `RpWarpOrgEventReceipt`     | ONLY-VIA-MODELS | `app/models/rp_warp_org_op_session_binding.rb`                                                                               |
| `RpWarpOrgIdentityBinding`  | ONLY-VIA-MODELS | `app/models/rp_warp_org_principal.rb`, `app/models/rp_warp_org_op_session_binding.rb`                                        |
| `RpWarpOrgOpSessionBinding` | ONLY-VIA-MODELS | `app/models/rp_warp_org_identity_binding.rb`, `app/models/rp_warp_org_event_receipt.rb`, `app/models/rp_warp_org_session.rb` |
| `RpWarpOrgPrincipal`        | ONLY-VIA-MODELS | `app/models/rp_warp_org_identity_binding.rb`                                                                                 |
| `RpWarpOrgSession`          | USED            | `app/services/rp_request_authenticator.rb`                                                                                   |
