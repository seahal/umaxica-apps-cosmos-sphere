# bin/setup Builds the Development Environment for Anyone (2026-11-10)

Owner: this repository (same goal in all four Cosmos repositories). Status: goal recorded; not
started. `bin/setup` may be rewritten freely for this.

## Goal

A person with a fresh checkout and only the documented prerequisites runs `bin/setup` once and ends
with a working development environment: dependencies installed, databases and reference data ready,
the application booting, and a clear report of anything that needs a human (secrets, external
accounts). Today `bin/setup` is the Rails default (bundle, bun, `db:prepare`, `log:clear`,
`bin/dev`) and misses steps found during the Cosmos split.

## Requirements

- **Idempotent and safe:** re-running changes nothing that is already correct; never deletes or
  resets data unless explicitly asked (`--reset` keeps its meaning and asks for confirmation).
- **Fail fast and explain:** check prerequisites first (Ruby, Bundler, Bun, the container runtime or
  services, database reachability) and stop with a specific message naming what is missing.
- **Reference data:** load every required reference row (status, state, kind tables) through the
  repository's established mechanism, and verify none is missing, for development and test. The
  2026-11-09 audits found empty reference tables and absent schemas after the split.
- **Secrets are never generated silently or printed:** detect missing `config/credentials/*.key`,
  `.env` entries (for example `CLOUDFLARED_TOKEN`) and other secrets, and print what to obtain and
  from whom (`docs/operations/development-credential-provisioning.md`), without showing values. Keys
  are not generated at boot (`adr/cosmos-development-on-vms-with-local-tls.md`).
- **Environment pitfalls:** warn when a shell-exported variable (such as `CLOUDFLARED_TOKEN`) would
  override this repository's `.env`; that silently joined three repositories to the wrong Cloudflare
  tunnel on 2026-11-10.
- **No external writes:** `bin/setup` does not change Cloudflare, AWS or any provider.
- **Report:** end with a summary of what was done and what still needs a person.
- Works in the current Dev Containers and, later, on the planned VMs
  (`adr/cosmos-development-on-vms-with-local-tls.md`); environment-specific steps are explicit.

## Verification

Run on a clean checkout (or a scratch clone) in the Dev Container: first run succeeds, second run is
a no-op, a deliberately missing prerequisite produces the documented message. Record in evidence/.
Environment construction is not tested with Minitest
(`adr/no-test-suite-for-environment-construction.md`).
