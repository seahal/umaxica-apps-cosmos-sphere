# Identifier lookup HMAC credential migration

Date: 2026-11-10. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. The extensive pre-existing
uncommitted worktree and this change affected all results. No commit was created. Scope and
acceptance: `specs/identifier-hmac-credentials/spec.md`; owner request of today, limited to APP/ORG
email and telephone lookup HMAC keys. Broader backlog work was not executed.

## Changes and secret handling

- Located all four assignments in `.env` (original lines 236–239) and `.env.container.devcontainer`
  (original lines 213–216). `LocalEnvironment.load!` in `lib/local_environment.rb`, called from
  `config/boot.rb`, imports the selected local contract; `.devcontainer/compose.yaml` also supplies
  its env file. No target assignments were found in Compose files. Inherited ENV also contained all
  four names; existing processes can retain them.
- Generated eight independent `SecureRandom.hex(32)` values, four per environment, directly into
  `config/credentials/development.yml.enc` and `test.yml.enc`. Decryption, generation and YAML
  replacement occurred in memory. Reopened both payloads, verified the eight values were distinct
  64-character hex strings and that every unrelated entry was unchanged. No key value, prefix or
  fingerprint was emitted or recorded; no plaintext credential file was created.
- Removed only the target assignments from both env files. Final inspection confirmed absence. Other
  repositories' values were neither read nor reused. Their checkouts were not modified.
- `IdentifierBlindIndex` now reads `Rails.application.credentials.option` directly and refuses
  missing/blank credentials. `IdentifierHistoryFingerprintVerifier` checks collisions against the
  same credential source; its separate history secrets were not rotated or migrated.
- Installed Rails `Rails.app.creds` is ENV-first, so using it would violate credentials-only reads.
  The scope's explicit source requirement takes precedence over the backlog's imprecise shorthand.
  The global combined source was not changed. Contradictory exported target variables have no
  authority in the changed readers.
- Updated ENV-dependent rotation/history tests and credential stubs. No fixture edits were needed.
  Scanning fixtures against inherited former target values found no literal dependencies. This does
  not prove absence of every possible precomputed dependency; targeted runtime coverage passed.
- Updated development credential provisioning documentation. The earlier `tmp` inventory remains a
  historical pre-migration snapshot.

## Verification

Initial sandboxed targeted run could not resolve the documented DB host `primary`. Repeating the
same test scope in the approved executor with DB access passed. No database topology was changed.

- `RAILS_ENV=test bin/rails test test/lib/identifier_blind_index_test.rb test/lib/realm_identifier_digest_test.rb test/lib/identifier_history_fingerprint_verifier_test.rb test/services/identifier_blind_index_backfill_test.rb test/services/realm_identifier_hmac_rotation_test.rb`:
  final run **56 runs, 491 assertions, 0 failures, 0 errors, 0 skips**.
- `RAILS_ENV=test bin/rails test test/security`: **107 runs, 621 assertions, 0 failures, 0 errors, 0
  skips**. This ran before subsequent formatting and removal of unused test ENV save/restore code;
  the final targeted scope passed after those edits.
- `bin/rubocop` on both changed application Ruby files and all four changed test files: **6 files
  inspected, no offenses detected**. Corrected formatting only with scoped `-a` first.
- Fresh development process:
  `RAILS_ENV=development bin/rails server -b 127.0.0.1 -p 3011 -P tmp/pids/identifier-hmac-server.pid`.
  Observed listening at `127.0.0.1:3011`. Existing server on 3000 and Vite on 3036 were preserved;
  they were not restarted and are not evidence of loading the new credentials.
- Local HTTP `GET /health/liveness` on port 3011 with `Host: www-jp.umaxica.app` returned **200**.
  The earlier hostless `GET /` returned 404, so it is not used as the successful health observation.
- Read-only development runner called `ClientEmail.find_by_address` and
  `OperatorEmail.find_by_address` with a synthetic nonexistent address: both completed without
  error. No authentication, OTP delivery, provider request or database update was attempted. This
  proves the search operation executes, not that existing stale addresses are found, nor that the
  complete sign-in flow succeeds.

Read-only preflight decrypted identifiers in memory and compared freshly derived digests without
printing identifiers or digests. Only aggregate counts were emitted:

| Model             | Total | Stale digest | Finalized stale | Malformed |
| ----------------- | ----: | -----------: | --------------: | --------: |
| ClientEmail       |     1 |            1 |               0 |         0 |
| ClientTelephone   |     0 |            0 |               0 |         0 |
| OperatorEmail     |     1 |            1 |               0 |         0 |
| OperatorTelephone |     0 |            0 |               0 |         0 |

## Owner approval pending: development reindex

**Not executed.** No development database deletion, reset or reindex was performed. Two existing
emails remain unsearchable through the new lookup digests until reindexing is approved and succeeds.

Procedure proposed for explicit approval:

1. Pause identifier registrations and updates, then repeat the read-only count/decryptability
   preflight. Confirm the development environment and the same model scope, malformed count zero,
   and finalized-stale count zero. Abort on a mismatch; do not silently select another writer.
2. Run inside this repository's documented runtime, with the new credentials:

   ```bash
   RAILS_ENV=development bin/rails runner 'Rails.logger = ActiveSupport::Logger.new(File::NULL); ActiveRecord::Base.logger = nil; begin; puts IdentifierBlindIndexBackfill.new.call.to_h; rescue StandardError => error; warn "Backfill failed: #{error.class}"; exit 1; end'
   ```

   There is no Rake task called `identifier_blind_index_backfill`; the command invokes the existing
   `IdentifierBlindIndexBackfill` service. Its result contains update counts only. Exception details
   and SQL logging are suppressed to avoid recording identifiers or digests. Expected updates at
   this preflight are APP email 1, ORG email 1, both telephone counts 0.

3. Repeat preflight and require stale counts zero. For each existing email, perform lookup using its
   decrypted address in memory and compare returned row identity as a boolean, without outputting
   the address, digest or row ID. Repeating the backfill should report zero further updates.
4. Restart ordinary development processes so all processes use the new credentials, then repeat
   server health and search checks. Do not create or deliver a real login OTP as a smoke check.

Impact: saves update lookup digests and may run existing callbacks/update timestamps. Original
addresses, telephone numbers, ownership and binding facts must be preserved. The service does not
provide a transaction spanning all models/databases; partial completion is possible. Recovery is
fix-forward: stop writes, inspect only safe counts/error classes, repair the prerequisite and rerun
the idempotent service with the same new keys. Do not reset DBs or restore retired/shared keys.

Finalized APP bindings are protected by digest immutability triggers. If any finalized stale row
appears at recheck, stop and obtain a scoped decision on the existing `identifier_hmac:rotate`
maintenance procedure instead. Never disable triggers or use unrestricted direct SQL to bypass them.
AC-1 through AC-5 have the above scoped evidence; AC-6 remains pending owner approval/execution and
post-backfill existing-record lookup verification.
