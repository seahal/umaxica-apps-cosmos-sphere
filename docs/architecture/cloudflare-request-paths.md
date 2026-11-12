# Cloudflare Request Paths and Trust Boundaries

Cosmos Sphere serves the host-constrained Docs, News, Help, Info, and Edit surfaces, along with the
Mission, Flipper, Blazer, PgHero, Swagger, and Coverband operator tools. `config/routes/` owns the
route host constraints. Development and production Host Authorization admit the configured retained
hosts; an unknown host cannot enter a surface route set.

## Host and Forwarded-Host Checks

Host Authorization evaluates the HTTP `Host` Rails receives and, when present, the final
`X-Forwarded-Host` value. A proxy routing target is not a request host and must not be added to
`config.hosts` merely because it delivered the request.

Every proxy that changes `Host` or `X-Forwarded-Host` must preserve the selected surface's
configured host boundary. A request with mismatched or unconfigured host values must not gain access
to another surface or mounted tool. `RuntimeRole.route_owner` and the route guard add a
process-level check: unowned controller paths are refused even by the shared role.

## Development Aliases

Compose aliases exist for local retained surface and operator hosts that need to resolve to Rails on
the frontend network. Alias presence does not establish a route owner; routing remains governed by
the explicit constraints in `config/routes/`. Keep external identity-provider and relying-party
origins distinct from local aliases unless a current caller requires a local back-channel path.

See the [surface matrix](content-surface-matrix.md), the current
[subdomain map](../reference/subdomains.md), and
[development host exposure](../operations/development-host-port-exposure.md).
