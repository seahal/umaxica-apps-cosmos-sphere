# Passkey Audit Delivery Runbook

## Scope and trigger

This procedure covers the scheduled delivery of retained Passkey audit outbox rows to Chronicle. The
application no longer has local Passkey registration or management routes. The recurring
`PasskeyAuditDeliveryJob` remains active for existing records and retention-generated purge events.

## Procedure

1. In Mission Control, inspect the recurring task and the latest `PasskeyAuditDeliveryJob` run.
2. If delivery failed, inspect the job's sanitized failure summary and confirm the source row
   remains unacknowledged. Do not edit or delete an outbox row to clear the failure.
3. Retry the failed job through Mission Control after the Chronicle or source database problem is
   resolved. Delivery is idempotent by `event_uuid`; successful rows are acknowledged after the
   Chronicle record exists.
4. Confirm the retry completed and the source row is acknowledged.

## Verification and recovery

Failed rows remain retryable. The delivery job continues through later rows, then raises so the
failure remains visible to operators. If a retry encounters a matching Chronicle UUID with a
conflicting actor, subject, or event, leave both records intact and investigate the mismatch before
retrying.

The job rejects metadata that replaces the source surface, Passkey reference, or actor reference.
Raw credential IDs, public keys, challenges, tokens, OTPs, cookies, and unnecessary personal data
must not be added to audit metadata.
