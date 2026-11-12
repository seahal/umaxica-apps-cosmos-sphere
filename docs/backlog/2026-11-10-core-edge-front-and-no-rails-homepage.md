# Core: Edge Worker Serves Pages, Rails Serves No Homepage (2026-11-10)

Owner: Sphere (`core`), with `umaxica-apps-edge` for the Workers. Status: decided (owner), queued.

## Intended shape

Core's pages are rendered by the Edge Workers (`umaxica-apps-edge-{app,com,org}-core`, TanStack
Router), not by Rails. Rails `core` serves only the protocol and API paths: `/api/v0`, `/oidc`,
`/sign` (with subpaths), `/.well-known/jwks.json` and `/csp-violation-report`.

```text
www-jp.umaxica.<tld>/            -> Edge core Worker (pages)
www-jp.umaxica.<tld>/api/v0/...  -> tunnel -> Sphere Rails (Core)
                    /oidc, /sign, /.well-known/jwks.json, /csp-violation-report -> same
```

## Rails Core has no homepage (owner, 2026-11-10)

Like Auth and Visa (`adr/cosmos-base-surface-decomposition.md`, decision 9), Rails `core` answers
`/` with 404 and draws no page route outside the paths above, on app, com and org. Reason: a Rails
page on the same hostname as the Edge pages makes it unclear which one answers, and a routing or
tunnel mistake would silently show a Rails page instead of the Edge one ("it causes accidents").

Work order (Codex, this repository):

```
Make Rails Core serve no homepage:
- Remove the root route and any page route in config/routes/core.rb other than the /api/v0, /oidc,
  /sign, /.well-known/jwks.json, /csp-violation-report scopes and health/revision endpoints; delete
  the controllers, views and tests that only served those pages.
- Add tests: GET / and a former page path on each Core host return 404; the retained paths still
  route.
- Do not change authentication, OIDC callback or CSRF behavior. Run test/security. No commit.
```

## Edge wiring (found missing on 2026-11-10)

The Core Workers are deployed but bound to no hostname: no Worker routes in the `umaxica.app`,
`.com` or `.org` zones, no custom domains, and their `wrangler.jsonc` has no `routes` (workers.dev
only). So neither the former `jp.*` nor `www-jp.*` had an Edge answer for pages. In development the
`sphere-jp-dev` tunnel therefore sends every `www-jp.*` path to Rails, with no path rule
(`adr/cosmos-sphere-surfaces-and-rp-independence.md`, amendment 2026-11-10).

To restore the intended shape:

1. Codex (`umaxica-apps-edge`, read-only first): which environment the deployed Core Workers run in,
   which hosts they call for the API, and any remaining `jp.*` names.
2. Codex (`umaxica-apps-edge`): declare `www-jp.umaxica.<tld>/*` routes for the Core Workers in
   `wrangler.jsonc`, with Worker-less exception routes for the Rails paths above.
3. Claude (Cloudflare): create the same routes and put the Core path rule back on the tunnel.
4. Owner: deploy the Workers.

Do 2 to 4 together with the "no homepage" change above, so `/` never reaches Rails.
