Task (umaxica-apps-cosmos-sphere only): make `database_consistency` runnable again in the
development container, then bring it to zero findings.

## Observed on 2026-11-14

`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` (and the development run)
fails while booting: `config/initializers/jwt.rb:10` calls `ENV.fetch("AUTH_JWT_ISSUER")` and the
container environment does not define it. The last result,
`evidence/2026-11-12-sphere-database-consistency-Q8M4.md`, predates commit `f65f1f29b` ("Complete
Sphere ownership split and database hardening"), which last changed that initializer. The variable
is read in `config/initializers/jwt.rb` and `lib/jit_security_jwt_registry.rb`.

## Work

1. Find which commit made the variable required and where its value should come from (devcontainer
   compose, `.env` example, CI workflow). Report names only. Keep one-argument `ENV.fetch`; never
   add a code default (`adr/env-fetch-without-default.md`). If the value is the issuer of another
   application, state which and stop for the owner if it is not already decided in this repository;
   otherwise add it to the development and CI configuration where its siblings live.
2. Check whether Sphere still needs this issuer at all after the split; if nothing uses it, report
   removal as an option instead of configuring it.
3. Once the application boots, run the checker and fix every finding under the rules below.

No commit. Never print secrets, key material or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside this
repository. Do not disable a checker, add an exclusion or a todo file, or weaken a database
constraint to make the report pass; fix the model or the schema so both sides state the same
contract. Every schema change is a reversible migration. Tests Red first; no mocked behaviour under
test.

## Checks and report

`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` must exit 0 (record the
command and the finding count before and after). Then bin/rails zeitwerk:check, bin/rubocop,
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, the changed and related tests,
bin/rails test (separate pre-existing failures; unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its
stale list blocks boot and report it). Update docs/mermaid inventories and checklists if a lifecycle
or deletion rule changes.

Evidence: `evidence/YYYY-MM-DD-database-consistency-zero-XXXX.md` (full `git rev-parse HEAD`;
uncommitted changes affected results): each finding, its cause, the fix and its test, migrations,
results, owner items, and confirmation that config/credentials files are unchanged.
