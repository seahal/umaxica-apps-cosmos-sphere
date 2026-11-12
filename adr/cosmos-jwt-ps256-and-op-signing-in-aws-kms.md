# Cosmos JWTs Use PS256, and the OP Signs Through AWS KMS (2026-11-09)

## Status

Accepted (2026-11-09). Implementation starts after the Cosmos repository split is complete; until
then the existing ES384 keys and key handling stay unchanged. The implementation proposal is
`docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md` (Access repository).

This record replaces the key specification in the 2026-10-23 amendment of
`adr/runtime-secret-isolation-deferred.md` (`ECC_NIST_P384`, `ECDSA_SHA_384`) and the "Only ES384"
part of decision 5 of `adr/cosmos-signing-key-management.md` (Proposed, on hold). The other parts of
those records are unchanged.

Amended 2026-11-10: the same design covers every repository's own signing keys, not only the OP's.
Each repository (Access as OP; Governance, Press and Sphere as RPs signing `private_key_jwt` client
assertions) keeps its private signing keys in AWS KMS, signs with `kms:Sign` on its own keys only,
and publishes the matching public keys at its own `/.well-known/jwks.json` (for example
`https://www.umaxica.app/.well-known/jwks.json` for Governance Base App), built from `GetPublicKey`.
A JWKS lists every public key still needed for verification (current and rotating `kid`s); each
private key stays in KMS. Development and test stub the KMS client as described for the OP. The
"Storage of RP private keys" item under "Not Decided Here" is resolved by this amendment, except for
Sphere regions without AWS, which remain open.

Amended again 2026-11-10 (owner): **one signing key set and one JWKS per repository, not per
client.** Keeping a separate key per OIDC client is more than the owner can maintain. Each
repository has one active signing key (plus keys still rotating out), and every client and surface
of that repository uses it: Governance's Base App, Base Org and Tech Org share Governance's key;
Sphere's clients share Sphere's key. The same key also signs that repository's other JWTs that are
not OIDC or OAuth. Every host of the repository serves the same `/.well-known/jwks.json`, and every
Access client registration of that repository names the repository's JWKS URL as `jwks_uri`
(Governance: `https://www.umaxica.app/.well-known/jwks.json`). Because one key signs several token
kinds, each token must state what it is (`typ`, `iss`, `aud` and purpose claims) and every verifier
must check them, so a token issued for one purpose is refused for another.

Amended a third time 2026-11-10 (owner): **Jump tokens move to PS256 as well.** Both the `rt` tokens
Rails issues to Jump and the return tokens Jump issues back (today ES384,
`adr/secure-jump-link-redirector.md`) follow this record. This needs changes in Rails and in the
Jump gateway (Hono on Cloudflare Workers, `umaxica-apps-edge-jump`), in this order: verifiers on
both sides accept PS256 alongside ES384 by `kid`; issuers switch to PS256; ES384 is removed once no
unexpired ES384 token can remain. Jump keeps its own signing key in Cloudflare Workers secrets and
signs with WebCrypto RSA-PSS (owner, 2026-11-10): Workers have no AWS KMS binding, and calling KMS
would add latency to a gateway whose value is having none. This is a deliberate exception to "the
private key never leaves KMS": the Jump key is visible to whoever administers the Workers secrets,
so restrict that access, rotate the key on any suspicion, and keep Jump's token lifetime short.

## Context

Every JWT is signed with ES384 today, and Discovery advertises only ES384 for both
`id_token_signing_alg_values_supported` and `token_endpoint_auth_signing_alg_values_supported`
(`app/values/oidc_discovery_document.rb`).

Access is the only OP and the only issuer of ID and access tokens. Governance, Press and Sphere are
first-party RPs. Production runs on AWS EKS. Sphere is deployed region by region and may run where
AWS is unavailable, so RPs must verify tokens from the OP's public keys alone.

The owner compared RS256, PS256, ES256 and ES384, and AWS KMS, Secrets Manager, SSM Parameter Store,
CloudHSM and Kubernetes Secrets. The deciding distinction was between storing a private key and
signing with it: with Secrets Manager and similar stores the application fetches the private key and
signs; with AWS KMS the private key stays inside KMS and the application receives only the signature
from the `Sign` API.

## Decision

1. **JWTs are signed with PS256 (RSASSA-PSS with SHA-256) using RSA 3072-bit keys.** The algorithm
   applies to ID tokens, access tokens and the other JWTs Cosmos signs. Whether these use one key or
   separate keys per purpose is not decided here.
2. **Reasons for PS256:**
   - it is allowed by the FAPI 2.0 Security Profile (PS256, ES256, EdDSA with Ed25519), which does
     not allow RS256;
   - it uses the PSS padding scheme rather than PKCS #1 v1.5;
   - AWS KMS, Google Cloud KMS and Azure Key Vault all support it, so moving provider keeps the
     algorithm;
   - common JWT libraries support it.
3. **RSA 3072-bit keys** exceed the FAPI minimum of 2048 bits and give about 128-bit security for
   long-lived keys.
4. **In production, the OP signs through AWS KMS and never holds the private key.** Key settings:
   `KeySpec` `RSA_3072`, `KeyUsage` `SIGN_VERIFY`, signing algorithm `RSASSA_PSS_SHA_256`, JWT `alg`
   `PS256`. Public keys are published in the OP's JWKS. KMS only signs; deciding whether a token may
   be issued, and its claims, remains Access's responsibility.
5. **Access reaches KMS through EKS Pod Identity (first candidate).** Only Access's ServiceAccount
   is associated with the signing IAM role, and that role may call `kms:Sign` only on the designated
   keys, restricted with `kms:SigningAlgorithm`. Governance, Press and Sphere get neither OP private
   keys nor `kms:Sign`. No long-lived AWS access key is stored in a pod or in Rails credentials.
6. **Verification never calls KMS.** RPs verify tokens locally with the OP's JWKS, so verification
   volume does not depend on KMS availability or cost.
7. **Discovery advertises PS256 only, and its two algorithm fields are managed separately.**
   `id_token_signing_alg_values_supported` states how the OP signs ID tokens;
   `token_endpoint_auth_signing_alg_values_supported` states which client assertion algorithms the
   OP accepts. Each client registration sets `id_token_signed_response_alg` to `PS256`.
8. **Portability is achieved by rotation.** KMS private keys are not exported. Moving to another
   provider or region creates new keys there and switches over through JWKS and `kid`. AWS KMS
   multi-Region keys may be used if Access ever signs from several AWS Regions; adopting them and
   creating replicas are separate decisions.
9. **No fallback that moves the private key into the application.** When KMS is unavailable, token
   issuance fails; there is no alternative path that exports or caches the private key.

## Deliberate Departure from OpenID Connect

OpenID Connect Core 1.0 section 15.1 requires an OP to support RS256 for ID tokens, and OpenID
Connect Discovery 1.0 requires `id_token_signing_alg_values_supported` to include RS256. Advertising
PS256 only does not meet these requirements. This is deliberate, to align with the FAPI 2.0
algorithm set. Today every RP is first party and can request PS256. Supporting external RPs that
assume RS256, or seeking OpenID certification, requires a new decision. Adopting PS256 alone does
not make Cosmos conformant to FAPI 2.0 as a whole.

## Consequences

- The OP's private signing keys leave the Rails process; a compromised Access pod can still request
  signatures while it holds `kms:Sign`, so IAM and key policies are the control that matters.
- Token issuance depends on KMS availability and latency; verification does not.
- Signatures grow from 96 bytes (ES384) to 384 bytes; tokens stored in cookies or headers must be
  checked against size limits.
- RSA signatures are used in JWS as returned by KMS; the DER-to-`R || S` conversion needed for ECDSA
  does not apply. Interoperability with the Ruby JWT library still needs testing.
- Cost is not a blocker: KMS charges per key per month and per signing request, and only issuance
  calls KMS. Regional prices are checked at implementation time.

## Not Decided Here

- Storage of RP private keys for `private_key_jwt`, including Sphere regions without AWS.
- Whether ID tokens, access tokens and other JWTs share a key.
- Signing in development and test, where AWS KMS is not available.
- The ES384-to-PS256 migration window and the handling of tokens issued before it.
- Algorithms of JWTs that Cosmos verifies but does not sign, such as DPoP proofs.
- Whether `kms:Sign` stays with the Access Rails process or moves to a narrow signing component that
  sets `iat` and `exp` itself (see the threats section of the backlog entry).
