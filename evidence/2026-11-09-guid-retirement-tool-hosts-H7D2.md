# Sphere GUID retirement and operator host changes

Date: 2026-11-09. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. Checks used the uncommitted
change and the existing dirty worktree. Pre-existing Compose, ADR, documentation, tooling-test, plan
and spec changes were preserved. No commit or external service configuration change was performed.

## Authorized scope and implementation

Source: [Cosmos Press route ownership](../specs/cosmos-press-route-ownership/spec.md) and the user's
explicit GUID/tool instructions. Access checkout comparison was waived by the user when its location
was unavailable. The separate content-surface removal remains deferred; this is not completion of
the full spec.

- Removed `draw :guid`, its route file, eleven dedicated controllers, view, stylesheet and feature
  tests. Retained Edit no-store tests in their own file.
- Removed the dead GUID health profile, availability slot, runtime role family, boot-host member and
  its private helper, host allowlist entries and tracked env inputs. Updated affected route/security
  inventories without widening protection.
- Kept shared identifier generation, resource/protocol identifiers, issued values, database schemas,
  existing records and connection targets unchanged.
- Changed seven tracked public tool values to `<tool>-sphere-jp.umaxica.dev` and updated current
  route comments/documentation. Private localhost aliases, exact host constraints, engine loading
  guards and origin authentication are retained.
- Kept Gemfile/Gemfile.lock differences limited to the Rails pin. An old Swagger host example in a
  Gemfile comment was left alone to preserve that explicit scope.

## Read-only configuration blocker

`.github/` and `.devcontainer/` are read-only mounts; direct writes failed with
`OSError: [Errno 30] Read-only file system`. No remount or permission bypass was attempted. The
unapplied changes are saved outside the repository:

`/tmp/sphere-guid-tool-hosts-H7D2/readonly-config.patch`

The patch replaces seven public aliases and removes the two GUID aliases in
`.devcontainer/compose.yaml`, preserving the user's existing edits. It updates both CI environment
blocks to the seven new public host values and removes the unused GUID value. `git apply --check`
passes. Both proposed YAML documents parse, and a parsed comparison confirms unchanged port
publications. Compose is not installed in this executor, so rendered Compose validation was not
performed.

These edits remain unapplied. In particular, CI still exports the old public Flipper host and will
disagree with the updated mount invariant until the patch is applied. Container alias
activation/recreation and Cloudflare changes were not performed. A new env file does not replace
already exported container values; runtime checks explicitly supplied the seven updated public host
values.

## Verification

- `RAILS_ENV=test bin/rails runner 'puts Rails.version'`: exit 0, `8.2.0.alpha`.
- RuboCop over Gemfile and all 30 surviving changed/new Ruby files: exit 0, 31 files inspected, no
  offenses. `git diff --check`: exit 0.
- `bun run check` initially could not find `oxfmt`. `bun install --frozen-lockfile` installed
  dependencies without changing package.json or bun.lock. The repeated complete check passed,
  including formatting, lint, type checks, knip and OpenAPI bundle freshness; OpenAPI lint emitted
  one existing unused-component warning.
- Targeted Rails run over 15 files, with `PARALLEL_WORKERS=1` and the new public tool hosts: **81
  runs, 1121 assertions, 3 failures, 0 errors, 0 skips**. All three failures match the full-suite
  baseline captured before this change:
  `XperRetiredHostsTest#test_a_retained_Base_host_still_owns_the_same_endpoint_paths`,
  `LayoutTitleContractTest#test_no_layout_or_view_builds_a_title_outside_meta-tags_except_the_standalone_documents`,
  `OpenapiRouteCoverageTest#test_no_route_the_router_serves_is_missing_from_its_surface_description`.
  They were not repaired. Exact types/locations and output are saved externally.
- The new retired-host tests and RI classification also passed independently: 6 runs, 47 assertions,
  no failures/errors/skips. Initial classification failure from an empty removed controller
  directory was corrected by removing that empty directory; it is absent from the final targeted
  run.
- Targeted scope: controller inheritance, default no-store policy, FQDN registry, mounted-engine
  invariants, RI routing, public entrypoint inventory, host-family values, OmniAuth host matrix,
  retained Edit no-store, title contract, retired hosts, OpenAPI route coverage, PublicId generation
  and identifier AST invariant.
- A development Puma server booted with the new public host values. A full HTTP request to the
  Mission host returned **500** before tool authentication because `development_publishing_db` does
  not exist (`ActiveRecord::NoDatabaseError`; first repository frame
  `config/initializers/schema_migration_if_not_exists.rb:10`). No development database was created.
  The temporary server was stopped.
- Separately, an external Puma-booted component probe exercised the real route set plus Host
  Authorization, without the outer application middleware requiring the missing development DB. **32
  checks passed**: all seven public hosts reject absent and invalid Basic credentials with 401;
  their seven private aliases also return 401; the seven old public hosts and two GUID hosts return
  403; Swagger's document endpoint rejects both absent and invalid credentials with 401. This
  verifies those components, not the blocked end-to-end HTTP path. The first probe omitted
  `HTTP_HOST`; it was corrected before the successful final probe.

The complete Rails run is the pre-retirement baseline recorded in
[Rails pin R9P2](2026-11-09-rails-revision-pin-R9P2.md): 17164 runs, 302 failures, 67 errors. It was
not repeated after this slice; affected boundaries were checked with the targeted run. Full-spec
acceptance remains open.

## External artifacts

Directory: `/tmp/sphere-guid-tool-hosts-H7D2/` (temporary, local artifacts).

- `targeted-failures.md`: all three final failures, exception types and locations.
- `targeted-tests-final.log`, `retirement-tests.log`: test outputs.
- `route-layer-probes.json`, `route-layer-probes-final.log`: all 32 component checks.
- `server.log`, `host-probes.log`: blocked full HTTP observation.
- `rubocop-final.log`, `bun-check-installed.log`: final successful static checks.
- `readonly-config.patch`: remaining configuration changes.
- `ci.proposed.yml`, `devcontainer-compose.proposed.yaml`: reviewable proposed YAML.
- `devcontainer-compose.before.yaml`, `worktree.before.diff`: pre-edit snapshots.

The full baseline failure/error list remains at
`/tmp/sphere-rails-revision-pin-R9P1/failures-and-errors.md`.
