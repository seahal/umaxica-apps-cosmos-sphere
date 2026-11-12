# Palm Native Clients Use DPoP (2026-11-10)

## Status

Accepted (2026-11-10, owner) as direction. No native client exists yet; implementation follows the
Cosmos split and the PS256/KMS migration.

## Context

Palm is currently a first-party browser RP with no native or bearer-token role
(`docs/architecture/acme-sign-core-base-port.md`; DPoP support exists but is not a default entry,
`adr/acme-sign-core-base-port-boundary.md`). The owner plans Palm clients on iOS and Android: the
user signs in through a browser, the app keeps the resulting tokens in the platform's secure storage
(Keychain, Keystore), and calls Palm APIs with them.

A native app is a public client: it cannot keep a client secret. Secure storage protects tokens at
rest only; a bearer token that leaks in transit, in logs, in a backup or through an intermediary can
be used by anyone who holds it. The Cosmos protocol target is OAuth 2.1, OpenID Connect and the FAPI
2.0 Security Profile (`adr/cosmos-base-surface-decomposition.md`), and FAPI 2.0 requires
sender-constrained tokens (DPoP or mTLS).

## Decision

1. **Palm native clients will use DPoP (RFC 9449).** The app generates its DPoP key inside the
   device's hardware-backed store (Secure Enclave on iOS, StrongBox or the hardware-backed Keystore
   on Android) so the private key cannot be exported. Access and refresh tokens issued to the app
   are bound to that key, and every request carries a DPoP proof.
2. **Sign-in uses the system browser,** not an embedded web view (RFC 8252):
   `ASWebAuthenticationSession` on iOS, Custom Tabs on Android, with PKCE (S256) and a claimed HTTPS
   redirect (Universal Links, App Links) rather than a custom URL scheme.
3. **Tokens live in the platform's secure storage** and are never logged.
4. **Until DPoP is in place,** a native client may start with short-lived access tokens and
   refresh-token rotation with reuse detection (a reused refresh token revokes the whole grant),
   which OAuth 2.1 accepts for public clients. This is a bounded transition; its exit condition is
   DPoP binding for every native token.
5. **Who verifies:** Access (Visa) binds tokens to the DPoP key at issuance and verifies proofs at
   its token endpoint; Palm's API (Sphere) verifies the DPoP proof and the token's key binding
   (`cnf.jkt`) on every request. The existing verifiers (`app/lib/dpop_proof_verifier.rb`,
   `app/services/dpop_request_verifier.rb`) are the starting point and must be reviewed before use,
   as `adr/acme-sign-core-base-port-boundary.md` requires.

## Consequences

- Palm gains a native/bearer role, which the earlier Palm architecture excluded; that statement is
  superseded for native clients when they are built. Browser Palm stays a browser RP with cookies
  and DBSC.
- DPoP plays for native apps the role DBSC plays for browsers: a stolen token is useless without a
  key that never leaves the device.
- Access must issue DPoP-bound tokens and advertise `dpop_signing_alg_values_supported` in
  Discovery.

6. **DPoP proofs use ES256** (owner, 2026-11-10). iOS Secure Enclave keys are P-256 only, so ES256
   is the algorithm both platforms can hold in hardware; it is in the FAPI 2.0 algorithm set.
   Server- issued tokens stay PS256. Moving proofs to PS256 is allowed later if hardware-backed
   RSA-PSS keys become available on both platforms.
7. **Server-provided DPoP nonces are supported** (owner, 2026-11-10), at least at Access's token
   endpoint, so pre-generated proofs cannot be replayed later (RFC 9449 section 8).

## Not Decided Here

- Whether native clients also use device attestation (App Attest, Play Integrity); not required by
  FAPI 2.0.
- How a native client fits FAPI 2.0, which assumes confidential clients authenticated with
  `private_key_jwt` or mTLS. Options: the app talks only to Palm's backend, which is the
  confidential client (consistent with the browser BFF target), or each installation registers as
  its own client with a hardware-held key and attestation. Decide before building the app.
