# Sphere database consistency

Status: verified (local authorized scope, 2026-11-12).

## Purpose and scope

Align surviving Sphere models, migrations and PostgreSQL constraints without checker exclusions. The
user narrowed the original four-repository request to the current Sphere worktree. Preserve all
pre-existing work. Do not edit CI, Solid Queue, or Blazer. Do not modify shared or production data.
Pending database ownership blocks only the affected database.

## Ownership

`adr/cosmos-common-database-connections.md` assigns independent `primary`, `chronicle`, and
`storage` instances to Sphere. Core app/org, Warp app/org and Palm app RP cells follow the latest
Sphere surface work order. Publishing ownership conflicts between the November 10 clarification and
November 12 surface work order; hold it pending resolution. Other split-era databases require
separate physical ownership classification before edits.

## Acceptance

- AC-1: Classify every configured database; distinguish physical instances, replicas, historical
  migration paths and reserved names.
- AC-2: Run DatabaseConsistency without configuration or disabled checks; partition findings by
  database ownership and keep Solid Queue separate.
- AC-3: For each implemented unit, demonstrate a failing regression before production edits, then
  successful model and PostgreSQL bypass-path tests, lint and relevant regression tests.
- AC-4: Keep existing uniqueness, ownership, lifecycle and deletion guarantees intact.
- AC-5: Verify empty-database migrations separately from existing-schema upgrades, and report
  coverage and unverified acceptance honestly.
- AC-6: KEEP targets have zero DatabaseConsistency reports without suppression, while retaining
  correct database contracts. Direct PostgreSQL success alone does not close this criterion.

## First unit

The five Sphere RP callback-state models have unique `state_digest` database indexes but no matching
model validation. Add validation without changing the stored shape or index. Test valid, duplicate,
missing and distinct digests, cross-cell independence, and direct insert rejection. The database
remains authoritative under concurrent inserts.

## Approved additional units

- Chronicle halt correlations: `SIGN_FLOW_HALTED` context is an object whose `transaction_public_id`
  and `halt_generation` are nonblank strings. Keep the existing partial expression UNIQUE. Reject
  invalid existing rows during constraint validation rather than repairing or deleting audit
  history. The user explicitly accepted this shape on 2026-11-12.
- Client audit UUIDs: align the nullable unique `event_uuid` model contract with PostgreSQL.
  Preserve legacy nil UUIDs and idempotent delivery, including the validation-time contention path.
- Historical Chronicle foreign keys: validate the 19 existing FK contracts missing a historical
  validation step. Empty reconstruction and the existing test schema must agree. Validation-only
  rollback is explicitly irreversible because weakening the FK is not a recovery requirement.
- RP callback digests: the user explicitly accepted exact 32-byte enforcement for `state_digest`,
  `browser_binding_digest` and `nonce_digest` in the five Sphere cells. Keep the bytea shape and NOT
  NULL guarantees; reject existing malformed rows rather than rewriting them.
- JSON expression correspondence: implement real strict JSON-key uniqueness validation on the
  writer, preserve the database expression index, and extend both checker directions to compare the
  same exact tuple/predicate. Reject wrong keys, predicates and invalid configurations; never
  silence an unsupported expression or add a metadata-only validator.

The user subsequently excluded the entire Blazer gem and its persistence from this task. The earlier
approved primary reference unit is withdrawn and its task-only changes are reversed. No Blazer
presence, state or reference hardening remains in scope.

No deployed or shared database migration is authorized by these local implementation units. The
earlier [whole-application remediation](../database-consistency-remediation/spec.md) provides
historical findings, not authority to expand this task into pending or transferred databases.

## Runtime limits

The unmodified standard command initially stops at missing `AUTH_JWT_ISSUER`. A second scan uses the
existing test suite's non-secret `auth-test-issuer` only in the process environment. PostgreSQL
initially required execution outside the sandbox; the current executor has network access. No
credential or environment file is changed.

## Verified implementation and limits

See [session evidence](../../evidence/2026-11-12-sphere-database-consistency-Q8M4.md). The
implemented local units pass 173 regression tests/1,325 assertions. All 31 changed application,
migration and test Ruby files and three changed checker-fork files pass their existing RuboCop
configurations. Eight KEEP writer databases rebuild from empty with no live-schema difference; all
15 writer/test-reader dumps match. Explicit rollback/invalid-row/reapply rehearsals pass. Blazer's
withdrawn unit is completely reversed.

AC-1 through AC-6 have scoped evidence: KEEP checker reports are zero, without configuration or
exclusions. The overall scanner still returns 1 for 707 displayed reports in PENDING/TRANSFER source
schemas, which are deliberately outside the repair boundary. The initially unsupported JSON index is
now matched against a real strict validator; no false-positive waiver remains.

Whole-application coverage thresholds and the committed-dump gate do not pass on this scoped dirty
worktree run; neither is claimed green. Changed models and the new validator have 100% line
coverage, the new validator also has 100% branch coverage, and the changed job has 98% line
coverage. Production migrations, physical transfers and full-suite coverage are not acceptance
claims of this local scope. The ignored nested checker repository is unchanged remotely; its local
patch is preserved in the parent repository for reproducibility.
