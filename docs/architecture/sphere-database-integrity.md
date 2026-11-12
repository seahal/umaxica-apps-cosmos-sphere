# Sphere database integrity

Use [database disposition](sphere-database-disposition.md) before changing a connection's schema.
These contracts apply only to retained Sphere stores, not transferred source databases.

## RP callback state

Core app/org, Warp app/org and Palm app store callback state in separate physical RP databases.
Within each cell, `state_digest` is unique. Identical digests in different cells do not confer
shared identity or state. Model validation gives an early duplicate error; the existing PostgreSQL
unique index remains the authority when concurrent writers both pass validation.

The three binary digest columns (`state_digest`, `browser_binding_digest`, `nonce_digest`) carry
32-byte digests. PostgreSQL bytea does not enforce the historical migration's `limit: 32` as a
length constraint; explicit octet-length CHECKs and model byte-length validation enforce the
accepted contract. A multibyte string is measured after binary attribute conversion, in bytes. The
existing realm/client identity CHECKs continue to isolate each cell.

## Chronicle

`client_chronicles.event_uuid` is unique when present. Multiple historical events without an event
UUID remain valid. Social audit delivery handles both database-time uniqueness contention and
validation-time contention after an earlier stale lookup. Only an event-UUID `taken` error is
recoverable; other validation failures propagate. Existing audit content must match the Source event
before the Source is acknowledged. A conflicting UUID never acknowledges another event.

For `OperatorChronicleEvent::SIGN_FLOW_HALTED`, context must be an object containing nonblank string
`transaction_public_id` and `halt_generation` values. A CHECK rejects SQL UNKNOWN as well as false,
closing the missing-key and JSON-null cases. The partial unique index on the two JSON text
expressions remains unchanged. Distinct transactions or generations remain independent; other event
types are outside the halt predicate. No trimming or normalization changes correlation identity.
Existing malformed audit rows cause migration validation to fail and require a separate
owner-approved recovery decision.

`JsonbKeysUniquenessValidator` performs a real parameterized writer query for the exact JSON-key
tuple and the explicitly declared event predicate, excluding the same persisted record on update. An
extra context field cannot evade it. Predicate columns and values must match the model's actual
database types; misconfiguration raises instead of silently skipping validation. The validator and
checker consume the same `predicate_for(model)` result. The writer is a statically declared abstract
record and must own the validated record.

Preflight duplicates raise `ActiveRecord::RecordNotUnique` through Rails' strict validation API.
They have no PostgreSQL cause because no INSERT was attempted. The unchanged index still raises the
native PostgreSQL unique violation for concurrent/bypass writes. Missing/malformed JSON values
remain the CHECK's responsibility. Projected records can still update unrelated fields without
loading or replacing their context. This adds a writer existence query to applicable validation;
production query-plan/latency measurements were not performed.

Nineteen historical Chronicle foreign keys enforced new writes without ever validating existing rows
in the migration history. An explicit validation-only migration closes that gap and makes an empty
rebuild agree with the current validated test schema. It never deletes or repairs rows. Validation
cannot be undone without dropping a protection, so its `down` raises explicitly.

## Primary operator tools

Blazer is explicitly outside the owner's repair scope. Its gem, models and tables retain their
existing contracts. No task-specific Blazer constraints or tests are retained.

Flipper's gate table is not treated as a simple foreign-key child of feature keys. The installed
adapter also stores synchronization metadata using a reserved key in that table. An apparently
missing feature reference is therefore not sufficient grounds to add a foreign key.

## Verification scope

DatabaseConsistency checks application model/schema correspondence; PostgreSQL tests separately
exercise raw insertion, update, deletion and concurrency. A checker pass alone does not establish
JSON expression semantics, validated historical rows, or coverage of bundled engine models. Neither
a local empty rebuild nor a test upgrade establishes production data readiness.

The local DatabaseConsistency extension recognizes only simple PostgreSQL `column ->> 'key'`
expression tuples and the real validator's explicit predicate. It compares exact key/column tuples
and predicate literals, including their case; unsupported expressions remain findings. The reverse
check also fails when JSON-key validation lacks an equivalent unique index. No new checker option,
model exemption or connection filter is used. See [the dependency patch](../../patches/README.md).
