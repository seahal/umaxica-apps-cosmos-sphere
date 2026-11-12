# Cosmos Signing Key Management (2026-11-08)

## Status

Proposed (2026-11-08), on hold. The owner keeps the existing key handling for now, so that the four
repositories first run safely, and will decide after researching key storage options. Nothing in
this record is to be implemented until it is accepted.

On 2026-11-09, `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` decided the algorithm (PS256,
RSA 3072) and OP signing through AWS KMS; the "Only ES384" part of decision 5 no longer applies.

## Context

In development and test, `config/initializers/jwt.rb` calls
`JitSecurityJwtLocalKeysetInstaller.install!` at boot. The installer reads
`tmp/local_jwt_keysets.json` and, when a keyset is missing, silently generates new key pairs (OP
`AUTH`, preference, surface and OIDC client keys) and writes them there. Production already reads
keys through `Rails.app.creds` (`lib/jit_security_jwt_key_source.rb`).

This is unsafe and does not fit the split:

- starting Rails can replace keys without anyone noticing;
- keys live in `tmp/`, outside the credentials path;
- it assumes the OP and every RP share one key file in one application. After the split each
  repository would generate its own unrelated keys, and the OP could not verify RP client
  assertions.

`adr/runtime-secret-isolation-deferred.md` (amendment 2026-10-23) already sets the direction for OP
signing keys: AWS KMS asymmetric keys (`ECC_NIST_P384`, `ECDSA_SHA_384`), the private key never
leaves KMS, and `kms:Sign` is granted only to the OP workload. Rails runs on AWS EKS, each
repository in its own pods. Sphere is deployed region by region and may run where AWS, or KMS in
that region, is not available.

## Decision

1. **The local keyset installer is removed.** No environment generates keys at boot.
2. **A missing required key stops the application.** Required keys are read with
   `Rails.app.creds.require`, not `.option`, consistent with `adr/env-fetch-without-default.md`.
3. **Development and test keys live in each repository's credentials** for that environment (for
   example `config/credentials/development.yml.enc` and `test.yml.enc`). They are created
   deliberately by a person following a runbook, never by the application.
4. **Each repository holds only its own private keys.** Access holds the OP signing keys. Each RP
   (Governance, Press, Sphere) holds only its own `private_key_jwt` client key. No repository holds
   another repository's private key.
5. **Signing goes through one replaceable signer.** Rails code asks a single signer interface to
   sign; implementations are selected by configuration: AWS KMS, another provider's KMS, or a key
   from credentials or a platform secret. Only ES384 (P-384) is used, which AWS KMS, Google Cloud
   KMS and Azure Key Vault all support. KMS returns DER-encoded ECDSA signatures; the signer
   converts them to the JWS `R || S` form.
6. **Production key storage by repository:**
   - Access, Governance and Press: AWS KMS; private keys never leave KMS.
   - Sphere: per region, the strongest store available there (that region's KMS where available,
     otherwise a platform secret such as a Kubernetes Secret), behind the same signer interface.
7. **Portability is achieved by rotation, not by copying keys.** Moving to another provider or
   region creates new keys there; both public keys are published under their `kid` until the old key
   is retired. No procedure exports a private key.
8. **The OP learns RP public keys from each RP's JWKS.** Every RP publishes its client public keys
   at its `jwks_uri` (OpenID Connect Core 1.0 section 9, RFC 7523). Access fetches them from the
   `jwks_uri` registered for that client in Access code (decision 11 of
   `adr/cosmos-identity-authentication-global-authorization-split.md`); a `jwks_uri` is never taken
   from request input. Fetching is HTTPS only, follows no redirects, has short timeouts and a
   response size limit, caches keys by `kid`, refreshes on an unknown `kid` at a bounded rate, and
   fails closed when no valid key is available.

## Consequences

- RPs rotate their own client keys without an Access deployment, which suits Sphere regions with
  different key stores.
- Access gains an outbound HTTP dependency on each RP's `jwks_uri`; an unreachable RP JWKS blocks
  only that RP's client authentication once cached keys are unusable.
- `docs/runbooks/jwt-key-rotation.md` forbids calling KMS or the network in request handlers for
  signing or JWKS rendering. KMS signing at token issuance and RP JWKS fetching conflict with that
  rule; the runbook is revised when this is implemented.
- Development and test need committed, encrypted credentials with keys for every repository before
  the application starts.

## Open Questions

- Preference signing keys: their owner is undecided with preference placement; for now they move to
  credentials unchanged.
- Whether fakecloud supports KMS signing for local development, or development always uses the
  credentials signer.
- The cache lifetime and refresh limits for RP JWKS, and the behaviour while an RP rotates keys.
- Where secrets that Rails needs as raw values (`secret_key_base`, Active Record encryption keys,
  HMAC keys) are stored in production (for example AWS Secrets Manager).
