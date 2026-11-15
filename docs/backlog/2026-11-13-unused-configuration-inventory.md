# Inventory and Removal of Unused Configuration (2026-11-13)

Owner: this repository. Status: backlog, **later** (owner, 2026-11-13: important, not now). Start
after the split cleanup, the PS256 cut-over and the CI static-check acceptance work are done.

## Why

The four Cosmos repositories were cut from one application. Each still carries configuration for
surfaces, databases, providers and features it no longer owns. Unused configuration hides the real
shape of the repository, keeps dead dependencies alive and makes missing-variable failures harder to
read.

## Scope

Everything under `config/` and the configuration it implies:

- `config/initializers/**`: an initializer stays only when this repository has a caller for what it
  configures.
- `config/database.yml`: connections, replica entries and role switching with no reader.
- `config/environments/**`, `config/application.rb`, `config/routes/**` leftovers, `config/*.yml`
  (Blazer, queue, recurring jobs, storage, feature flags), `config/locales/**` keys with no caller.
- Environment variables: names read by no code, and names documented or set in env example files,
  compose files, the devcontainer and `.github/workflows/**` that no code reads.
- Credentials: entry **names** no code reads (list the names only; the owner removes entries; never
  print values).
- Gems, jobs, fixtures and docs that existed only for removed configuration.

## Rules

- Inventory first: for each item record the reader (file and line) or "no reader", then the
  decision. Remove only items with no reader; no compatibility layer or placeholder is left.
- Required variables keep one-argument `ENV.fetch`; no code-side defaults
  (`adr/env-fetch-without-default.md`).
- Decisions that belong to the owner are listed, not taken: for example whether this repository
  keeps replica connections (Sphere decided primary-only reads).
- `.github` is read-only inside the container; workflow changes are made from the host.

## First observations (Press, 2026-11-13)

`config/initializers/webauthn.rb`, `shrine.rb`, `preference_reference_defaults.rb`, `cors.rb` and
`outbound_email.rb` may have no remaining caller in Press; `config/database.yml` keeps replica
connections; `.github/workflows/ci.yml` still sets `OBJECT_STORAGE_BUCKET_AVATAR`. The workflow's
124 unused `POSTGRESQL_*_PUB` / `*_SUB` variables were already removed on 2026-11-13.
