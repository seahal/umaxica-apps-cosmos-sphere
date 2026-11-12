# Local dependency patches

`database-consistency-jsonb-keys-uniqueness.patch` records the source changes already applied to the
editable `vendor/fork/database_consistency` checkout. That directory is an independent Git
repository ignored by the parent repository; the patch preserves the change for review and reuse
without publishing to GitHub or changing CI.

Base: `seahal/database_consistency`, commit `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`, local branch
`fix/connection-api-compat`, version 3.0.16. On a checkout at that base, inspect and apply with:

```sh
git -C vendor/fork/database_consistency apply --check ../../../patches/database-consistency-jsonb-keys-uniqueness.patch
git -C vendor/fork/database_consistency apply ../../../patches/database-consistency-jsonb-keys-uniqueness.patch
```

Do not apply it again to the current already-patched checkout. It adds correspondence checks for the
real `JsonbKeysUniquenessValidator` contract in both directions: an expression unique index needs
matching validation, and JSON-key validation needs an equivalent unique index. Exact keys, column,
tuple cardinality and partial predicate are compared. Unsupported expressions and missing or
mismatched validators still fail; no checker or model is excluded.

The application validator and its PostgreSQL behavior tests live in the parent repository. The
matcher's positive and negative regression tests are in
`test/tooling/database_consistency_jsonb_uniqueness_test.rb`. Operational results and limits are
recorded in [the session evidence](../evidence/2026-11-12-sphere-database-consistency-Q8M4.md).
