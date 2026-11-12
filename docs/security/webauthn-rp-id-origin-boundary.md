# WebAuthn RP ID And Origin Boundary

The application has no local WebAuthn routes after the surface hard reset. Edit authenticates
through OIDC and does not use request-derived RP IDs or origins.

The persisted ceremony transaction models and concerns remain until the next model/database review.
When those model paths are evaluated, `Webauthn::RelyingPartyConfigResolver` obtains configuration
for the declared `app` or `org` surface. It does not infer a relying party from the request host or
URL.

This file records the remaining model configuration boundary. The former sign-in, registration,
step-up, challenge, and signed-result flows are historical and are not route contracts.

See [Passkeys](passkeys.md) for the current application scope and
[Passkey lifecycle and audit](passkey-lifecycle-and-audit.md) for retained records.
