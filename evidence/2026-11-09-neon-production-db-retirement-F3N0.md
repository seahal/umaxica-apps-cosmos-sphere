# Neon production database configuration removal

Date: 2026-11-09. Sphere HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. The worktree is
uncommitted. This change follows the 2026-11-09 amendment in
[`adr/staging-aurora-postgresql-topology.md`](../adr/staging-aurora-postgresql-topology.md).

Removed the `production:` database entries, the `production_value` lambda, and the conditional
production SSL settings from `config/database.yml`. Removed the Neon-specific assertions from
`DatabasePasswordConfigTest`, and removed its now unused production database-name metadata. Before
`Bundler.require` in `config/application.rb`, production now raises `RuntimeError` with:

> Production database configuration is not set; configure a provider before starting production.

This early check ensures the missing database provider is reported before unrelated production
configuration checks.

## Verification

- `git grep -iw neon -- config/ app/ lib/ test/`: 0 matches.
- `git grep 'NEON_' -- config/ app/ lib/ test/`: 0 code references.
- Rendered the `development` and `test` sections from `HEAD` and the worktree; both parsed
  configurations are unchanged.
- `RAILS_ENV=development bin/rails runner 'puts Rails.version'`: passed, `8.2.0.alpha`.
- `RAILS_ENV=test bin/rails runner 'puts Rails.version'`: passed, `8.2.0.alpha`.
- `RAILS_ENV=production bin/rails runner 'puts Rails.version'`: exited 1 with the explicit
  production database configuration error above.
- `bin/rails test test/unit/database_password_config_test.rb`: 2 runs, 17 assertions, 0 failures, 0
  errors, 0 skips.
- `bin/rubocop config test`: 2,476 files inspected, no offenses.
- `git diff --check`: passed.

No `.devcontainer/`, `compose*.yaml`, or `.env*` path was inspected or modified for this change. No
development or production database was created, reset, or deleted, and no external service was
changed. The unit test used the configured test environment only.
