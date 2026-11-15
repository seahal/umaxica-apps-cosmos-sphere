Task (this repository only): make every CI static check report zero problems without suppression, as
defined in `docs/backlog/2026-11-12-ci-static-checks-acceptance.md` (acceptance condition of the
Cosmos split). Unattended run: do not ask questions; when an item needs an owner decision, record it
and continue with the next item. Never print secrets or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no change outside this repository.

## Order of work (one check at a time; record before/after counts for each)

1. Baseline: run every static step of `.github/workflows/ci.yml` (and `config/ci.rb`) and record the
   counts. Environment failures (missing tools, read-only files) are findings: fix the cause if it
   is inside this repository, otherwise record it.
2. Checker source first (owner, 2026-11-13). Today the Gemfile loads
   `gem "database_consistency", path: "vendor/fork/database_consistency"`
   (`# FIXME: use rubygem's code.`); `vendor/fork/` is git-ignored, so nothing in it reaches CI or
   another machine. The fork is v3.0.16 plus one compatibility commit
   (`permanent_connection_checkout` support). Local, uncommitted edits to the checker were made in
   earlier work (seen in Press:
   `lib/database_consistency/checkers/column_checkers/null_constraint_checker.rb`; Sphere's evidence
   mentions a checker patch too).
   - Record `git status` and `git diff --stat` of `vendor/fork/database_consistency`, then discard
     every local edit there. The checker is never changed to make a finding disappear.
   - Try the newest released gem from RubyGems (`gem "database_consistency", require: false`, no
     `path:`). If it runs against this application, use it and remove the FIXME.
   - If it fails only because of `permanent_connection_checkout`, use the owner's fork pinned to a
     commit (`github: "seahal/database_consistency", ref: "<sha>"`) that contains the compatibility
     commit and nothing else; record the failure output that justifies it. Never keep `path:`.
   - Findings that the discarded edits had hidden are fixed in models and schema like any other.
     Then run `bundle exec database_consistency` with no configuration file. Fix models and schema:
     NOT NULL and explicit states, foreign keys and unique indexes that match validations and
     associations. Remove models, tables and columns this repository no longer owns instead of
     fixing them (check `plans/2026-11-12-handoff.md` and the ownership ADRs first). Migrations
     follow `generic/migrations.mdc` and may run against the local development and test databases
     only. If existing development rows violate a new constraint, do not delete or rewrite them:
     record the table, the constraint and the row count, and move on.
3. RuboCop: `bundle exec rubocop --fail-level convention` with `.rubocop_todo.yml` emptied and then
   deleted (and its `inherit_from` line removed). Use safe autocorrect (`-a`) first; apply unsafe
   corrections (`-A`) only cop by cop with the affected tests run afterwards. Never add
   `rubocop:disable` comments or new `Exclude` entries to pass; never weaken `.rubocop.yml`.
4. Frozen string literal scripts, `bundle exec erb_lint --lint-all`, the i18n key check.
5. Brakeman (no ignore file), the secret scan if the tool is available (no allow-list),
   `actionlint`, `bin/bundler-audit check --update` (update the gem; never ignore an advisory).
6. `bun run format:check`, `bun run lint`, `bun run typecheck`, the production Vite build.
7. Herb evaluation (read-only): compare ERB Lint and Herb for this repository (rule coverage, Rails
   8.2 support, speed, editor support) and write the comparison in the evidence file. Do not switch
   tools; the owner decides.

## Rules

- Behaviour must not change. After each group of fixes run the affected tests; at the end run
  `bin/rails test` and separate pre-existing failures (latest evidence baseline) from new ones. Fix
  what you broke.
- No placeholder, skipped or weakened tests; no test-only code in production; no compatibility
  layers; NULL never encodes a state.
- Stop an item and record it (do not guess) when it needs: an ADR change, a cross-repository
  contract change, deleting development data, or a credential.

## Report

evidence/YYYY-MM-DD-ci-static-checks-zero-XXXX.md (full `git rev-parse HEAD`; uncommitted changes
affected results): per check before/after counts and the exact command, what remains and why,
migrations added, the Herb comparison, items waiting for the owner, test results, and confirmation
that config/credentials files are unchanged.
