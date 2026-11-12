Task (umaxica-apps-cosmos-sphere): finish the test baseline left open by
evidence/2026-11-11-sphere-round2-R2B7.md. No commit. Never print secrets or environment values.
Never edit config/credentials/*.yml.enc.

Sphere's surfaces stay as in plans/2026-11-12-sphere-test-baseline-and-round2-work-order.md (core,
warp without com, palm, operator tools). Do not re-add foreign surfaces.

## 1. Restore deleted initializers that Sphere still needs (likely root cause of JWT errors)

The worktree deletes these files that exist in HEAD:

    config/initializers/cors.rb
    config/initializers/development_routing_authority_diagnostics.rb
    config/initializers/event_subscribers.rb
    config/initializers/jwt.rb
    config/initializers/login_cooldown.rb
    config/initializers/meta_tags.rb
    config/initializers/multi_db.rb            (keep deleted: primary-only reads, decided)
    config/initializers/omniauth.rb            (keep deleted: social sign-in removed, decided)
    config/initializers/outbound_email.rb
    config/initializers/rails_performance.rb   (keep deleted: rails_performance removed)
    config/initializers/turnstile.rb

`config/initializers/jwt.rb` installs the local JWT keyset (`JitSecurityJwtLocalKeysetInstaller`)
and calls `JitSecurityJwtRegistry.configure!`; Access still has it. Its absence explains the
`JitSecurityJwtRegistry::ConfigurationError` errors (66) without any credential change: do not
create temporary keysets to work around it. For each file not marked "keep deleted", decide from
Sphere's remaining callers whether Sphere needs it; restore the needed ones with
`git restore --source=HEAD -- <path>` (explicit paths only) and adapt them to Sphere's surfaces;
report each decision.

## 2. Test database pollution (authorized cleanup)

Fixture setup and cleanup in isolated, disposable test data are authorized verification (AGENTS.md);
the test database is disposable. You do not need owner approval to remove rows that tests left
behind.

- Root cause to fix: a test that runs without transactional fixtures (first seen in
  `OpAuthorityStopConcurrencyTest`) persists an `OpOrgGrant` row and leaves it; the next fixture
  load fails with `fk_op_org_grants_on_device_session_id` for thousands of tests. Make every
  non-transactional test remove the rows it creates (teardown or `ensure`), or remove the test if it
  exercises only behavior Sphere no longer owns (OP authority belongs to Access).
- Before each full run, reset the test database (`bin/rails db:test:prepare` or the repository's
  documented equivalent) so leftovers from earlier runs cannot mask the result.

## 3. Remaining error classes

After 1 and 2, re-run and classify what remains (`KeyError`, `OidcClientRegistry::ClientNotFound`,
`ArgumentError`, `JumpRtConfigurationError`, `NameError`, `DeleteRestrictionError`). Fix causes in
code, tests and fixtures; delete tests that exist only for removed or foreign behavior. If a fix
would need a credential value, stop and report the missing name only.

Never weaken a constraint, disable foreign-key checks, skip tests or add placeholder tests.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle exec erb_lint --lint-all, bun run
check, bin/rails test (after a test database reset). Record in
evidence/YYYY-MM-DD-sphere-test-baseline-followup-XXXX.md (full `git rev-parse HEAD`; uncommitted
changes affected results): restored initializers and decisions, polluting tests fixed or removed,
error classification before and after, the new baseline with identifiers, and confirmation that
config/credentials files are unchanged.
