Task (umaxica-apps-cosmos-sphere only): remove Publishing from Sphere completely. Unattended run: do
not ask questions; record items that need the owner and continue. Never print secrets or environment
values. Never edit config/credentials/*.yml.enc. No push, no deploy, no change outside this
repository.

## Decision

Owner, 2026-11-13: Sphere does not need Publishing; remove it. This resolves the `publishing` row
marked PENDING in `docs/architecture/sphere-database-disposition.md` (the 2026-11-10 ADR amendment
kept its persistence in Sphere, the 2026-11-12 work order assigned its HTTP surfaces to Press):
Sphere keeps neither the persistence nor the surfaces. Whether Press owns Publishing data is decided
in Press, not here; do not copy or transfer anything.

Observed 2026-11-13 at `f65f1f29b`: `config/database.yml` and `db/` no longer contain a `publishing`
connection, migrations or structure file. Remaining references include
`app/controllers/concerns/sitemap.rb`, `app/controllers/concerns/fqdn_availability_gate.rb`,
`app/controllers/concerns/default_no_store.rb`, `config/blazer.yml`, and ADR and docs text.

## Work

1. Search the whole tree (case-insensitive `publishing`, and the model, table, route, job, policy,
   locale, fixture, OpenAPI, front-end and environment-variable names that belong to it). Classify
   each hit: Publishing feature (remove), unrelated use of the word (keep, list it), historical ADR
   or archived plan text (keep the history; amend status instead of rewriting).
2. Remove the feature: code, routes, views, front-end, jobs, policies, locales, fixtures, tests that
   exist only for it, OpenAPI paths, Blazer queries, environment variable reads and their entries in
   env example files (do not read or print real env files' values). No compatibility layer, no stub,
   no redirect left behind (`generic/no-compatibility-layer.mdc`).
3. Local databases: if a `publishing` development or test database still exists on the local
   PostgreSQL, list it with its table and row counts and do **not** drop it; the owner approves the
   drop separately.
4. Documents: set the `publishing` row in `docs/architecture/sphere-database-disposition.md` to
   REMOVED with this decision and date; amend the Publishing ADR's status in this repository
   (superseded for Sphere, owner 2026-11-13) without deleting the record; update README topology,
   mermaid diagrams and checklists that still show Publishing in Sphere. `rp_edit_org` (Edit) is a
   separate PENDING item: do not touch it, but report whether it only existed to serve Publishing.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes (no Publishing route), bin/rubocop, bundle exec erb_lint
--lint-all, bundle exec database_consistency, bun run check, then bin/rails test after a test
database reset (baseline: 1,508 tests passing in
`evidence/2026-11-12-remove-non-sphere-databases-R7P3.md`; explain every difference). Record in
evidence/YYYY-MM-DD-remove-publishing-XXXX.md (full `git rev-parse HEAD`; uncommitted changes
affected results): the classified hit list, what was removed, what was kept and why, local databases
found, documents amended, test results, and confirmation that config/credentials files are
unchanged.
