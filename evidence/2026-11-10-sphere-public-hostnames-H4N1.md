# Sphere Public Hostname Rename — Local Evidence

Date: 2026-11-10. Owner decision: `adr/cosmos-sphere-surfaces-and-rp-independence.md`, "Public
Hostnames for Core, Warp and Palm".

## Revision and scope

- Sphere HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`.
- The checkout already contained extensive staged/unstaged/untracked work. All checks used the
  resulting uncommitted tree; this is not clean-HEAD verification.
- The session-only zero-context diff against the starting file contents has SHA-256
  `6fee8dc2e788339e53f9788a1ad865131fe505ebf8c9877dfb177d261e82d9cc` (before this evidence).
- Core: `www-jp.umaxica.{app,com,org}`; Warp: `warp-jp.umaxica.{app,com,org}`; Palm:
  `palm-jp.umaxica.app`. The `.dev` domain is outside this decision and unchanged.
- No commit, provider operation, container startup/recreation, credential change or retained-data
  migration was performed.

## Changes and registration sources

The public variables in `.env.container.devcontainer`, `.env` and `.env.local` now agree; the latter
files are consumed by host development/test boot. A line-by-line check verified six public
hostname-only replacements in each file, with every other line unchanged. Secret values were not
printed or included in the evidence. Palm is unchanged.

Compose was writable: the Core aliases remain `www-jp.*`, and three `warp-jp.*` aliases were added.
No container was restarted; effective Compose DNS is unverified.

Production Host Authorization now names the new families and removes the retired bare regional
APP/COM/ORG authorities. Regional root destinations, Jump JWT issuer metadata, route/Jump fixtures,
CI configuration, OpenAPI servers and current documentation were updated. The earlier canonical Core
ADR has an amendment identifying the superseding hostname decision; historical decision context
remains historical.

`OidcClientRegistry` reads `OidcClientStoresStaticClientStore`. Core APP/ORG, Warp APP/ORG and Palm
APP use their respective `PUBLIC_*_SERVICE_URL` / `PUBLIC_*_STAFF_URL`. The static store combines
environment and boot hosts, so both must agree. These construct `/oidc/callback`,
`/sign/out/completion?ri=...` and `/oidc/closures`. `OidcRedirectUriPolicy` retains exact membership
checks. Jump resolves the same public origins through `JumpRtSurface`; its approved namespace edges
are unchanged. There are no new corporate OIDC clients.

Added behavioral assertions cover the five client registrations, exact callback and logout
registrations, back-channel endpoints, retired/wrong-family and suffix-confused authorities,
trailing-slash callback rejection, and retired Jump authorities. Existing signed-return, JWKS, Warp
route and SSO tests were updated to the new names. These assertions have not executed.

## Verification results

- Passed: Ruby 4.0.9 syntax checks (`ruby -c`) for all 14 affected Ruby files.
- Passed: `git diff --check` (whole existing checkout diff).
- Passed: public-variable mapping checks in all three environment files and a retired bare regional
  APP/COM/ORG authority scan of active `app`, `lib`, `config`, `.github` and `openapi`.
- Blocked: `bin/rails test test/security` under the default Ruby 3.4.10 fails during boot at
  `LocalEnvironment::Pathname` before test discovery. The repository declares Ruby 4.0.7.
- Blocked: the related test command below, retried with installed Ruby 4.0.9, fails during Bundler
  setup: `flipper` Git dependency at `main@cc573c8` is not checked out (`Bundler::GitError`).
  Native-extension dependencies are also incomplete. No assertions or database preparation ran.
- Blocked: `bin/rubocop`, using Ruby 4.0.9, fails at the same Bundler Git dependency before
  inspection.
- Blocked: `podman ps --format '{{.Names}}'` fails obtaining configuration because its runtime
  directory is read-only. No container command or Rails HostAuthorization middleware probe could be
  executed in the documented runtime.

Related test command attempted (with the Ruby 4.0.9 bin directory prepended to PATH):

```bash
bin/rails test test/security test/services/jump_rt test/values/oidc_client_registry_test.rb test/services/oidc/client_registry_test.rb test/adapters/oidc_backchannel_logout_client_test.rb test/integration/jump_rt_return_verification_test.rb test/integration/jump_rt_issuer_jwks_authority_test.rb test/integration/warp_sso_start_contract_test.rb test/integration/routes/warp_route_contract_test.rb test/lib/config_values/host_family_values_test.rb test/values/regional_root_url_registry_test.rb
```

Security tests, related tests, RuboCop, effective HostAuthorization and end-to-end OIDC/Jump
behavior remain unverified. The requested passing acceptance gate has not been met. Dependencies and
Podman were not repaired as part of this hostname-only change.

## Preserved boundaries and remaining work

Historical ADR/evidence/research/archive text and explicit rejection cases may name retired hosts;
these are not permitted runtime aliases. Publishing hosts such as `docs.jp.*`, `.dev` hosts and
other regions are independent contracts and unchanged. `CoreRpBridge` still recognizes the
pre-existing stored legacy host values; no persistence bridge or authoritative stored data was
changed. That callback is not a redirect/HostAuthorization allowlist.

The prior Core operations memo claimed legacy HostAuthorization aliases were still accepted; its
current host description was corrected to match configuration. The Cloudflare request-path document
still contains an explicitly historical observation linked to its original evidence.

Access lives outside this session's writable roots. It was inspected read-only and remains
unchanged. Its registration sources and an unapplied public-only patch are recorded in
`2026-11-10-access-oidc-hostname-proposal-A7C2.md`. Access implementation and its test/security gate
are outstanding. No Cloudflare DNS, Tunnel, Access application, Turnstile widget or external Jump
configuration was inspected or changed; those remain coordinated external work.

## Session-edited paths

- `app/values/regional_root_url_registry.rb`
- `lib/jit_security_jwt_registry.rb`
- `config/environments/production.rb`
- `test/values/regional_root_url_registry_test.rb`
- `test/values/anonymous_com_preference_token_shape_test.rb`
- `test/integration/jump_rt_issuer_jwks_authority_test.rb`
- `test/integration/jump_rt_return_verification_test.rb`
- `test/integration/warp_sso_start_contract_test.rb`
- `test/lib/config_values/host_family_values_test.rb`
- `test/integration/routes/warp_route_contract_test.rb`
- `test/services/jump_rt/surface_identity_test.rb`
- `test/services/jump_rt/return_policy_test.rb`
- `test/services/jump_rt/issuer_test.rb`
- `test/fixtures/files/jump_app_org_candidate_graph.json`
- `test/fixtures/files/jump_production_graph_0_4_0.json`
- `docs/reference/ui-view-inventory.md`
- `docs/architecture/cloudflare-request-paths.md`
- `docs/backlog/2026-11-09-core-jp-app-path-route.md`
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
- `docs/operations/jump-rt-visa-edges.md`
- `openapi/bundled/openapi.app.yml`
- `openapi/bundled/openapi.org.yml`
- `openapi/org/paths/token-refresh.yml`
- `openapi/org/paths/session.yml`
- `openapi/org/paths/preferences-theme.yml`
- `openapi/org/paths/preferences-cookie.yml`
- `openapi/app/paths/preferences-cookie.yml`
- `openapi/app/paths/preferences-theme.yml`
- `openapi/app/paths/token-refresh.yml`
- `openapi/app/paths/session.yml`
- `.github/workflows/ci.yml`
- `.env.container.devcontainer`
- `.devcontainer/compose.yaml`
- `.env`
- `.env.local`
- `adr/core-canonical-public-host.md`
- `test/values/oidc_client_registry_test.rb`
- `docs/operations/xper-phase-one-activation-gate.md`
