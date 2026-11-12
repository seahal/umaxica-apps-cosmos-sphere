# Outbound Network Access Policy (2026-11-10)

## Status

Accepted (2026-11-10) as direction. The owner will research SSRF and combined SSRF-to-RCE risks
before implementation; the concrete design and any library change follow that research. Until then,
existing outbound code stays as it is and is marked `# TODO: AUDIT external access:` at each class
that reaches the network.

## Context

The application makes server-to-server calls: OIDC Discovery, JWKS, token, UserInfo and revocation;
back-channel logout; first-party authority APIs; Apple, Microsoft Entra ID and Google identity
endpoints; Cloudflare Turnstile; AWS SNS; the OpenTelemetry exporter. After the Cosmos split, more
of these cross repository boundaries (for example Access fetching each repository's
`/.well-known/jwks.json`). HTTP goes through Faraday, wrapped by our own `OutboundHttp::Connection`,
with an SSRF guard in `OutboundHttp::ConnectionAdapterPort` that resolves the host, refuses
non-public addresses and pins the connection to the checked address.

Outbound access ideally would not exist; in practice it cannot be avoided, so it must be bounded.

## Decision

1. **Use established, maintained libraries for outbound HTTP** (Faraday today). Keep our own code to
   thin configuration and to controls the library does not provide; prefer a well-known library over
   our own code for those controls when one covers them at least as completely.
2. **Never send credentials to an unintended destination.** Tokens, client assertions, API keys,
   cookies and other secrets are attached only to requests for destinations the application was
   configured to trust. A request that is redirected or resolves elsewhere does not carry them.
3. **Never execute what is fetched.** Responses are data: they are size-limited, parsed with safe
   parsers for their expected format, and never evaluated, deserialized into objects (`Marshal`,
   unsafe YAML) or written somewhere they could be loaded as code.
4. **Layered SSRF defense** for every outbound call:
   - an allowlist of destinations, loaded from configuration at boot and frozen, where the set of
     destinations is known (for example the four repositories' JWKS URLs);
   - resolve and check the address immediately before connecting, refuse internal, link-local and
     reserved ranges, and connect to the checked address (DNS rebinding);
   - do not follow redirects;
   - require HTTPS and reject malformed URLs (userinfo, fragments).

## Consequences

- Outbound code is reviewed against these rules, starting from the `TODO: AUDIT external access`
  markers.
- Moving development onto VMs where real domain names resolve to local addresses conflicts with the
  address check (`adr/cosmos-development-on-vms-with-local-tls.md`). Any relaxation applies only to
  allowlisted destinations, only outside production, and needs its own decision.
- Calls made inside gems (OmniAuth strategies, AWS SDK, Active Storage) are covered by reviewing
  their configuration and the destinations they are given, not by these markers.

## Not Decided Here

- Whether to replace `OutboundHttp::ConnectionAdapterPort` with a third-party SSRF library.
- The allowlist format and where each repository's allowlist lives.
