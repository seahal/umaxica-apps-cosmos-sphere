# Sphere database disposition

Status: current task classification, 2026-11-12. This records the implementation boundary, not
authorization to delete databases or data. The owner narrowed the consistency repair to Sphere.

## Decision sources

Use the current worktree, including its uncommitted split changes. The accepted
[common connection ADR](../../adr/cosmos-common-database-connections.md) assigns separate `primary`,
`chronicle`, and `storage` instances to every Cosmos repository. The latest
[Sphere work order](../../plans/2026-11-12-sphere-test-baseline-and-round2-work-order.md) identifies
Sphere's Core, Warp and Palm surfaces. The
[Base decomposition ADR](../../adr/cosmos-base-surface-decomposition.md) separates canonical
authentication and governance responsibilities. Configured connections alone do not establish
physical ownership.

## Configured writer connections

| Connection                                  | Classification         | Reason                                                                                                                                                                              |
| ------------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `primary`                                   | KEEP                   | Repository-local default database; currently Flipper and Blazer. The owner explicitly excludes Blazer tables and gem behavior from this repair.                                     |
| `chronicle`                                 | KEEP                   | Common ADR retains the full audit schema, including unused tables.                                                                                                                  |
| `storage`                                   | KEEP                   | Common ADR reserves an owned Active Storage role; currently only extensions and Rails metadata, not attachment tables.                                                              |
| `rp_core_app`, `rp_core_org`                | KEEP                   | Sphere Core's independent RP cells.                                                                                                                                                 |
| `rp_warp_app`, `rp_warp_org`                | KEEP                   | Sphere Warp's independent RP cells.                                                                                                                                                 |
| `rp_palm_app`                               | KEEP                   | Sphere Palm's independent RP cell.                                                                                                                                                  |
| `queue`                                     | EXCLUDED               | Solid Queue; no consistency repair, migration or configuration changes in this task.                                                                                                |
| `publishing`                                | PENDING                | November 10 Publishing ADR amendment retains persistence in Sphere; November 12 work order assigns its HTTP surfaces to Press. Physical transfer is not resolved by HTTP ownership. |
| `rp_edit_org`                               | PENDING                | The same Edit ownership conflict; do not infer a physical transfer.                                                                                                                 |
| `app_zenith`, `org_zenith`                  | PENDING                | Authentication and authorization responsibilities split across Access and Governance; whole physical database ownership remains unresolved.                                         |
| `app_setting`, `org_setting`, `com_setting` | PENDING                | Preference placement remains open in the Base decomposition ADR.                                                                                                                    |
| `app_signal`, `org_signal`                  | PENDING                | Business database ownership is not settled by the Sphere surface ADR.                                                                                                               |
| `search`                                    | PENDING                | Common ADR leaves repository adoption open; currently a reserved empty schema.                                                                                                      |
| `occurrence`                                | PENDING                | Common ADR explicitly leaves retention outside Governance unresolved.                                                                                                               |
| `avatar`                                    | TRANSFER to Governance | Canonical avatar data belongs to Governance; Sphere presentation is a separate responsibility. Do not repair the source schema.                                                     |
| `op_base_app`, `op_base_org`                | TRANSFER to Access     | OP authentication and session authority belongs to Access. Do not repair the source schemas.                                                                                        |
| `rp_base_app`, `rp_base_org`, `rp_tech_org` | TRANSFER to Governance | Base and Tech RP surfaces belong to Governance. Do not repair the source schemas.                                                                                                   |

Every configured `_replica` follows its writer's classification. Development uses the writer's
physical database name with a replica host; test configuration names separate physical replica
databases. Neither distinction grants permission to rebuild them indiscriminately.

## Historical and reserved names

- Old Solid Cache storage is RETIRE under
  [the cache separation ADR](../../adr/solid-cache-removal-and-valkey-cache-separation.md). The
  newer common ADR only reserves `cache` and `cable` names; they are not configured here.
- `publisher` is not a current connection and must not be confused with `publishing`.
- `*_principal` connections are not currently configured. The semantic principal records connect to
  Zenith. `app_principals_migrate` and `org_principals_migrate` remain Zenith-owned historical
  migration inputs, not evidence of additional physical principal databases. Read the correction in
  [the consolidation ADR](../../adr/principal-zenith-physical-consolidation.md).
- Historical activity/behavior audit storage was consolidated into Chronicle. An orphan
  `db/audit_schema.rb` does not establish a live `audit` connection.
- The requested historical `plans/immutable-wibbling-jellyfish.md` is absent from this worktree.

## Dependencies and inspection limits

Retention jobs still reference Zenith, Avatar and other split-era stores. Their presence establishes
a remaining dependency, not KEEP ownership. Common ADR decision 5 requires each repository's jobs to
operate only on its own databases; removing or transferring these consumers needs the matching
ownership decision.

The vendored DatabaseConsistency 3.0.16 compares application models. Its `project_klass?` check does
not include models defined under Bundler's path, including framework and engine models. Absence of
primary/storage findings therefore does not prove Flipper, Blazer or Active Storage coverage.
PostgreSQL catalog and direct write tests provide separate evidence.

The user explicitly excluded Blazer during this task. Its bundled model validations, schema, states
and references remain untouched; this is a subsystem scope boundary inside `primary`, not a
database-connection exclusion setting for DatabaseConsistency.

The OperatorChronicle halt index is a legitimate partial unique index on two JSON expressions. Its
real `JsonbKeysUniquenessValidator` now checks the same tuple and predicate on the writer. Its
declaration publishes standard uniqueness metadata (the index's normalized expression terms as
attributes and scope, and the partial predicate as `conditions`), so the released
`database_consistency` gem from RubyGems matches it in both directions without a fork or patch
(2026-11-15). The index itself is preserved.
