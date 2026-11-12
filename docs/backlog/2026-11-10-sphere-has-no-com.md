# Sphere Serves No `.com` Surface (2026-11-10)

Owner: Sphere. Status: implemented (2026-11-11). The `.com` route and host configuration removal is
complete in Cosmos Sphere.

## Decision

Sphere does not serve the `.com` top-level domain. Rails Core has no corporate (`com`) routes, and
rather than build one, Warp's corporate routes are dropped too, so Sphere stays on `.app` and
`.org`.

Done in Cloudflare the same day: `www-jp.umaxica.com` and `warp-jp.umaxica.com` were removed from
the `sphere-jp-dev` tunnel routes, DNS, the `sphere-jp-dev` Access application and the
`sphere-development-*` Turnstile widgets.

## Implementation record (2026-11-11)

Sphere now routes only Core app/org/net/dev, Warp app/org, and Palm app hosts. The Rails Warp `.com`
route block and its controller/view/test dependencies were removed. The remaining host configuration
and local host lists were reviewed for corporate Warp entries. Requests to the former Warp `.com`
hosts are rejected by the route contract test.

## Original work order

```
Remove Sphere's .com surface:
- config/routes/warp.rb: remove the warp_corporate constraint block and what only it uses
  (controllers, views, tests); keep warp service (app) and staff (org).
- Remove PUBLIC_CORE_CORPORATE_URL / PUBLIC_WARP_CORPORATE_URL and other corporate-only settings
  from configuration, host lists, .env templates, Compose aliases (warp.com.localhost) and docs,
  names only, never values.
- Add tests: requests to the former .com hosts are not routed.
- Do not change authentication, OIDC or CSRF. Run test/security. No commit.
```

If a `.com` Core or Warp is ever needed, it returns as an Edge Worker surface (see
`docs/backlog/2026-11-10-core-edge-front-and-no-rails-homepage.md`), by a new decision.
