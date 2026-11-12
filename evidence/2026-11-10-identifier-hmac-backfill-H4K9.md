# Approved development identifier HMAC backfill

Date: 2026-11-10. HEAD: `44dfa264c91c58121e48800c6f2680464914e8c4`. Pre-existing uncommitted changes
and the uncommitted credential/source migration affected results. No commit was created. This
completion record supplements `2026-11-10-identifier-hmac-credentials-H4K8.md`; that earlier
record's pending state is historical. The owner explicitly approved the proposed development
backfill in the subsequent conversation. Scope: existing APP/ORG email/telephone lookup digests
only, using the already generated credentials.

## Execution

Executed `RAILS_ENV=development bin/rails runner tmp/identifier_hmac_authorized_backfill.rb`. The
wrapper asserted development, suppressed application/SQL logging, held write-blocking table locks on
the four identifier tables, and rechecked counts/decryptability/finalization before invoking the
existing `IdentifierBlindIndexBackfill.new.call`. APP and ORG principal database transactions kept
checks and saves together within each database. These are not a distributed atomic transaction. No
trigger, constraint, ownership protection or validation implementation was modified or bypassed. The
existing service's `save!(validate: false)` remained unchanged.

The locked preflight matched the approved scope exactly: one stale, non-finalized APP email and one
stale, non-finalized ORG email; no telephone records. Unexpected counts, finalized bindings or
malformed identifiers would abort before service execution. No such mismatch occurred.

| Result field             | First execution | Repeated execution |
| ------------------------ | --------------: | -----------------: |
| user_emails_updated      |               1 |                  0 |
| user_telephones_updated  |               0 |                  0 |
| staff_emails_updated     |               1 |                  0 |
| staff_telephones_updated |               0 |                  0 |

Before committing, compared each email's complete attributes in memory, excluding only
`address_digest` and `updated_at`: all other facts were unchanged. Verified each new digest and
looked up each existing email through `find_by_address`, comparing returned identity in memory. Both
passed. Repeating the service performed zero further updates. Both transactions committed
successfully. Only fixed status messages and aggregate counts were emitted; no keys, addresses,
telephone numbers, digests or row identifiers were displayed or retained by these checks.

## Post-commit verification

- `RAILS_ENV=development bin/rails runner tmp/identifier_hmac_readonly_check.rb`: APP email total
  1/stale 0; ORG email total 1/stale 0; both telephone totals 0/stale 0. Malformed and
  finalized-stale counts were zero for all four models.
- `RAILS_ENV=development bin/rails runner tmp/identifier_hmac_existing_lookup_check.rb`:
  fresh-process lookup of each existing APP/ORG email returned the original row. One row verified
  per realm. No OTP issuance, login-session establishment or full browser sign-in was attempted.
- Restarted the ordinary Foreman development processes with `SKIP_DB_PREPARE=1 bin/dev` so database
  preparation was skipped. The first attempt hit `EADDRINUSE` because the original Puma process
  outlived its Foreman shell. Terminated that original Puma, confirmed port release, and retried.
  Final web/Vite/jobs process startup was observed; Puma master PID 33493 listened on port 3000 and
  Vite listened on 3036. Stopped the temporary verification server on 3011; that port is closed.
- Local `GET /health/liveness` on port 3000, `Host: www-jp.umaxica.app`: **HTTP 200**.
- Existing-email lookup was verified again in a fresh development runner after the restart.

This turn changed retained development data only through the approved service and added this record
and the specification completion update. No credentials were regenerated, no development database
was deleted/reset, no secret values were printed, and no commit was made. The prior 56 targeted
tests, 107 security tests and scoped RuboCop pass are recorded in H4K8; no implementation code
changed in this operational continuation, so those suites were not rerun.

AC-6 is complete with explicit owner approval, successful committed backfill, idempotent repeat and
post-commit existing-record lookup verification. AC-5 now includes the ordinary restarted
development server's health response. This does not certify a complete interactive sign-in or other
repositories.
