# OIDC/OAuth Participation in Cosmos Sphere

The accepted OIDC/OAuth participation allowlist remains in
[`adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`](../../adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md).
This page describes the current routes in this repository after the surface hard reset.

## Retained Routes

| Surface                                              | Route file                               | OIDC/OAuth role                                                                                                  |
| ---------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Docs, News, Help, Info                               | `config/routes/{docs,news,help,info}.rb` | Non-participants; public content, health, revision, and read-only content API                                    |
| Edit                                                 | `config/routes/edit.rb`                  | Staff Publishing RP; verifies its own browser session and delegates sign-in to its configured external authority |
| Mission, Flipper, Blazer, PgHero, Swagger, Coverband | one file each under `config/routes/`     | Operator tools; each mount owns its host and access checks                                                       |
| Unknown host root                                    | `config/routes.rb`                       | Machine-readable 404; no OIDC/OAuth behavior                                                                     |

The Edit RP keeps only its own browser relying-party boundary in this repository. Its external
issuer and client host configuration does not create an inbound route for an Auth, Base, Core, GUID,
Palm, Tech, Visa, or Warp controller tree.

## Retired Controller Surfaces

The Auth, Base, Core, GUID, Palm, Tech, Visa, and Warp route files and controller trees have been
removed from Cosmos Sphere. Their earlier participation and non-participation rows were historical
implementation inventories. The current route ownership contract is in the
[content surface matrix](content-surface-matrix.md).

## Operator Tools

Operator tool routes are constrained to their own host families. A Rack mount retains its local
middleware, while mounted engines retain their configured access controls. A tool host does not
inherit Edit's browser session or an external identity provider's credentials.
