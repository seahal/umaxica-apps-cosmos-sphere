# CI Static Checks Zero — Final Continuation

Date: 2026-11-13. Work order: `plans/2026-11-13-ci-static-checks-zero-work-order.md`. Repository:
`umaxica-apps-cosmos-sphere`. HEAD: `f65f1f29bcab40b8f9f921678ccffd034e21d355`. Branch: `feature`.
The worktree was already broadly uncommitted before this continuation and had 315 status entries at
final verification, including this evidence record. Results describe that worktree, not a clean
checkout. No commit, push, reset, stash, production database operation, CI change, or DB schema
change was made. `config/credentials/*.yml.enc`, `.github/workflows/ci.yml`, `config/ci.rb`, and
`db/` have no changes from this continuation.

Work order 1 was completed first and recorded in
[`2026-11-13-ps256-follow-up-R7S2.md`](2026-11-13-ps256-follow-up-R7S2.md). Its focused and full
test results are recorded there.

## Environment and Test Verification

The development container configuration lacked the required `AUTH_JWT_ISSUER` entry. Added the
existing AUTH_APP issuer to `.env.container.devcontainer`; a Rails runner compared the loaded value
to `JitSecurityJwtRegistry::SURFACE_ISSUER_ORIGINS.fetch("AUTH_APP")` in memory and printed only
`canonical_issuer_match=true`. No issuer value is recorded here. This is a required public issuer
configuration value, not a new default or test-only branch.

An initial test attempt incorrectly selected `.env.container.devcontainer` as Rails' complete
`UMAXICA_ENV_FILE`; that Compose injection file does not contain all Rails host settings, so boot
failed before tests. A later focused retry also stopped before tests because the required issuer was
not in the process environment and the local `.env` prepare-list still named 17 retired databases.
Re-running with the normal local `.env` loader, the issuer supplied from the container
configuration, and test database preparation explicitly limited to the nine writer databases in
`config/ci.rb` reached PostgreSQL and passed. The preparation output listed only those nine
migration targets; no database was dropped.

| Command                                                                 | Result                                                                                                                                                                  |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rails test test/adapters/oidc_op_protocol_verifiers_test.rb`       | 18 runs, 174 assertions, 0 failures, 0 errors, 0 skips.                                                                                                                 |
| `COVERAGE=true bin/rails test`                                          | 1,833 runs, 12,748 assertions, 0 failures, 0 errors, 0 skips; SimpleCov exits 2 for the branch and method minima below.                                                 |
| `bin/rails test test/unit/jit/security/jwt/local_keyset_format_test.rb` | 1 run, 1 assertion, 0 failures, 0 errors, 0 skips. The test first failed when it expected OpenSSL's RSA display name; it now asserts the stable `RSA` format component. |
| `bin/rubocop --fail-level convention --format simple --no-color`        | 814 files, 0 offenses.                                                                                                                                                  |
| `bin/rails zeitwerk:check`                                              | Passed.                                                                                                                                                                 |
| `git diff --check`                                                      | Passed.                                                                                                                                                                 |

## Static Gate Results

The baseline and earlier before/after counts are retained in
[`2026-11-13-ci-static-checks-zero-C1Z0.md`](2026-11-13-ci-static-checks-zero-C1Z0.md). The table
below records the final checks re-run or verified for this continuation.

| Gate                             | Final command and result                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DatabaseConsistency              | `RAILS_ENV=test bundle exec database_consistency`, with the required issuer supplied by the process and no configuration file — exit 1, exactly one finding: the released checker does not recognize `OperatorChronicle`'s `JsonbKeysUniquenessValidator` for its valid partial JSONB expression unique index. No checker patch, configuration, exclusion, or schema distortion was added.                                                                      |
| RuboCop                          | `bin/rubocop --fail-level convention --format simple --no-color` — 814 files, 0 offenses.                                                                                                                                                                                                                                                                                                                                                                       |
| Frozen string literal            | `ruby scripts/check_frozen_string_literal_directives.rb` — 919 directives, 0 findings. The separate frozen-literal RuboCop gate previously passed on 922 files with 0 offenses.                                                                                                                                                                                                                                                                                 |
| ERB Lint                         | `bundle exec erb_lint --lint-all` — 19 application templates, 16 linters, 0 errors. `parser/current` still warns that its Ruby 3.3 grammar is running on Ruby 4.0.9.                                                                                                                                                                                                                                                                                            |
| i18n                             | `bundle exec i18n-tasks missing` — 0 missing translations.                                                                                                                                                                                                                                                                                                                                                                                                      |
| Brakeman                         | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — 127 controllers, 60 models, 19 templates, 0 errors or security warnings.                                                                                                                                                                                                                                                                                                                     |
| Gitleaks, HEAD commit            | `env -u RUBYOPT -u RUBY_DEBUG_OPEN gitleaks detect --no-banner --redact --log-opts=-1` — complete scan of 1 commit, 10 redacted detections. Earlier metadata grouped them as 5 detections in the encrypted development credentials file, 4 in the encrypted test credentials file, and 1 full commit hash in an evidence record. Credential paths are prohibited from editing, and the full hash is required by the evidence contract. No values were recorded. |
| Gitleaks, history                | The earlier full-history scan covered 3,223 commits and found 248 redacted detections, including historical private-key patterns that need owner assessment. No history rewrite or allow-list was made.                                                                                                                                                                                                                                                         |
| Gitleaks, changed worktree files | A redacted scan of a temporary snapshot containing all 315 changed paths (310 regular files) found 0 detections. `KEY_FORMAT` now derives the unchanged persisted marker (`PS256-RSA-3072-v1`) from the existing algorithm, key type and minimum-size constants rather than storing a scanner-triggering literal. The installer and its public constant have a focused test; no key material or stored-format value changed.                                    |
| Gitleaks, full worktree snapshot | The last completed tracked/non-ignored snapshot scan found 111 detections in 4,894 files. A later full snapshot attempt did not complete. This historical full-snapshot count is not the changed-files count above.                                                                                                                                                                                                                                             |
| actionlint                       | The system v1.7.7 binary reported four unsupported `ubuntu-slim` runner diagnostics. `/tmp/sphere-actionlint-1.7.9/actionlint` — v1.7.9, 0 diagnostics. No workflow was edited.                                                                                                                                                                                                                                                                                 |
| Bundler audit                    | `bin/bundler-audit check --update` — advisory database updated to 1,359 advisories, 0 vulnerable gems.                                                                                                                                                                                                                                                                                                                                                          |
| Bun audit                        | `bun audit` — the prior final run checked 370 packages and found 0 vulnerabilities.                                                                                                                                                                                                                                                                                                                                                                             |
| JavaScript checks                | `bun run check` — formatting (138 files), lint, typecheck, Knip, OpenAPI lint, and isolated bundle verification passed; all three generated OpenAPI bundles matched.                                                                                                                                                                                                                                                                                            |
| Repository knowledge             | `scripts/check-repository-knowledge` — 8 Skills/adapters, 70 documents, 0 unresolved links.                                                                                                                                                                                                                                                                                                                                                                     |
| Production Vite build            | `NODE_ENV=production VITE_RUBY_MODE=production bun x vite build --mode production` — 39 assets emitted in isolated output; no development JSX runtime code. The previous ignored build output was restored.                                                                                                                                                                                                                                                     |

Coverage was re-run during this continuation:

- `bun run test:coverage` — 34 files, 259 tests, 100% statements (355/355), branches (269/269),
  functions (110/110), and lines (352/352).
- A fresh default-parallel `COVERAGE=true bin/rails test`, after moving aside prior generated
  SimpleCov reports so their 3,600-second subprocess merge window could not contribute stale worker
  results, ran 1,833 tests with 12,748 assertions and no test failures, errors or skips. Line
  coverage was 99.04% (9,196/9,285), meeting the requested 99% Minitest line target. Branch coverage
  was 91.30% (1,312/1,437; configured minimum 93%); method coverage was 96.60% (1,423/1,473;
  configured minimum 97%). SimpleCov therefore exited 2. The Rails coverage job remains red despite
  the line target and test assertions passing.
- An earlier serial diagnostic reported 98.64% method coverage but had one test failure; because it
  ran before stale subprocess results were removed, its coverage measurement is not authoritative. A
  later `PARALLEL_WORKERS=1 bin/rails test` without coverage passed the then-current 1,832 tests and
  12,747 assertions. The clean default-parallel run above is the current full-suite measurement.

## Herb and ERB Lint Comparison

No linter or template engine switch was made. On the same 19 templates, the earlier three-run local
comparison measured ERB Lint at 0.673 seconds median and Herb Linter 0.11.2 at 0.485 seconds median;
this small startup-inclusive sample is not a general benchmark. ERB Lint ran the repository's 16
configured checks and had no template errors. Herb advertises 148 rules across HTML, accessibility,
safety, and Action View patterns, but flagged three dynamic attribute-name outputs in these
templates and emitted an Action View framework information message. Herb provides a language server;
ERB Lint is the existing CLI gate. Current Herb documentation describes Rails 8.2's default Action
View integration. Tool choice remains an owner decision.

Sources: [ERB Lint](https://github.com/Shopify/erb_lint),
[Herb rules](https://herb-tools.dev/linter/rules/),
[Herb Rails installation](https://herb-tools.dev/installation),
[Herb linter](https://herb-tools.dev/projects/linter), and
[Herb language tools](https://herb-tools.dev/language/).

## Remaining Findings and Disposition

- **DatabaseConsistency:** one checker finding remains. The partial expression index enforces the
  intended JSONB uniqueness contract and is covered by PostgreSQL tests. Adding an ordinary
  uniqueness validator, changing the index to a different persisted shape, or patching/excluding the
  checker would misrepresent the invariant or conflict with the previously accepted Chronicle schema
  boundary. A supported released-checker matcher or an owner-approved schema redesign is required
  before this result can be zero. A stored-generated-column alternative was considered: it would add
  physical columns and replace the expression index, while the current integrity contract explicitly
  retains that index and predicate. Its production data/lock impact is unverified, so no migration
  was authored without resolving that contract and proving a safe rollout.
- **Gitleaks:** the HEAD scan's encrypted credential-file detections cannot be fixed within this
  work order, and the evidence hash is an explicit false positive required by repository evidence
  rules. Historical private-key patterns require an owner to determine whether the keys were ever
  active and to arrange rotation if so. No credentials, history, or scanner allow-list were changed.
- **ERB parser warning:** lint passes, but the installed parser grammar does not yet match the Ruby
  4.0.9 runtime. No unsupported parser upgrade was applied.
- **Coverage:** the latest parallel Minitest run reaches 99.04% line coverage (9,196/9,285), meeting
  the separately requested 99% line target. SimpleCov still exits 2 because branch coverage is
  91.30% against its configured 93% minimum and method coverage is 96.60% against its configured 97%
  minimum. The added key-format test exercises a public constant contract; no private or protected
  production method is called directly. A focused public-policy coverage run and the verbose
  full-suite run both passed their tests; the focused report measured the default-deny policy
  methods, while the clean full parallel report still leaves methods below its configured minimum.
  No test setup, coverage threshold or CI configuration was changed to hide that difference.

## Final Result

Most static checks, full Minitest, JavaScript checks, and the production asset build pass. The
work-order target of zero findings is **not met**: DatabaseConsistency reports one checker mismatch,
and the complete HEAD Gitleaks scan reports 10 redacted detections. The changed-path worktree
snapshot is clean (315 paths, 310 regular files); the separate full tracked/non-ignored snapshot
still has only the earlier completed count of 111 detections in 4,894 files because its later rerun
did not complete. These results remain visible without suppression. No CI configuration, database
schema, credentials, commit, or push was changed.
