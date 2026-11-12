# Core: Recreate the `www-jp.umaxica.app` Path Route on Sphere's Tunnel

Owner: Sphere (`core`). Recorded 2026-11-09.

## Note

During the Cloudflare Tunnel split, the existing Access tunnel ("Auth") held a published route on
`www-jp.umaxica.app` restricted by this path regular expression (Core moves to `www-jp.*` on
2026-11-10; recreate the route there, see `adr/cosmos-sphere-surfaces-and-rp-independence.md`):

```text
^/((api/v0|oidc|sign)(/.*)?|\.well-known/jwks\.json|csp-violation-report)$
```

It matches `/api/v0`, `/oidc` and `/sign` with any subpath, `/.well-known/jwks.json` and
`/csp-violation-report`, and nothing else.

The route leaves the Access tunnel. It must be recreated later on Sphere's tunnel (`sphere-jp-dev`,
`plans/2026-11-08-cloudflare-tunnel-split.md`) for `core`.

## Open When Recreating

- Whether every listed path still belongs to `core` after the split: `sign` and `oidc` are RP
  protocol endpoints (`adr/cosmos-base-surface-decomposition.md`, group 9), and the JWKS path must
  serve the RP's own keys, not Access's OP keys.
- The service URL and the Cloudflare Access policy for the route; record them when it is created.
