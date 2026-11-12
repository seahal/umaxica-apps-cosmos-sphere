# HTTP Cache Policy for Rails Controllers

This is the current implementation reference for `Cache-Control` on controller responses. Static and
fingerprinted assets served by Propshaft or Vite are outside it. Mounted operator engines own their
response behavior and access checks.

## Policy

Retained application controllers use a default `no-store` policy. That includes Docs, News, Help,
Info, and Edit. An action may opt into caching only when its route and representation have an
explicit owner and the response is safe for the selected cache.

- `no-store`: no cache may store the representation.
- `no-cache`: the representation may be stored, but must be revalidated with the origin before
  reuse.
- `private`: may be stored by a private browser cache, not by a shared cache.
- `public`: may be stored by shared caches when the rest of the response permits it.

## Rules

1. Every retained surface root declares `include ::DefaultNoStore` and prepends
   `apply_default_no_store` once. Subclasses inherit the policy; `DefaultNoStore` itself registers
   no callback.
2. `apply_default_no_store` runs before the FQDN availability gate and all surface callbacks. A
   subclass that prepends callbacks and calls `ensure_fqdn_gate_first!` must preserve that order.
3. An action that needs caching opts in from inside the action with a Rails cache helper such as
   `fresh_when`, `stale?`, or `expires_in`. Typical shapes are:

   ```ruby
   # Shared-cacheable content, revalidated by validator.
   fresh_when(weak_etag: record.cache_key_with_version, last_modified: record.updated_at, public: true)

   # Browser-private revalidation.
   fresh_when(weak_etag: payload, cache_control: { no_cache: true, extras: ["private"] })
   ```

4. `skip_before_action :apply_default_no_store` is forbidden.
5. Do not opt into caching by assigning `Cache-Control` directly. Rails merges such headers with the
   default `no_store`; use the framework cache helpers. A stricter protocol-specific `no-store`
   value remains harmless.
6. A response whose body varies by the signed-in subject never opts into `public`. If it is cached,
   it is `private` and carries `Vary` for each selector of the representation.
7. Public content can be cacheable only when its owning route explicitly opts in. The retained
   content and management surfaces currently default to `no-store`.

The invariant tests under `test/security/invariants/` enforce policy inclusion, callback ordering,
and the prohibition on skipping the default. Keep those tests aligned with the current surface
inventory.

## Current roots

The application roots are `Docs::{App,Com,Org}::BareController`,
`News::{App,Com,Org}::BareController`, `Help::{App,Com,Org}::BareController`,
`Info::{App,Com,Org}::BareController`, and Edit's `ApplicationController`/`BareController`. These
roots own their callbacks and inherit no authentication lifecycle from another surface. The
repository-wide `ApplicationController` provides the CSRF baseline for mounted operator engines and
`UnknownHostsController`; it does not own a content or management session.

Health and revision responses, Edit's OIDC and sign-in flow, and other protocol responses keep
explicit `no-store` behavior. Preserve those headers when changing a caller. The surface route
contracts are listed in the [content surface matrix](../architecture/content-surface-matrix.md).
