# Public-Surface Test Coverage Ratchet

Status: implementing

## Purpose

Raise the measured coverage of Sphere's retained Ruby and TypeScript application code while keeping
tests at supported public or protected boundaries. Coverage describes which production behavior the
test suites execute; it does not replace assertions about results or authorization.

## Scope

- Vitest's configured `src/**/*.{js,ts,jsx,tsx}` production files, subject to the current deliberate
  exclusions in `vitest.config.ts`.
- Minitest's configured `{app,lib}/**/*.rb` production files, subject to the existing SimpleCov
  profile and filters.
- Tests, focused coverage configuration, and this change's evidence.

## Exclusions

- No CI/CD, GitHub Actions, Git hooks, environment-construction tests, coverage exclusions,
  thresholds hidden by file lists, or production-code changes solely to improve a percentage. A
  narrow runtime defect directly exposed by a public-boundary regression test may be fixed when its
  expected contract is already established.
- Do not call private methods from tests. Exercise private implementation only through observable
  public/protected APIs or framework boundaries. Keep genuine extension hooks protected.
- Do not change required assertions, weaken security checks, or test implementation details merely
  to mark lines as covered.

## Acceptance

- AC-1: Every configured Vitest coverage metric (lines, statements, branches, functions) is 100%.
- AC-2: Every configured SimpleCov metric (lines, branches, methods) is at least 99% for the full
  Minitest suite.
- AC-3: All added behavior tests invoke public/protected entry points; none directly invokes a
  private method through `send`, reflection, or visibility changes.
- AC-4: Existing tests, source population, and measurement exclusions remain intact except where a
  test is demonstrably obsolete under the current Sphere surface ownership.
- AC-5: The ordinary Vitest and Rails suites pass, and coverage thresholds enforce AC-1/AC-2.

## Verification

- Run focused suites while adding observable behavior cases, then run `bun run test:coverage` and
  `COVERAGE=true bin/rails test` against the isolated configured test databases.
- Inspect the generated LCOV/SimpleCov reports to verify each metric and remaining uncovered branch.
- Run `bun run check` and the affected Ruby format/lint checks after coverage configuration and test
  edits. Do not change CI configuration.

## Execution units

1. Close Vitest gaps by production module and public component/function boundary.
2. Close Minitest gaps by production namespace and public/framework boundary.
3. Raise the configured thresholds only after the corresponding complete suite reaches its target;
   perform a final full coverage run for both runtimes.
