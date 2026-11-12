# Rails revision pin and GUID retirement verification

Date: 2026-11-09. Sphere HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. The worktree is
uncommitted; these results include the Rails pin, GUID retirement, operator host updates,
architecture baseline refresh, and the Neon configuration removal recorded separately in
[`2026-11-09-neon-production-db-retirement-F3N0.md`](2026-11-09-neon-production-db-retirement-F3N0.md).

## Rails pin

`Gemfile` pins Rails to `9ba8b1edeeacccb1ff5d2497432242eeddf48aed`. The `Gemfile.lock` diff changes
only `branch: main` to the same `ref`; Rails was already resolved to that revision and no gem
version changed.

`RAILS_ENV=test bin/rails runner 'puts Rails.version'` completed with `8.2.0.alpha`.
`bin/rubocop Gemfile` and `git diff --check` passed.

## GUID and retained operator hosts

GUID routes, controllers, view, stylesheet, tests, and host-family references were removed. Shared
identifier processing used by remaining code was retained. The seven operator hosts use the
requested Sphere names. Route and HostAuthorization component probes passed for the new public hosts
and private aliases; retired hosts were rejected. The targeted mounted-engine invariant also passed
with `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev`, matching the new host. The generated
architecture baseline was refreshed with `bin/rails architecture:baseline`; its invariant test
passed.

The full Dev Container/CI alias update could not be applied: `.devcontainer/` and `.github/` are
read-only mounts. The prepared patch is at `/tmp/sphere-guid-tool-hosts-H7D2/readonly-config.patch`
and `git apply --check` passed. Full development HTTP verification remains blocked: after the two
explicitly approved development database creations, 24 configured writer databases were still
absent. The later Neon request prohibits further database creation, and none was attempted. See
[`2026-11-09-guid-retirement-tool-hosts-H7D3.md`](2026-11-09-guid-retirement-tool-hosts-H7D3.md).

## Full test run

Command: `PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev bin/rails test` (exit 1; the inherited
process environment still provided the retired Flipper hostname unless overridden).

```text
17150 runs, 149391 assertions, 304 failures, 66 errors, 0 skips
```

The complete failure/error inventory contains each test name, exception kind, and first repository
path and line. It is stored outside the repository at
`/tmp/sphere-guid-tool-hosts-H7D2/failures-and-errors-final.md`.

Compared by test name with the earlier full-suite record in R9P1, three additional
`ActorSupportLifecycleTest` cases returned HTTP 503 in this run. The effective development and test
database configurations are unchanged, and these failures are outside the Rails pin/GUID changes;
they were not modified. The targeted ActorSupport run also returned HTTP 503 for four cases. Other
existing failures remain in the external inventory as the next-work baseline.

The full suite completed after GUID retirement and the Neon change. The `DatabasePasswordConfigTest`
targeted run passed: 2 runs, 17 assertions. The related mounted-engine, architecture-baseline, and
DBSC tests passed in their targeted run; the unrelated existing Org root-login test failed with
HTTP 401. `bin/rubocop config test` inspected 2,508 files with no offenses. `bun run check` passed
earlier after the GUID changes.

No commit or write to another repository was made. Development database connections were not
changed.
