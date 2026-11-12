# Sphere Route Separation Implementation Notes

## Context

- Original decision: `adr/cosmos-sphere-surfaces-and-rp-independence.md`.
- Surface decomposition: `adr/cosmos-base-surface-decomposition.md`.
- Related route ownership: `specs/cosmos-press-route-ownership/spec.md`.
- Implementation date: 2026-11-09.

## Decisions Made During Implementation

- `config/routes.rb` draws Core, Warp, Palm, and the seven retained operator tools only. The
  unknown-host response remains the final route.
- Route-owned Rails controllers, views, concerns, helpers, and tests with no retained caller were
  removed. Route-contract tests now exercise the retained host set. Tests that only exercised Base
  Inertia groups, Auth ceremony/signup endpoints, or Visa OP logout endpoints were removed with
  those route owners.
- `BrowserRpAuthentication` and its legacy Access-database read path were left untouched. The
  Core/Warp/Palm RP local-cell migration remains a separate work unit. Retained RP sign-in, refresh,
  callback and sign-out code was not weakened or reordered.
- Avatar social pages were not moved. The unowned Rails endpoints and templates were removed; the
  frontend entrypoint and stylesheet sources were left in place for their separately scoped work.
- Jump issuer identifiers remain registered. The JWKS integration test still checks the configured
  identifiers and token issuance, while its HTTP publication assertions target only Core, Warp and
  Palm hosts.
- The regional-root test distinguishes existing behavior: Core and Palm redirect to add a valid
  region, while Warp root controllers resolve the region in place. No controller callback changed.
- The shared layout test records Palm's existing `:head` yield explicitly. No layout behavior was
  changed to satisfy the retargeted contract test.

## Deviations From Plan

- Vite and stylesheet contract checks now enumerate the retained layouts and active stylesheets,
  including Core Dev. Inactive frontend sources were not deleted because frontend migration and the
  Avatar screen are outside this Rails route-removal unit.
- No database configuration, schema, or development data changed. Test execution used the existing
  test database environment. No external service was changed.

## Review Notes

- Final route inventory: `core`, `warp`, `palm`, `mission`, `flipper`, `blazer`, `pghero`,
  `swagger`, `performance`, `coverband`.
- Tests and checks run: `test/security`, the retained-surface focused group, the serial full Rails
  suite, `bin/rubocop`, Brakeman, test-mode runner, and `git diff --check`. Final outcomes and the
  baseline comparison are in `evidence/2026-11-09-sphere-route-separation-T4J8.md`.
- Not run: Rails system/browser tests and JavaScript tests. No frontend source or browser behavior
  was moved in this route-removal unit.
- The full failure/error name, exception, first repository line, and baseline comparison list is
  outside the repository at `/tmp/sphere-route-separation-failure-metadata-2026-11-09.tsv`.
- The repository had existing uncommitted changes; no commit was created.
