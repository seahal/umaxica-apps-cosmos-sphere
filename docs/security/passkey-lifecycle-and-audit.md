# Passkey Lifecycle and Audit Contract

This contract covers retained Passkey data and scheduled audit delivery. The surface hard reset
removed local Passkey registration and management routes. The credential models and migrations stay
for the next database review; no current user-facing surface creates a Passkey here.

Retention purge may physically delete old credentials after holds, dependencies, and foreign-key
ordering are checked. A purge event is written to the existing audit outbox before deletion. The
interactive registration, settings removal, and sign-up cancellation flows are retired.

`PasskeyAuditDeliveryJob` delivers retained outbox facts to the common Chronicle using an immutable
`event_uuid`, checks the event identity, and acknowledges only after the Chronicle row is present.
Chronicle outages leave the source fact retryable; duplicate delivery is idempotent. The scheduled
job remains active so existing audit facts and retention events continue to be delivered.

The outbox owns the `surface`, `external_id`, and `actor_ref` references. Additional metadata must
not contain any of those keys; the writer raises and rolls back the principal transaction when a
caller attempts to replace them. System events may omit the actor reference. Delivery preserves the
original occurrence time and target reference even after physical credential deletion.

New interactive Passkey lifecycle events are no longer produced by this application. Raw credential
IDs, public keys, challenges, tokens, OTPs, cookies, and unnecessary PII are never audit payloads.
Passkey Chronicle retention remains TBC.

See [the lifecycle ADR](../../adr/passkey-current-state-limit-and-chronicle-outbox.md) and the
[Passkey audit delivery runbook](../runbooks/passkey.md).
