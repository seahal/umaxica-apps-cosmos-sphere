Task (umaxica-apps-cosmos-sphere): repair the test baseline, then cleanup round 2. Destructive
removal is approved; no compatibility layer; no commit. Never print secrets or environment values.

## Sphere's surfaces (the only correct list; read this first)

OWN, keep:

- core: app, org, net, dev (`www-jp.umaxica.*`; development `core.*.localhost`)
- warp: app, org (`warp-jp.umaxica.*`); no com
- palm: app (`palm-jp.umaxica.app`)
- operator tools: mission, flipper, blazer, pghero, coverband, swagger
- unknown-host 404 fallback

Foreign: auth, visa (Access); base, tech (Governance); edit, docs, news, help, info (Press); guid,
performance, and every `.com` surface. Sphere is a relying party; it never runs sign-in, social
sign-in or OpenID Provider code.

The 2026-11-11 recovery (evidence/2026-11-11-sphere-surface-recovery-V2K8.md) is the starting point.
Do not re-add anything it removed, and do not remove anything it restored for core, warp or palm.

## Do not touch

config/credentials/_.yml.enc (never edit, never add entries; if a test needs a missing value, report
it instead), .devcontainer/\*\*, .env_ values, docs/backlog/** (except closing entries named below),
plans/**, evidence/** (except your new record), adr/**, migrations. Do not drop tables or databases.
Do not change the OIDC client registrations or the Access/Base host readers the recovery kept on
purpose.

## Part A: repair the test baseline (first)

After the recovery: 8,188 tests, 53 failures, 3,851 errors. The dominant error happens while loading
fixtures: `ActiveRecord::InvalidForeignKey` for `op_org_grants` referencing a missing
`operator_device_sessions` row.

1. Classify the errors by cause with counts (fixtures of removed or foreign models, fixture load
   order, missing constants of removed code, missing translations).
2. Fix the causes in tests and fixtures: remove fixtures and tests that exist only for removed or
   foreign surfaces and models, and repair references in the rest. Never weaken a database
   constraint, disable foreign-key checks, skip tests or add placeholder tests to get green.
3. Re-run bin/rails test and record the new baseline with identifiers; report what remains red and
   why.

## Part B: cleanup round 2

1. Primary-only reads, per docs/backlog/2026-11-11-no-automatic-replica-reads.md (Governance and
   Access carry the same decision): remove `database_selector`, `database_resolver` and
   `database_resolver_context` from config/initializers/multi_db.rb; list every remaining
   `connected_to(role: :reading)`.
2. Social sign-in leftovers: remove Google and Apple entries from
   `app/values/external_authentication/provider_registry.rb`, the Apple client secret provider
   (`app/adapters/external_authentication/apple_client_secret_provider.rb`) and every social sign-in
   code path, test and gem that remains only for them (their credential entries were removed on
   2026-11-11).
3. Valkey auth state: delete `app/services/valkey/auth_state/*` stores and the OTP verification
   failure budgets if no Sphere flow uses them (Sphere issues no authorization codes and runs no OTP
   ceremony); otherwise report the callers.

## Checks

bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle exec erb_lint --lint-all, bun run
check, bin/rails test. Report test results against the Part A baseline, new failures separately.
Before finishing confirm: `config/routes/` contains core.rb, warp.rb, palm.rb and the operator-tool
files only; `bin/rails routes` lists no foreign or `.com` host; config/credentials files are
byte-for-byte unchanged by this task.

## Report

Record in evidence/YYYY-MM-DD-sphere-round2-XXXX.md (full `git rev-parse HEAD`; note that
uncommitted changes affected results): error classification and fixes, new test baseline, removed
paths summary, remaining reading-role uses, check results. No commit.
