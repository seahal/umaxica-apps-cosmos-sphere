# Sphere GUID retirement and operator host verification correction

Date: 2026-11-09. This corrects the development-database observation in
`evidence/2026-11-09-guid-retirement-tool-hosts-H7D2.md` after the user explicitly authorized
creating `development_publishing_db` and then `development_app_zenith_db` on `primary:5432` for the
HTTP check.

Both databases were absent at the time they were created. A catalog check confirmed the exact
configured target and absence; each database was created without changing or deleting another
database. No schema migrations, seed data, or database settings were changed. The Rails server still
returns HTTP 500 before tool authentication: its next missing configured development writer database
is `development_org_zenith_db` (`PG::ConnectionBad`, first repository frame
`config/initializers/schema_migration_if_not_exists.rb:10`). A read-only catalog comparison shows 24
of the 26 configured development writer databases are still missing. Their full list and the catalog
command are at `/tmp/sphere-guid-tool-hosts-H7D2/missing-dev-dbs.log`.

Thus the two database approvals were honored, but full-stack development HTTP verification remains
blocked until the remaining development database fleet is created and its schemas are initialized.
Those operations would affect 24 additional databases and run migrations on 26 newly created
databases; no such operation was authorized or executed. The prior 32 real route/HostAuthorization
component checks remain valid for route matching and tool authentication, but do not prove the full
middleware stack.

The temporary development server was stopped after the probes.

## Follow-up after authorization to create the remaining development databases

On 2026-11-09, the user authorized creating the remaining 24 development writer databases for the
HTTP check. A read-only catalog check confirmed the target was `primary:5432` (`10.89.12.3/32`,
PostgreSQL 18.6), with 26 configured writers and only the previously created
`development_publishing_db` and `development_app_zenith_db` present. Individual Rails tasks created
exactly the 24 names listed in `/tmp/sphere-guid-tool-hosts-H7D2/missing-dev-dbs.log`. A second
read-only catalog check confirmed all 26 configured writers are present.

No database was dropped or reset, and no application migration or seed task was run. With the
canonical seven public tool hosts supplied as process-only environment overrides, a development Puma
server started and each dashboard HTTP probe returned 500. The Mission request reported
`ActiveRecord::PendingMigrationError` with first repository frame
`lib/credential_deletion_finalizer.rb:42`. The server was stopped after the probes. Applying
migrations to the 26 development databases is a separate bulk persistence operation; approval for
that operation was requested but is not recorded in this evidence yet.
