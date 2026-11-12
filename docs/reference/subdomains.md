# Subdomain Map

## Routes Served by Cosmos Sphere

| Surface family | Audience host groups      | Route file                   |
| -------------- | ------------------------- | ---------------------------- |
| Docs           | service, corporate, staff | `config/routes/docs.rb`      |
| News           | service, corporate, staff | `config/routes/news.rb`      |
| Help           | service, corporate, staff | `config/routes/help.rb`      |
| Info           | service, corporate, staff | `config/routes/info.rb`      |
| Edit           | staff                     | `config/routes/edit.rb`      |
| Mission        | operator                  | `config/routes/mission.rb`   |
| Flipper        | operator                  | `config/routes/flipper.rb`   |
| Blazer         | operator                  | `config/routes/blazer.rb`    |
| PgHero         | operator                  | `config/routes/pghero.rb`    |
| Swagger        | operator                  | `config/routes/swagger.rb`   |
| Coverband      | operator                  | `config/routes/coverband.rb` |

The four content families have three audience host groups each. Edit has its own staff host group.
Each route file is the source of truth for the configured and local aliases. Operator-tool routes
also constrain requests to their own hosts; Coverband is drawn only when the request-serving process
enables its collector.

## Host Authorization

Development and production Host Authorization admit only configured hosts for the retained surfaces
and tools. The root route for an unmatched host returns a machine-readable 404; it does not create
another surface.

Identity-provider and relying-party origins that remain in configuration for Edit's external
protocol calls do not create inbound route constraints. The retired Auth, Base, Core, GUID, Palm,
Tech, Visa, and Warp controller surfaces are not served by this repository.

See the [content surface matrix](../architecture/content-surface-matrix.md) and
[Cloudflare request paths](../architecture/cloudflare-request-paths.md).
