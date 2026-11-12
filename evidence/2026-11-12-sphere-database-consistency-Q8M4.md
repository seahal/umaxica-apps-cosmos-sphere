# Sphere database consistency repair

Date: 2026-11-12. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`, branch `feature`. The worktree
already contained extensive uncommitted split changes. Those changes affected boot, models, locales,
schemas and verification. This records the dirty worktree, not the committed HEAD alone. No commit,
CI change, production/shared-database operation, checker configuration or credential edit was
performed.

## Scope and disposition

The user narrowed the original four-repository request to Sphere. Access/Governance GitHub database
files were read only as potentially stale reference; no remote write occurred. The owner later
excluded Blazer completely. Its initially approved two migration changes were rolled back on the
local test primary database and their two files/test removed. Primary retains only its original
versions `20260807000000` and `20260915000000`, the three original nullable references and no
task-specific Blazer constraints. Its dump is unchanged by this task.

Complete connection classification and decision conflicts:
[Sphere database disposition](../docs/architecture/sphere-database-disposition.md).

- KEEP: primary, chronicle, storage, rp_core_app, rp_core_org, rp_warp_app, rp_warp_org,
  rp_palm_app.
- TRANSFER source schemas: avatar; op_base_app/org; rp_base_app/org and rp_tech_org. No repair.
- PENDING: publishing, rp_edit_org, app/org_zenith, app/org/com_setting, app/org_signal, search,
  occurrence. No repair. Publishing's November 10/12 ownership conflict remains unresolved.
- EXCLUDED: Solid Queue and, by the later instruction, Blazer. Historical Solid Cache is retired.
- Replica classification follows the writer, but test replicas are separate physical databases.

## Implemented units

| Unit                               | Model/runtime change                                                                                                       | PostgreSQL/migration change                                                                                                 |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Five Sphere RP callback states     | Add state_digest uniqueness and exact 32-byte validation on state/browser-binding/nonce digests                            | Ten new migrations: add 15 NOT VALID byte-length CHECKs, then validate; five generated dumps updated                        |
| ClientChronicle event UUID         | Nullable uniqueness; SocialAuditDeliveryJob recovers only UUID-taken validation contention and still checks event identity | Existing nullable unique index preserved; no schema change                                                                  |
| OperatorChronicle halt correlation | Real strict writer validation of the JSON-key tuple; preserve RecordNotUnique class and projected-update behavior          | Two migrations enforce object context and two nonblank string correlation keys; preserve existing partial expression UNIQUE |
| Historical Chronicle FKs           | No model or deletion policy changed                                                                                        | One migration explicitly validates 19 historical FKs on ten tables; no delete/repair/cascade                                |
| Checker expression support         | Match the actual JSON-key validator and shared canonical predicate in both directions; mismatches still fail               | No schema change or checker configuration; ignored local fork patch preserved in parent repository                          |

Thirteen migrations were added; no historical migration was rewritten or removed. Chronicle FK
validation-only down explicitly raises IrreversibleMigration rather than dropping protection. Halt
and RP check pairs were rolled back/reapplied on disposable databases successfully. See
[the current contract](../docs/architecture/sphere-database-integrity.md) and
[accepted task](../specs/sphere-database-consistency/spec.md).

## TDD and behavioral verification

Actual PostgreSQL: 18.6. Rails ran with RAILS_ENV=test. The standard bare scanner initially failed
before inspection because AUTH_JWT_ISSUER is absent. Subsequent Rails commands supplied only an
existing non-secret test-fixture issuer in the process environment; no persisted configuration was
changed. Initial sandbox DNS isolation required escalation; later execution had direct access.

| Red observation before its implementation                                                    | Green evidence                                                                                                                                             |
| -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RP duplicate accepted: 2 tests/21 assertions, 1 failure                                      | All five cells reject duplicates; real two-writer contention commits exactly one row per cell                                                              |
| RP byte lengths: 4 tests/78 assertions, 3 failures                                           | NULL, empty, 31/32/33 bytes, binary/non-ASCII, Unicode byte lengths, insert_all! and update_all covered                                                    |
| Halt correlation: 5 tests/12 assertions, 2 failures                                          | JSON null/array bypass closed; missing/empty/whitespace/type classes, exact duplicates and independent tuples covered                                      |
| Client UUID: 5 tests/24 assertions, 1 failure; validator-only exposed job contention failure | Model/DB duplicate rejection, legacy nils, validation-time and real database-time contention, identity conflicts and unrelated validation errors covered   |
| Empty Chronicle rebuild differed on 19 FK validation flags                                   | Explicit migration closes all differences; environment construction verified operationally, not with setup tests                                           |
| JSON expression preflight: 8 tests/21 assertions, 4 failures                                 | Real JSON tuple validation rejects duplicates, preserves strict exception class, scopes other events and excludes its own row                              |
| Checker expression correspondence: 6 tests/18 assertions, 3 failures                         | Actual equivalent expression passes both checker directions; wrong key/column/predicate, absent validator/nonunique index and literal-case mismatches fail |
| Predicate type/configuration: 12 tests/52 assertions, 2 failures                             | Missing columns and noncanonical scalar types explicitly raise; checker consumes the same public predicate_for API                                         |

Final regression command:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/models/*chronicle*test.rb \
  test/models/sphere_rp_callback_state_consistency_test.rb \
  test/models/sphere_rp_callback_state_race_test.rb \
  test/models/sphere_rp_callback_digest_length_test.rb \
  test/jobs/social_audit_delivery_job_test.rb \
  test/jobs/social_audit_validation_race_test.rb \
  test/operations/rp_callback_committer_test.rb \
  test/operations/rp_cell_session_revoker_test.rb \
  test/tooling/database_consistency_jsonb_uniqueness_test.rb \
  test/validators/jsonb_keys_uniqueness_validator_test.rb
```

Result: **173 tests, 1,325 assertions, zero failures/errors/skips**, exit 0. After independently
upgrading test reader databases, the two RP operation files passed again: 19 tests/131 assertions,
zero failures/errors/skips. Nanoid emits an existing Ruby frozen-string warning; it was not hidden.

RuboCop on all 31 changed application/migration/test Ruby files: zero offenses, exit 0. The three
changed fork source files also pass that fork's existing RuboCop config. Scoped git diff --check
passed in both repositories; reverse git apply --check confirms the saved patch matches the fork.
The same regression command with COVERAGE=true had 173 passing tests but exit 2 from repository-wide
coverage floors: lines 19,831/37,842 (52.40%), branches 234/7,184 (3.25%), methods 422/5,861
(7.20%). Those floors measure the whole application, while this run is deliberately scoped. They
were not changed or disabled. Changed RP models: 17/17 lines each; ClientChronicle: 40/40;
OperatorChronicle: 37/37; JsonbKeysUniquenessValidator: 47/47 lines and 22/22 branches;
SocialAuditDeliveryJob: 49/50 (98%). Its unexecuted line rejects unsupported Source event names; the
Source's normal validated taxonomy cannot produce that branch. No full-suite coverage pass is
claimed.

## Reconstruction, upgrades and schema correspondence

All eight KEEP writer databases were constructed from empty disposable databases by their existing
Rails migration paths, compared with current live schemas (columns/defaults/types/nullability,
indexes, FK options and CHECKs), then individually dropped. No existing database was dropped.

| Database                         | Full migration count | Empty rebuild | Live-schema differences |
| -------------------------------- | -------------------: | ------------- | ----------------------: |
| primary                          |                    2 | passed        |                       0 |
| storage                          |                    1 | passed        |                       0 |
| chronicle                        |                   33 | passed        |                       0 |
| Each of the five Sphere RP cells |              10 each | passed        |                       0 |

The owning SchemaDriftVerification dump comparison also passed for all eight writer configurations
and all seven independent test reader databases: **15/15 generated dumps match**. Six test reader
databases initially lacked these new migrations (Chronicle 30->33; five RP stores 8->10). Their
exact test names were checked before applying the same migrations through maintenance-only writer
connections. Application replica flags/roles and configuration remain unchanged. An initial attempt
using their read-only configuration was refused; no protection was disabled in application code.

Every RP check pair was rehearsed on a disposable database: rollback removes the new checks;
malformed historical data makes validation raise a real PG::CheckViolation; the row and unapplied
version remain; deleting only that disposable fixture permits reapply; all three checks validate.
Chronicle halt rollback/reapply and invalid-existing-row failure were likewise observed, including
preservation of the old guard until new validation succeeds. Production data preflight remains
unverified. No schema rewrite automatically applies to any deployed environment.

Live KEEP writer catalog: zero unvalidated constraints, invalid/not-ready indexes, nullable boolean
columns, missing primary keys or exact duplicate indexes; zero noninternal triggers. Storage has no
application tables yet. This does not claim arbitrary semantic index redundancy was proved.

`bin/rails db:verify_no_schema_drift` returned 1. Its implementation also marks any uncommitted
schema dump as drift; it reports six intentionally changed KEEP dumps and eight out-of-scope
pre-existing schema paths. The independent 15/15 live-dump and eight empty-rebuild comparisons above
distinguish actual schema correspondence from that commit-based gate. No clean full-gate claim.

## DatabaseConsistency result and remaining limits

Command: RAILS_ENV=test bundle exec database_consistency, with the process-only issuer above.
Vendored version: 3.0.16. It printed "No configuration files were provided". No checker, model or
connection exclusion was added; no exit status was discarded.

| Scope                   | Before displayed failures | Final displayed failures |
| ----------------------- | ------------------------: | -----------------------: |
| KEEP                    |                         7 |                    **0** |
| PENDING                 |                       515 |                      515 |
| TRANSFER source schemas |                       192 |                      192 |
| Solid Queue             |                0 reported |     0 reported, excluded |
| Total                   |                       714 |                      707 |

Grouped expansion is 730 -> 723 individual failures. Final process exit: **1**.

The last KEEP report initially concerned OperatorChronicle's
uniq_operator_chronicles_sign_flow_halted, UNIQUE on context->>'transaction_public_id' and
context->>'halt_generation' WHERE event_id=18. It is now resolved by a genuine
JsonbKeysUniquenessValidator plus structural checker support, preserving that index. The validator
uses explicit writer ownership, parameterized JSON-key values, own-row exclusion and the same
canonical typed predicate consumed by the checker. Duplicate preflight raises RecordNotUnique
without a PG cause; concurrent/bypass INSERT still raises native PG::UniqueViolation. Existing
duplicate-class assertions and projected-record saves remain valid. No fake attribute validation,
generated stored copies, relaxed uniqueness or checker suppression was introduced.

Both UniqueIndexChecker and MissingUniqueIndexChecker now recognize this real validator kind.
Unsupported JSON functions/casts/operators, different columns/keys/predicates and absent validators
still fail. Literal case is preserved. The fork's version remains 3.0.16, base HEAD
`d5d1781f3d642b428d6a9654099b0cd96ce52fd8`, branch `fix/connection-api-compat`, with three local
modified files. Because vendor/fork/database_consistency is ignored by the parent repository, the
exact source diff is saved as
[patches/database-consistency-jsonb-keys-uniqueness.patch](../patches/database-consistency-jsonb-keys-uniqueness.patch).
Patch SHA-256: `b3c8b0629d07ad8c96f272ea61b4b2025be1868aa39940d638a506ae92ba65d6`. No
nested-repository commit or remote write occurred. Future checkouts need that patch until the
dependency owner incorporates it; no CI/bootstrap flow was added in this task.

The complete multiset of all 707 non-KEEP displayed reports is identical before and after these
changes, not merely equal in count. PostgreSQL catalog verification found no remaining disposable
databases with this task's exact temporary-name prefixes.

Remaining PENDING/TRANSFER counts by connection: publishing 432; app_zenith 53; org_zenith 29;
rp_edit_org 1; op_base_app 88; op_base_org 70; rp_base_app 9; rp_base_org 15; rp_tech_org 1;
avatar 9. Blazer was excluded by the user and is not claimed audited/fixed. Bundler-defined models
are not covered by this checker's project_klass? selection, so absence of engine/framework warnings
is not evidence of engine/framework correctness. Full application tests/coverage, production
migrations and physical transfers remain unverified/outside this local task. **KEEP checker reports
are zero**; global checker reports are not zero. All seven original KEEP reports are resolved, with
no false-positive waiver remaining.
