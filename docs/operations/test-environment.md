# Rails test environment

Rails tests use explicit test-only PostgreSQL databases and Valkey logical databases declared in
`config/valkey.yml`. A test process must not inherit the development host or the development Valkey
databases.

Canonical Compose services are `valkey-cache` and `valkey-kvs`. Test cache does not connect to
Valkey; it uses `ActiveSupport::Cache::MemoryStore`. Rate-limit and auth-state use `valkey-kvs`
logical DBs 4 and 6.

Inside a Dev Container the supported entry point is:

```bash
bundle exec rails test
bun run test
```

Orchestration supplies `VALKEY_KVS_HOST`. Do not export `VALKEY_TEST_HOST`, `CACHE_REDIS_URL`,
`RATE_LIMIT_REDIS_URL`, `AUTH_STATE_REDIS_URL`, or a run namespace before those commands. Rails
generates `VALKEY_NAMESPACE_RUN_ID` when it is absent.

`config/database.yml` fixes every test database to `primary:5432` as `root` (password
`development`); no environment variable selects the test PostgreSQL target, so an exported variable
cannot redirect a destructive preparation. `Umaxica::TestEnvironment::DatabaseSafety` holds the same
fixed values and validates every effective test database configuration before opening Active Record
connections. `DATABASE_URL` and other database URL overrides cannot silently redirect a test
connection to a non-test database.

Application auth-state and rate-limit keys include the run and worker identifiers. Parallel Minitest
workers share logical DBs 4 and 6 and isolate keys by namespace (`<run-id>:<worker-id>:…`). Cleanup
uses prefix SCAN + DEL. `FLUSHDB` and `FLUSHALL` are forbidden.

The test boundary prevents provider delivery: Action Mailer uses the `:test` delivery method, the
SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. An unstubbed Turnstile
call raises a test-boundary error rather than invoking Cloudflare. Faraday requests are blocked
unless the test uses `OutboundHttpStub` (or another explicit test adapter) for the duration of the
request.

The `gait/` directory contains the JavaScript and React Vitest behavior suite. The repository has no
configured Playwright Rails E2E runner. Rails integration tests cover retained server-side browser
and API behavior.

## Rails System Tests

`test/application_system_test_case.rb` configures Capybara's Playwright driver with headless
Chromium, following Cosmos Access. Future scenarios under `test/system/` inherit
`ApplicationSystemTestCase`. No browser scenarios or automatic system-test CI job are added by this
setup.

Use the documented Rails development runtime with its test PostgreSQL databases, Valkey,
credentials, and host environment. Install the locked JavaScript dependencies with
`bun install --frozen-lockfile` and provision Chromium with
`node_modules/.bin/playwright install chromium` before running system tests. These preparation
commands have not been executed for this configuration-only change.

Select the owning surface's configured hostname explicitly, without a scheme, port, or path:

```bash
RAILS_ENV=test PARALLEL_WORKERS=1 SYSTEM_TEST_HOST="$PRIVATE_CORE_SERVICE_URL" \
  PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright \
  bin/rails test:system
```

The host variable must already be exported by the runtime. Use the appropriate configured host for
other surfaces and run each surface separately. Chromium maps only the selected hostname to
`127.0.0.1`; Capybara adds its local server port. Cross-surface browser journeys need their own
explicit host configuration before use.

The driver requires one worker before loading `test_helper.rb`, reusing its database safety,
fixtures, Vite build, and Valkey isolation. The CLI path is required to avoid an implicit `npx`
download. Optional `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium` selects an installed browser
and enables its Chromium sandbox. Leave it unset to use Playwright's provisioned browser.

The Ruby client is locked at 1.64.0 and the JavaScript CLI at 1.64.1, matching the inspected Access
setup; compatibility and browser execution remain unverified. Ordinary test-environment CSRF
settings remain in effect. Browser access to external providers is not isolated by this
configuration, so provider-backed scenarios require explicit network isolation before they are
added.

Ordinary `bin/rails test` excludes system tests. Explicitly selecting `test/` includes them;
coverage commands use the ordinary selection to keep browser provisioning separate. Failure
screenshots in `tmp/screenshots/` and `log/test.log` can contain sensitive page data and require
review before sharing.
