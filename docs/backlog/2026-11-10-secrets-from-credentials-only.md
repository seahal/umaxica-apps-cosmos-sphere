# Read Secrets From Rails Credentials Only (2026-11-10)

Owner: this repository (same change in all four Cosmos repositories). Status: decided (owner,
2026-11-10).

## Why

On 2026-11-10 the blind-index keys used by `app/lib/identifier_blind_index.rb`
(`APP_EMAIL_ADDRESS_HMAC_KEY`, `ORG_EMAIL_ADDRESS_HMAC_KEY`, `APP_TELEPHONE_NUMBER_HMAC_KEY`,
`ORG_TELEPHONE_NUMBER_HMAC_KEY`) were found absent from Rails credentials and supplied by
environment variables instead, with identical values in all four repositories. The code reads
`Rails.app.creds.option(key)` first and falls back to `ENV.fetch(key)`, so a secret can silently
come from either place, and the credential inventory (which read only credentials) missed them. The
same check found the realm encryption keys used by `lib/realm_identifier_encryption_key_provider.rb`
(`APP_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `APP_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`,
`ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ORG_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`, and
the `*_PREVIOUS` rotation keys) also come from the environment with identical values in all four
repositories. `secret_key_base` (development `tmp/local_secret.txt`) and the global
`ACTIVE_RECORD_ENCRYPTION_*` keys in credentials already differ per repository. Meanwhile
credentials still held unused older names (`EMAIL_ADDRESS_HMAC_SALT`, `TELEPHONE_NUMBER_HMAC_SALT`).

## Decision (revised 2026-11-10, owner)

These values should not be visible to others, so they do not live in environment variables during
development and test.

- **Development and test:** every application secret lives in the encrypted Rails credentials
  (`config/credentials/<environment>.yml.enc`) and is read with `Rails.app.creds.option(:NAME)`.
  Code never reads a secret with `ENV.fetch` or adds its own `|| ENV.fetch(...)` fallback.
- **No secret in an environment file:** remove these names from `.env.container.devcontainer`,
  `.env` templates, Compose files and CI. In the pinned Rails, `Rails.app.creds` checks environment
  variables (and, in development, dotenv files) before credentials
  (`railties/lib/rails/application.rb`, `creds`), so a leftover variable would silently override the
  credential; `bin/setup` warns when one is present.
- **Each repository has its own values;** none is shared with another repository.
- **Production, later:** production supplies the same names as environment variables from its secret
  store (`adr/cosmos-secret-key-base-in-ssm-parameter-store.md`); `Rails.app.creds` reads them
  without code changes. Until production exists, everything uses credentials.

### Scope: the 22 environment secrets found on 2026-11-10

All were identical across the four repositories:

- Identifier encryption (to be retired with Rails-standard encryption):
  `APP_/ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
  `APP_/ORG_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (and `*_PREVIOUS`).
- Blind indexes: `APP_/ORG_EMAIL_ADDRESS_HMAC_KEY`, `APP_/ORG_TELEPHONE_NUMBER_HMAC_KEY`.
- Identifier history: `APP_/ORG_EMAIL_HISTORY_KEY`, `APP_/ORG_TELEPHONE_HISTORY_KEY`.
- OTP verification: `APP_/ORG_EMAIL_OTP_VERIFIER_KEY`, `APP_/ORG_TELEPHONE_OTP_VERIFIER_KEY`.
- Enforcement: `ENFORCEMENT_APP_IDENTIFIER_HMAC_KEY`, `ENFORCEMENT_ORG_IDENTIFIER_HMAC_KEY`.
- Operator tools: `BLAZER_PASSWORD`, `FLIPPER_UI_PASSWORD`, `PGHERO_PASSWORD` (also identical to
  each other; give each tool its own value).
- Object storage: `OBJECT_STORAGE_SECRET_ACCESS_KEY` (kept; it will be used).

Secrets already in credentials and already distinct per repository: `secret_key_base` (development
`tmp/local_secret.txt`), the global `ACTIVE_RECORD_ENCRYPTION_*` keys, `OCCURRENCE_HMAC_SECRET`,
`PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT`, the JWT keysets, Turnstile (except Access's shared development
widgets).

## Work order (Codex)

```
1. Inventory every secret the application reads with an ENV fallback or directly from ENV
   (Rails.app.creds.option(...) || ENV, ENV.fetch of secrets), including the 22 names above. Names
   only, never values.
2. For each, read it with Rails.app.creds.option(:NAME) only; remove the code's own ENV fallback.
   Put a new random per-repository value into development and test credentials, and delete the name
   from every environment file. Keep the one-argument ENV.fetch rule for non-secret configuration.
3. Remove unused credential entries found on 2026-11-10 (EMAIL_ADDRESS_HMAC_SALT,
   TELEPHONE_NUMBER_HMAC_SALT, DATABASE.*.PASSWORD with no reader), after confirming no reader.
4. Tests: a missing credential fails clearly; no code path reads these secrets from ENV.
5. Run test/security. No commit. Never print values.
```

## Decided later the same day: use Rails' standard Active Record Encryption (owner, 2026-11-10)

Not done now; recorded as the target. The identifier encryption for email addresses and telephone
numbers (`encrypts` in `ClientEmail`, `OperatorEmail`, `ClientTelephone`, `OperatorTelephone`, via
`lib/realm_identifier_encryption_key_provider.rb`) and the global keys
(`lib/jit_security_active_record_encryption_key_provider.rb`) move to Rails' standard mechanism:

- Keys live in credentials under `active_record_encryption` (`primary_key`, `deterministic_key`,
  `key_derivation_salt`, created with `bin/rails db:encryption:init`), read by Rails itself; no
  custom provider, no environment fallback.
- The app/org separation, if still needed in a repository, uses Rails' per-attribute `key:` option
  with a credential value, not a custom key derivation.
- Key rotation uses Rails' `previous` support, not a custom JSON variable.
- Each repository gets new values. Changing the derivation makes existing ciphertext unreadable, so
  do this together with the value change, either discarding development data (hard reset) or
  decrypting with the old provider and re-encrypting with the new configuration.

## Ownership (owner, 2026-11-10)

Email addresses and telephone numbers are identity data, owned by Access only. This repository will
delete `ClientEmail`, `OperatorEmail`, `ClientTelephone`, `OperatorTelephone`, their encryption key
provider and related code once its remaining callers read identity data through Access (step 4 of
`adr/cosmos-base-surface-decomposition.md`, First Step). The encryption change above is not done
here; do not invest in code that is going to be removed.

## Development data when keys change (owner, 2026-11-10)

When the blind-index HMAC keys and the encryption keys get new per-repository values (and, in
Access, the Rails-standard encryption), the development and test databases are destroyed and rebuilt
rather than re-hashed or re-encrypted (hard reset, `adr/cosmos-base-surface-decomposition.md`). No
backfill or re-encryption code is written for development. The destruction itself still needs the
owner's explicit approval when it is run, with the exact databases or volumes named; after the
rebuild, load reference data and confirm sign-in and sign-up work (`bin/setup` should cover this,
`docs/backlog/2026-11-10-bin-setup-one-command.md`). Staging and production are out of scope and
need their own migration plan.

## Retired environment keys (owner, 2026-11-10)

The environment variables `APP_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`APP_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`,
`APP_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`, `ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ORG_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` and
`ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`, and
`lib/realm_identifier_encryption_key_provider.rb`, are to be deleted: in Access when the
Rails-standard encryption replaces them, elsewhere together with the identity models. Delete them
from every `.env*` template, Compose file, CI workflow and document in the same change, and confirm
no code reads them afterwards.
