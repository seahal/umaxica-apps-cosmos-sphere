# Publishing Persistence And Controller Design

Current architecture after the twelve-family encrypted persistence rewrite. See
`adr/publishing-twelve-family-encrypted-persistence.md`.

## Persistence is global

The 3 × 4 content matrix shares one `publishing` database. There are not twelve CMS databases. Each
cell is a physical table family:

`Publishing::Docs::App::Entry` → `publishing_docs_app_entries`

Family identity is the table/class. Do not persist `audience` or `surface` on content rows. Locale
is a column inside the family. Region is `Entry::REGION_CODE`.

## Persistence polymorphism is prohibited

No polymorphic associations, STI, exclusive-arc owners, discriminator ownership, or `constantize`
for family selection. Ruby modules/Concerns share behavior.

## Encryption

Revision and version `title`, `summary`, and `body` use non-deterministic Active Record Encryption
(existing key provider). PostgreSQL stores ciphertext `text`. Ruby sees String title/summary and a
Hash body. `content_digest` is SHA-256 of canonical plaintext and is not a confidentiality control.

## Media

`publishing_media_files` is global. Revision/version media usages are family-owned with a single
explicit owner FK.

## HTTP surface ownership

The owner-approved
[Sphere surface hard-reset specification](../../specs/sphere-operator-tools-hard-reset/spec.md)
keeps the `edit`, `info`, `news`, `help`, and `docs` routes and presentation in Cosmos Sphere. The
public published-entry endpoints are served on the retained Docs, News, Help, and Info host groups.
The earlier Cosmos Press transfer scope is superseded for this repository.

Sphere retains the Publishing database connection, schema, data, models, and domain operations. This
hard reset removes the Base route tree, including its local `/api/v0/publishing/*` routes. Edit's
`PublishingAuthorityClient` remains an outbound client for the separately owned Base authority API,
addressed through its configured host. This checkout no longer serves that authority API; a local
Base hostname routed back to this process therefore reaches the unknown-host response until a
separate owner service is available. No database or record migration is part of this route change.
See [`content-surface-matrix.md`](content-surface-matrix.md) for the current route boundary.
