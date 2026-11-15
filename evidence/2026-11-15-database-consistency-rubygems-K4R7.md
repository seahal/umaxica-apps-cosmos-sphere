# DatabaseConsistency from RubyGems (2026-11-15)

HEAD: `f65f1f29bcab40b8f9f921678ccffd034e21d355`. Uncommitted worktree (pre-existing changes
preserved); results apply to it. Run in the `cosmos-sphere-devcontainer-core` container. No commit,
no credentials change.

## Change (owner request: use the published gem, no fork)

- `Gemfile`: `gem "database_consistency", require: false` (was `path: "vendor/fork/..."`).
  `Gemfile.lock`: fork PATH entry removed, `database_consistency (3.1.2)` from RubyGems with
  checksum; no other lock change (platforms and `BUNDLED WITH 4.0.24` kept).
- `JsonbKeysUniquenessValidator`: `kind` is `:uniqueness`; requires `source_attribute`, `scope` and
  `conditions`; validates `source_attribute` itself. Behaviour (writer role, tuple, predicate,
  strict `RecordNotUnique`) is unchanged.
- `OperatorChronicle`: declared with `validates_with`, attributes and scope set to the partial
  index's normalized expression terms, `conditions` to its predicate (same approach as Governance
  `evidence/2026-11-14-database-consistency-zero-DCA4.md`).
- Tests: tooling test rewritten for the released checker (match, missing validator fails, other
  predicate fails); validator and model tests use the new declaration; metadata validation test
  added. Fork-only tests removed.
- `patches/` removed; two architecture docs updated.

## Results

| Check                                                                       | Result                                               |
| --------------------------------------------------------------------------- | ---------------------------------------------------- |
| `database_consistency` before validator change (released gem)               | 1 finding (UniqueIndexChecker, OperatorChronicle)    |
| `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` after | exit 0, zero findings                                |
| Focused tests (tooling, validators, model)                                  | 72 runs, 258 assertions, 0 failures/errors/skips     |
| `env -u POSTGRESQL_TEST_PREPARE_DATABASES bin/rails test`                   | 1837 runs, 12762 assertions, 0 failures/errors/skips |
| `bin/rubocop`                                                               | 815 files, no offenses                               |
| `bin/rails zeitwerk:check`                                                  | All is good                                          |

The ignored local checkout `vendor/fork/database_consistency` is no longer referenced and was left
in place.
