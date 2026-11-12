# Identifier lookup HMAC credentials

Status: closed. Authority: owner request, 2026-11-10, scoped to the four APP/ORG email and telephone
lookup keys in `docs/backlog/2026-11-10-secrets-from-credentials-only.md`.

## Purpose and scope

Give Sphere independent secrets for identifier search. Generate four independent
`SecureRandom.hex(32)` values in each of development and test credentials. Remove their assignments
from the two local env files and enforce encrypted-credentials-only reads, including
history/live-key separation checks. Preserve other secrets, encryption keys, identity facts,
authentication boundaries and unrelated work. No commit, database reset, provider operation or
broader secret migration is authorized.

`Rails.app.creds` is ENV-first in the installed Rails revision. For these keys use
`Rails.application.credentials.option`; simply deleting an explicit ENV fallback is insufficient.
This resolves the backlog's imprecise description of `creds` in favor of its credentials-only
decision. Existing exported variables must have no authority over these four keys.

## Acceptance

- AC-1: All eight newly generated keys are distinct, at least 256 random bits, and unrelated
  credential entries remain unchanged. Never print or retain plaintext key material.
- AC-2: No target assignments remain in `.env` or `.env.container.devcontainer`; no target
  application reader uses ENV, directly or through combined configuration.
- AC-3: APP/ORG and email/telephone remain isolated. Missing, empty and whitespace credentials fail
  clearly even when ENV contains a key; valid credentials win over contradictory ENV values.
- AC-4: Relevant identifier, history, rotation and backfill tests and `test/security` pass; Ruby
  changes pass RuboCop. Test fixtures do not require the retired key values.
- AC-5: A fresh development server boots and email lookup completes without an error. Existing
  identifiers are not claimed searchable until authorized reindexing completes.
- AC-6: Present a concrete development backfill procedure, impact and recovery; obtain explicit
  owner permission before any development database update. Record actual results in evidence.

## Execution and limits

Inspect settings without exposing values; write credentials in memory; remove definitions; update
readers/tests; verify; inspect development data read-only; request approval for backfill. The
ordinary backfill saves records separately across databases and may partially complete. Finalized
APP rows require the existing restricted maintenance path instead; never bypass triggers. The owner
gate remains open until explicit approval. Keep incomplete acceptance open.

## Completion

All six acceptance criteria are satisfied within this repository's local scope. Credential/source
migration, targeted tests, security tests and RuboCop are recorded in
`evidence/2026-11-10-identifier-hmac-credentials-H4K8.md`. After explicit owner approval, the two
existing development emails were reindexed, existing-row lookups passed, the repeat updated zero
rows, and the ordinary development processes restarted with health HTTP 200; see
`evidence/2026-11-10-identifier-hmac-backfill-H4K9.md`. No database reset or commit occurred.
Current provisioning guidance is maintained in
`docs/operations/development-credential-provisioning.md`. Complete interactive sign-in and changes
to other repositories remain outside the verified scope.
