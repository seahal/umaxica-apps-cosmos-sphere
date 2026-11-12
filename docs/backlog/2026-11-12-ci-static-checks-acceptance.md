# Acceptance: Every CI Static Check Reports Nothing, Without Suppression (2026-11-12)

Owner: this repository. Status: **acceptance condition of the Cosmos split** (owner, 2026-11-12).

## Condition

Every static check that `.github/workflows/ci.yml` runs (and `config/ci.rb` where it lists the same
gates) finishes with **zero reported problems**, and no problem is hidden by configuration. Fix the
code, schema or dependency; never silence the check.

| Check                          | Command in CI                                                               | Zero means                                                                                                                                                                 |
| ------------------------------ | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Database consistency           | `bundle exec database_consistency`                                          | no problems, with **no** `database_consistency` configuration (no `.database_consistency.yml`, no `.database_consistency.todo.yml`, no ignore lists, no disabled checkers) |
| RuboCop                        | `bundle exec rubocop --fail-level convention`                               | no offenses, with `.rubocop_todo.yml` **emptied and removed** (it exists today and hides offenses)                                                                         |
| Frozen string literal checks   | `scripts/check_frozen_string_literal_directives.rb` and the follow-up check | clean                                                                                                                                                                      |
| ERB Lint                       | `bundle exec erb_lint --lint-all`                                           | no errors                                                                                                                                                                  |
| i18n keys                      | the CI i18n key check                                                       | no missing or unused keys                                                                                                                                                  |
| Brakeman                       | `bundle exec brakeman ... -z`                                               | no warnings, no ignore file                                                                                                                                                |
| Secret leaks                   | the CI secret scan (Gitleaks)                                               | no findings, no allow-list added to pass                                                                                                                                   |
| GitHub Actions lint            | `actionlint`                                                                | clean                                                                                                                                                                      |
| JavaScript format, lint, types | `bun run format:check`, `bun run lint`, `bun run typecheck`                 | clean                                                                                                                                                                      |
| Dependency scan                | `bin/bundler-audit check --update`                                          | no known vulnerable gem (update instead of ignoring; GitHub also reports Dependabot alerts on the default branch)                                                          |
| Production asset build         | `bunx vite build --mode production` and its runtime assertion               | succeeds                                                                                                                                                                   |

Tests and coverage (Rails tests, Vitest coverage threshold) are separate acceptance items; they are
not relaxed either.

Reason (owner): consistent data, models and code are one of the purposes of splitting the single
repository; each repository now owns less and must keep it fully clean.

## Notes

- Observed 2026-11-12: the `database_consistency` gem is installed and has no configuration in all
  four Cosmos repositories; each repository has a `.rubocop_todo.yml`.
- Fix rules: NOT NULL columns and explicit states instead of NULL-as-state; foreign keys and unique
  indexes that match validations and associations; no compatibility layers; migrations per
  `generic/migrations.mdc`; destroying development data needs owner approval at execution time.
- Remove what the repository no longer owns (split stage 2) before fixing it.
- Some checks fail today for environment reasons (host without the bundle; `ci.yml` read-only inside
  the container; `openapi:verify` on uncommitted bundles); fix those causes too.
- ERB linting: evaluate moving from ERB Lint to Herb (`herb` gem: HTML-aware ERB parser with a
  linter and formatter) as part of this work (owner, 2026-11-12). Compare rule coverage, Rails 8.2
  support, CI speed and editor integration; record the decision as an ADR. If Herb replaces ERB
  Lint, replace the CI step and remove `.erb_lint.yml` in the same change (no parallel period), and
  the zero-problem condition applies to Herb instead.
- Record the all-clean run in `evidence/` (full `git rev-parse HEAD`).
- Access history: `docs/backlog/2026-10-26-database-consistency-findings.md`.
