# Sphere route separation progress evidence

Date: 2026-11-09  
Revision: `44dfa264c91c58121e48800c6f2680464914e8c4`  
Worktree: pre-existing uncommitted changes were present and affect these observations. No commit was
created.

## Scope reached

- `config/routes.rb` draws only `core`, `warp`, `palm`, and the retained operations tools `mission`,
  `flipper`, `blazer`, `pghero`, `swagger`, `performance`, and `coverband`.
- Base, Auth, Visa, and Tech route draws and their uncalled route-owned controllers, views, and
  surface-only tests were removed. The remaining controller directory contains Core, Warp, Palm,
  application-level endpoints, and unknown-host handling.
- Avatar social-network screens were not moved to Core, Warp, or Palm. No avatar controller is
  present under `app/controllers` after removing the retired Base surface.
- `BrowserRpAuthentication` and its legacy Access database connection path remain unchanged. The
  local-cell RP migration was not performed.
- The user's listed OpenTelemetry TODO/FIXME markers, MessagePack serializer and gem, and additions
  under `adr/`, `docs/`, and `plans/` were preserved.
- Press route-ownership evidence was reviewed. The referenced Access evidence file was not present
  at the expected local path, so it was not used and no other repository was written.

## Verification at this checkpoint

- Route inventory inspection confirmed the allowed route draws listed above.
- Retained-surface focused tests: 37 runs, 394 assertions, 0 failures, 0 errors. The run covered
  route ownership, Core RP browser entry, Palm entry and landing, runtime-role route guards,
  retained health endpoints, PWA endpoints on Warp and Palm, layout ownership, and active preference
  chrome.
- `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/security`:
  107 runs, 625 assertions, 0 failures, 0 errors.
- An earlier full-suite diagnostic before the last stale-test cleanup completed with 14,964 runs,
  94,280 assertions, 641 failures, and 1,180 errors. Its inventory is
  `/tmp/sphere-route-separation-failure-metadata.tsv`. This is an intermediate result, not the
  post-cleanup full-suite count.
- The latest focused retained-surface run and `test/security` have 0 route-separation-caused errors.
  The post-cleanup full-suite error count and baseline comparison remain pending.

## Constraints and next verification

- Database configuration and application code were not changed to provision or reset development
  data. No external service was changed.
- Next: run the required serial full suite, classify any errors against the 16,910-run baseline (300
  failures, 67 errors), then run RuboCop and Brakeman and record final results separately.
