# Passkeys

## Current scope

As of 2026-11-11, the application has no local Passkey registration, sign-in, step-up, or management
routes. Edit uses the retained OIDC relying-party flow; credential ceremonies are owned by its
external identity provider.

The Passkey models and migrations remain in the repository for the next model/database review, as
requested for this hard reset. Their presence does not represent a user-facing workflow.

## Retained data and scheduled work

- App and operator Passkey rows, status rows, transaction rows, and audit outboxes remain.
- Model-level credential-ID uniqueness and owner relationships remain in place.
- `PasskeyAuditDeliveryJob` remains in the recurring schedule to deliver existing outbox facts to
  Chronicle. Retention work can also write a purge fact before deleting an old credential.
- `Webauthn::Surface` and the relying-party configuration objects remain because retained model
  concerns still reference them. No route starts a local ceremony.

The persistent data contract is documented in
[Passkey lifecycle and audit](passkey-lifecycle-and-audit.md). The scheduled delivery procedure is
in the [Passkey audit delivery runbook](../runbooks/passkey.md).

## Historical implementation

The former Auth and Base registration, sign-in, step-up, and management flows are retired. The
earlier ceremony design is retained as historical reference in
[WebAuthn architecture](webauthn-architecture.md),
[WebAuthn security invariants](webauthn-security-invariants.md), and the
[RP ID and Origin boundary](webauthn-rp-id-origin-boundary.md). Those pages are not active route or
authentication contracts.
