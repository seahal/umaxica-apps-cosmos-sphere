# Unused PUBLIC_STATUS_URL cleanup

Date: 2026-11-10. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. Existing uncommitted worktree
changes were present and affected inspection. This task made no commit and did not open or change
credential payloads or keys. Environment values and secrets were not printed or recorded.

## Verification and disposition

Candidate: `PUBLIC_STATUS_URL`. No runtime reader or test assertion on this name was found. Searched
app/, lib/, config/ (excluding credentials), bin/, script/ when present, db/, src/, Rakefile,
Gemfile, package.json, vite.config._, Procfile_, Containerfile*, podman/ when present,
.devcontainer/, .github/, config/ci.rb, test/ and gait/; also searched env definitions, Compose,
README and docs including runbooks. Paths absent from this checkout have no files to inspect.

Reviewed dynamic ENV/combined-credentials reads and public-host builders, notably
`lib/config_values_host_family_values.rb:107` and its explicit family builders at lines 164–242;
none constructs a STATUS key. Generic local env loading copies configured entries but does not
establish a runtime consumer. `lib/jit_security_jwt_local_keyset_installer.rb:68` filters
private-key names, not this candidate. Host registries/redirect helpers select explicit service
names and do not select STATUS. No candidate was kept because of a reader. The user's protected-name
list was left unchanged.

Removed only four candidate lines, preserving all other bytes in each edited file:

- `.env`: one assignment.
- `.env.local`: one assignment (an additional local definition).
- `.env.container.devcontainer`: one assignment.
- `docs/reference/ui-view-inventory.md`: one listing row.

Unexpected/blocking: `.github/workflows/ci.yml` is read-only in this executor. Opening it for the
scoped edit failed with `OSError: [Errno 30] Read-only file system`; no CI content was changed. Two
unused assignments remain at lines **296** and **580**. These are definitions, not readers. Final
name-only rescan found only those two remaining references in the inspected scope. The request to
remove every definition is therefore **incomplete** until that file is writable.

## Checks

- Edited-file byte comparisons confirmed that only candidate lines were removed.
- `git diff --check -- .env.container.devcontainer docs/reference/ui-view-inventory.md`: exit 0.
- Attempted `docker compose -f .devcontainer/compose.yaml config -q`: blocked because the `docker`
  executable is unavailable. Compose parsing is **unverified**; no Compose file changed.
- RuboCop not run: no Ruby changed. Rails tests not run: no test files changed.
- No destructive commands, application startup, database operations, dependency installation or
  external writes were performed. No unrelated worktree changes were reverted.
