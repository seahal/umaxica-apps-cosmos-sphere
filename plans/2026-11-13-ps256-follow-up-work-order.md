Task (this repository only): follow Access's complete cut-over to PS256. Unattended run: do not ask
questions; record items that need the owner and continue. Never print secrets, key material or
environment values. Never edit config/credentials/*.yml.enc. No push, no deploy, no change outside
this repository.

## Decision

`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` in Access (Accepted 2026-11-09; read this
repository's copy if it exists, otherwise `../umaxica-apps-cosmos-access/adr/`, read-only). Owner,
2026-11-13: every first-party JWT is PS256 with RSA 3072 or larger, in one cut-over with no period
in which ES384 is also accepted (nothing is launched). Access migrates under
`../umaxica-apps-cosmos-access/plans/2026-11-13-access-ps256-migration-work-order.md`. Signing
through AWS KMS stays deferred: keys load the way they do today.

## Scope

- Verification of tokens Access issues to this repository as an RP: ID tokens, access tokens, logout
  tokens and any other first-party token found by search. Accept only JWKS entries that are `kty`
  RSA, `alg` PS256, `use` sig, public members only, modulus 3072 bits or more; header `alg` must be
  PS256 and equal the selected key's `alg`. Refuse ES384, RS256, PS384, `none`, HMAC.
- Tokens this repository signs: `private_key_jwt` client assertions, Jump `rt`, and any other
  first-party JWT. Sign PS256 with this repository's single key set; publish only RSA PS256 public
  keys at `/.well-known/jwks.json`.
- Jump return-token verification, if this repository has it: PS256 only.
- Docs, OpenAPI and ADR text in this repository that say ES384.
- Unchanged: algorithms chosen by other parties (DPoP proofs, DBSC, WebAuthn, Apple, Google, Entra).

Every other check keeps its order and strictness (`typ`, `iss`, `aud`, expiry, `nonce`, `jti`
consumption, JWKS cache and refetch, fail closed). Wrong key type in configuration fails at boot
naming the variable or credential only.

## Key material (stop point)

Do not create or store real keys. Development and test use the existing local or throwaway keyset
mechanism, changed to generate RSA 3072; tests generate their own keys. For keys that come from
credentials or ENV, report the exact names that must now hold an RSA 3072 PKCS#8 key; the owner
provisions them.

## Tests (Red first)

Per token family: PS256 accepted; ES384-signed token refused; header `alg` mismatch refused; RS256
and PS384 on the RSA key refused; undersized key refused (2048 as the nearest practical value below,
said in the test name; 3072 and 4096 accepted); tampered, expired, wrong `aud`, wrong `typ`. JWKS
endpoint publishes only RSA PS256 keys. Remove tests that only assert ES384.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, bun run check, affected tests, then bin/rails test
(separate pre-existing failures). `grep -rn ES384 app lib config docs adr openapi` shows only
external-protocol items and historical text; list what remains. Record in
evidence/YYYY-MM-DD-ps256-follow-up-XXXX.md (full `git rev-parse HEAD`; uncommitted changes affected
results): families migrated, files, key names the owner must provision, test results, unverified
items (live sign-in against Access cannot be checked tonight), and confirmation that
config/credentials files are unchanged.
