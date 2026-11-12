# Sphere route separation checkpoint

Date: 2026-11-09  
Revision: `44dfa264c91c58121e48800c6f2680464914e8c4`  
Worktree: existing uncommitted work remains in place and affects these observations. No commit was
created.

## Changes since the previous checkpoint

- Kept the root route draws limited to Core, Warp, Palm, and the seven retained operations tools.
- Removed obsolete Warp corporate preference API examples from the OpenAPI preference contract
  tests; that host still has health and revision endpoints, but its route file does not expose
  preferences.
- Updated the health contract description to name the retained Core app and Warp corporate hosts.
- The unsafe Core Jump/CSRF test that depended on the removed Base receiver route is absent. Active
  Core, Warp, and Palm Jump-return verification tests remain.
- No production authentication, authorization, CSRF, database, or route behavior was weakened or
  changed in this checkpoint.

## Verification

Command:

```sh
PUBLIC_FLIPPER_URL=flipper-sphere-jp.umaxica.dev PARALLEL_WORKERS=1 RAILS_ENV=test \
  bin/rails test test/contracts/openapi_preferences_contract_test.rb \
  test/integration/health_revision_contract_test.rb \
  test/integration/jump_rt_return_verification_test.rb
```

Result: 50 runs, 451 assertions, 4 failures, 0 errors. All four failures are the retained Core/Warp
app/org OpenAPI preference contract tests receiving the existing 403 authorization response. Their
test names already appear as failures in the supplied pre-change full-suite inventory; authorization
behavior was left unchanged. The health and Jump-return tests passed in this run.

The full serial suite and final static checks are pending. The prior checkpoint is
`evidence/2026-11-09-sphere-route-separation-S0R1.md`.
