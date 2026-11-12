# Herb Migration (2026-11-10)

Owner: each Cosmos repository; same work in all four. Status: decided, queued until the split
cleanup in all four repositories is finished. Basis: an owner-supplied work order drafted with
ChatGPT, checked against the repositories on 2026-11-10 and corrected below. Herb adoption is
decided; it is not to be re-evaluated.

## Goal

Move HTML+ERB from Erubi and erb_lint to Herb in all four repositories (Access, Governance, Press,
Sphere), keeping `.html.erb` extensions:

1. Render HTML+ERB with Herb (`config.action_view.erb_implementation = :herb`, or whatever the
   pinned Rails defines). Non-HTML ERB stays on Erubi as Rails intends.
2. Replace erb_lint with the Herb Linter (`@herb-tools/linter`, run with Bun:
   `bunx --bun herb-lint`; no npm or npx requirement). The Herb formatter is out of scope.
3. Fix every template Herb rejects, in the application and in gems.

ReActionView and reactive features are out of scope.

## Facts checked on 2026-11-10

- The pinned Rails (`9ba8b1e`, 8.2.0.alpha) has an `erb_implementation` attribute (default Erubi), a
  Herb handler and `actionview/lib/action_view/tasks/herb.rake` (`bin/rails herb:check`).
- `herb 0.11.1`, `erb_lint 0.9.0`, and `rails_performance 1.6.0` are locked; `rails_db 2.5.0` was
  locked before its removal in Sphere (see the evidence linked below). `.herb.yml` (template, mostly
  comments) and `@herb-tools/linter ^0.11.1` in `package.json` already exist; `erb_implementation`
  is not set.
- `app/views/shared/ui/_button.html.erb` exists in all four repositories.

## Corrections to the original work order (owner, 2026-11-10)

1. **Move the `herb` gem to the default group.** It is in the development/test group today. A
   rendering engine is needed in production; leaving it there would break every page in production.
2. **Test acceptance is "no new failures against the recorded baseline",** not "the whole suite
   passes": every repository still carries pre-split failures. Making the whole suite green is later
   work.
3. **All four repositories.** Do one repository first, then apply the same changes to the others.
4. **Timing:** after the split cleanup ends in all four repositories, so templates and Gemfiles are
   not edited concurrently.

## Known compile failures (earlier check)

- Application: `_button.html.erb` builds attribute names with ERB output (`class=...`, `disabled`,
  `data-<key>=...`), which Herb refuses for security. Rebuild it with Rails tag helpers, keeping the
  `link_to` branch, `type`, `class`, `disabled`, `data-*`, label and block rendering, with escaping
  left to Rails. Compare HTML output before and after, check every caller and Stimulus/Turbo
  behavior, and test escaping (no XSS regression).
- Gems: `rails_performance` has 8 templates with omitted end tags, elements spanning ERB control
  flow, and unmatched tags. `rails_db` had 5 such templates, which are no longer installed in Sphere
  after its removal documented below. For remaining gem issues, resolve in this order: newer
  release, upstream issue or PR, upgrade, minimal upstream patch, fork pinned by commit SHA. Never
  edit `vendor/bundle`. Never report success while these remain.
- Also check how Herb treats Access's `app/views/visa/shared/authorization_continuation.html.erb`
  (`javascript_tag do`, flagged by erb_lint; CSP nonce handling must not change).

## Decided: remove `rails_db` (owner, 2026-11-10)

`rails_db` is removed from Sphere by `docs/backlog/2026-11-10-remove-rails-db.md`; see
`evidence/2026-11-09-sphere-route-separation-followup-M8K2.md`. Its five Herb failures therefore no
longer apply here. Removal in the other repositories remains separate. `rails_performance` is
removed too (`docs/backlog/2026-11-10-remove-rails-performance.md`), so no gem template remains to
fix.

## Not allowed

Deleting tests, excluding problem files wholesale, disabling linter rules in bulk, editing
`vendor/bundle`, silent fallback to Erubi, relaxing security checks, broad unrelated view rewrites,
and reporting success with known problems. No changes to routing, authentication, authorization or
database structure as part of this work.

## Phases

1. Inventory: Rails, Herb, erb_lint configuration and custom rules, Bun, CI, templates, engine
   views; re-run the Herb compile check for current counts.
2. Fix application templates, with tests per change.
3. No gem templates to fix: `rails_db` and `rails_performance` are removed.
4. Switch rendering to Herb; `bin/rails herb:check` passes.
5. Configure `.herb.yml` (`framework: actionview`), compare erb_lint's checks with Herb's, record
   any lost check and how it is covered, then remove erb_lint, its configuration and its CI step.
6. CI and documentation (AGENTS.md verification commands, development docs).
7. Final verification and a report: changed files, versions, linter migration result, gem fixes,
   tests run and results against the baseline, CI changes, open issues and risks.
