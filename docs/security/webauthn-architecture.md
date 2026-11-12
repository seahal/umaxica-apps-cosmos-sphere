# WebAuthn Architecture

## Current status

The surface hard reset removed local WebAuthn assertion, registration, and challenge endpoints.
Edit's browser authentication uses OIDC with its configured identity provider; it does not execute
WebAuthn ceremonies in this application.

The client and operator credential models, ceremony transaction models, their migrations, and
scheduled audit/retention jobs remain for the next model/database review. `Webauthn::Surface` and
per-surface relying-party configuration remain referenced by model concerns. Those retained types do
not expose a current user-facing ceremony.

The previous ceremony design is preserved in accepted ADRs and archived authentication-cycle
material. For current retained data behavior, see [Passkeys](passkeys.md) and
[Passkey lifecycle and audit](passkey-lifecycle-and-audit.md).
