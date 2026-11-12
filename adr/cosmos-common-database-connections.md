# Cosmos Common Database Connections (2026-11-08)

## Status

Accepted (2026-11-08), direction only. Implementation is decided later.

## Context

The four Cosmos repositories (`umaxica-apps-cosmos-access`, `-governance`, `-sphere`, `-press`)
started as copies of one application and will each keep only the databases they own. Some databases
serve every application regardless of domain. Naming them the same way in every repository keeps
operations, tooling and configuration uniform.

`adr/cosmos-identity-authentication-global-authorization-split.md` decision 12 forbids Access and
Governance from sharing a database. "Common" here therefore means the same connection name and role,
with each repository owning its own instance.

Observed in `umaxica-apps-cosmos-access` at `281a9e5c5`:

- `primary` holds only Blazer and Flipper tables.
- `queue` is the Solid Queue database.
- `storage` holds Active Storage records.
- `chronicle` holds audit tables for several domains in one schema.
- Solid Cache and Solid Cable are not used; there is no `config/cache.yml` or `config/cable.yml`.
- `search` is documented as a per-region instance.
- `occurrence` records when identifiers (email, IP, telephone, domain, zip, area, JWT and others)
  were observed, plus denial counters. It is history only, not a ban list: bans are enforcement
  cases (`adr/unified-enforcement.md`). Most writes come from authentication code. A comment in
  `app/models/occurrence_record.rb` describes it as one instance shared worldwide; the actual
  deployment was not verified.

## Decision

1. **Every repository has its own instance of these connections, with the same name and role:**
   - `primary`: the default database. Which database it points to stays an environment setting.
   - `queue`: Solid Queue.
   - `storage`: Active Storage.
   - `chronicle`: audit records. The current full schema is kept as is in every repository, unused
     tables included, to avoid the migration cost of splitting it.
2. **These connection names are reserved in every repository:** `cache` (Solid Cache), `cable`
   (Solid Cable), `search` and `occurrence`. A repository that needs one of these roles uses that
   name, and no repository uses these names for anything else. Reserving a name does not require
   configuring it.
3. **No instance is shared between repositories.** This applies to common and reserved connections
   alike.
4. **`occurrence` is used mainly by Governance.** Any repository that keeps an `occurrence` database
   keeps its own independent instance; no repository reads or writes another repository's
   `occurrence`.
5. **Jobs work only on their own repository's databases.** Recurring and background jobs, such as
   retention purges, never read or write another repository's databases.
6. **Rate limits and other counters are not shared between repositories.** Each repository counts in
   its own units and keeps its counters in its own stores (for example its own Valkey); no
   repository's limit is consumed or reset by another repository's traffic.

## Consequences

- Operator tools (`.dev` hosts), job processing and file attachments work the same way in every
  repository.
- Each repository carries `chronicle` tables it does not use.
- If `occurrence` is currently deployed as one shared instance, moving to independent instances
  under decisions 3 and 4 requires a separate migration decision.
- Authentication code in Access writes most `occurrence` rows today; where those writes go once
  Governance is the main user is not decided.

## Open Questions

- Which repositories other than Governance keep `occurrence`, and how existing `occurrence` data is
  handled.
- Which repositories use `search`.
- Whether and when Solid Cache and Solid Cable are adopted.
