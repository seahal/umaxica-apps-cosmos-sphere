# Sphere database consistency zero

## Closure under the owner's revised scope

The owner explicitly removed CI work from this task's completion conditions after the read-only
workflow mount was confirmed. CI configuration and CI execution are deferred; they are not claimed
as completed. The available local implementation and verification are complete. Actual
Docker-container execution remains unverified because no container runtime is available; local Rails
boot and direct checker execution were verified as described below.

The final direct test checker rerun exited 0 and emitted only `No configuration files were provided`
(zero findings). Existing full-suite results remain 1,843 runs, 12,779 assertions, zero
failures/errors/skips. No implementation changed after that suite. The user's destructive database
reset was not executed against the remote development database. No commit or push was made.

## Scope and working tree

- Repository: `umaxica-apps-cosmos-sphere`.
- HEAD: `f65f1f29bcab40b8f9f921678ccffd034e21d355` (`feature`).
- The working tree already contained extensive uncommitted work; 319 paths were dirty when this
  record was prepared. Those changes were preserved. Results apply to that working tree.
- No commit or push was made. No database was dropped or recreated. No schema or migration changed.
- `config/credentials/` and `.github/` are unchanged. `.env.container.devcontainer` was already
  modified and was read only. On follow-up, the missing issuer key was copied into the ignored local
  `.env` from that development file without printing its value.

## Issuer investigation

- `git log -1 -- config/initializers/jwt.rb` and `git blame -L 10,10 config/initializers/jwt.rb`
  identify HEAD `f65f1f29bcab40b8f9f921678ccffd034e21d355` as the commit that made the one-argument
  `ENV.fetch("AUTH_JWT_ISSUER")` unconditional. The one-argument fetch remains unchanged.
- `AUTH_JWT_ISSUER` is present in the current `.env.container.devcontainer` worktree file; it is
  absent from the local `.env` file and from tracked environment templates. The CI `test-rails` and
  `coverage` jobs contain sibling `AUTH_JWT_*` settings but no `AUTH_JWT_ISSUER` reference.
- The registry eagerly builds an `auth` issuer record at boot. Production callers in `app/` and
  `lib/` use explicit surface or OIDC-client issuer IDs; none calls the `auth` registry record or
  `JwtConfig`. Access owns the OP issuer under the accepted Sphere/Access ownership decisions. The
  remaining Sphere dependency is boot-time construction, not a used RP feature.
- The issuer is consumed during registry construction, so the running code still needs it to boot
  despite the absence of an RP feature caller. Access ownership is settled in accepted ADRs, so no
  owner decision blocks configuration. Removing the unused `auth` registry entry and its initializer
  fetch is a follow-up option. The current development-container file supplies the setting, but this
  environment has no Docker CLI to inspect or restart the actual container. CI's missing setting
  could not be added: `.github` is mounted read-only (`EROFS`). CI was not run, and CI boot remains
  unverified if the legacy registry entry is retained.

## Finding and fix

Before the fix, `database_consistency` 3.1.2 reported one `UniqueIndexChecker` finding for
`OperatorChronicle` index `uniq_operator_chronicles_sign_flow_halted`. The model already had
`JsonbKeysUniquenessValidator` for the JSONB key tuple and partial predicate. The published checker
only matched ordinary column-based uniqueness and could not compare this expression index to its
validator.

The dependency now resolves to the repository's editable `database_consistency` fork (3.0.16),
selected in `Gemfile`. The existing tracked
`patches/database-consistency-jsonb-keys-uniqueness.patch` was applied to the local fork's
`unique_index_checker.rb`, `missing_unique_index_checker.rb`, and `helper.rb`. It compares JSONB
text-key expressions, tuple members, uniqueness, and the partial predicate in both checker
directions. Unsupported expressions, wrong keys or predicates, a non-unique index, and a missing
validator continue to fail. No checker configuration, exclusion, suppression, or database constraint
was added or weakened. `Gemfile.lock` has no diff and `bundle check` succeeds.

The checker printed `No configuration files were provided`; inspection of the fork's configuration
confirms that absent settings default all checkers and databases to enabled. The message is
informational and did not skip the scan.

The regression test was Red against the unpatched/published checker: 10 runs, 21 assertions, 4
failures, 2 errors. It is Green against the patched fork: 10 runs, 31 assertions, 0 failures, 0
errors, 0 skips. The existing PostgreSQL-backed checker and Chronicle expression/lifecycle tests
passed together: 26 runs, 87 assertions, 0 failures, 0 errors, 0 skips.

## Verification

The execution wrapper loaded development-container settings by calling `LocalEnvironment.parse`
without printing values, removed the stale `POSTGRESQL_TEST_PREPARE_DATABASES` variable in the child
process only, then ran the requested Rails command. No database preparation or destructive database
task was run.

| Check                                                                        | Result                                                                                                       |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency`        | 0 findings; exit 0.                                                                                          |
| `RAILS_ENV=development RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` | 0 findings; exit 0.                                                                                          |
| Checker JSONB regression and Chronicle expression/sign-flow tests            | 26 runs, 87 assertions, 0 failures/errors/skips.                                                             |
| `bin/rails zeitwerk:check`                                                   | Passed (`All is good!`).                                                                                     |
| `bin/rubocop`                                                                | Passed; 815 files inspected, no offenses.                                                                    |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`             | Passed; exit 0.                                                                                              |
| `bin/rails test`                                                             | Exit 0; 1,843 runs, 12,779 assertions, 0 failures, 0 errors, 0 skips (exit status recaptured on 2026-11-14). |
| `bundle check`                                                               | Passed; dependencies satisfied.                                                                              |
| `git diff --check` and local fork `git diff --check`                         | Passed.                                                                                                      |

The checker printed only `No configuration files were provided` on the successful test run; no
findings were suppressed. Initially, the shell command failed because `AUTH_JWT_ISSUER` was absent
from local `.env`; the follow-up below resolves that local boot failure. An actual container
invocation was unavailable because Docker is not installed. An attempted CI workflow update failed
with `EROFS`; `.github` is mounted read-only and remains unchanged. The CI setting is outstanding.
No result is claimed for CI or production.

## Follow-up after the user's reset attempt

- The reported `bin/rails db:migrate:reset` failure occurred in `config/initializers/jwt.rb` during
  environment boot, before the Rake reset task or any database action.
- The local `.env` did not contain `AUTH_JWT_ISSUER`, while the development-container file did.
  After adding the key to the local ignored `.env`, `bin/rails runner 'puts "rails_boot_ok"'` exited
  0, and `bin/rails db:version` exited 0.
- Direct test and development checker runs using the local `.env` both exited 0 with no finding
  output. `POSTGRESQL_TEST_PREPARE_DATABASES` was unset only for those checker child processes
  because its local list is stale.
- A direct full test run using the local `.env` (without development-container environment
  injection) exited 0: 1,843 runs, 12,779 assertions, 0 failures, 0 errors, 0 skips.
- Read-only `bin/rails db:migrate:status` exited 0 and reported 91 applied migrations, 0 pending. A
  Rake dry run confirmed `db:migrate:reset` includes `db:drop`, `db:create`, and `db:migrate`,
  without `db:drop:all` or a queue task.
- The development primary database config uses a non-local host. The destructive reset was not
  re-run because this environment cannot verify that the remote development database is isolated
  rather than shared. The user's earlier attempt stopped before it could drop anything.
- CI remains unverified: `.github` is a read-only ZFS mount (`EROFS`), and Docker, Podman,
  `nerdctl`, and `devcontainer` executables are unavailable here.
