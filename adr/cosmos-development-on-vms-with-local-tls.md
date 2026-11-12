# Cosmos Development Moves to Bare-Metal VMs with Local TLS (2026-11-10)

## Status

Accepted (2026-11-10). Direction only; the migration has not started. Until it does, the current Dev
Containers and Cloudflare Tunnels stay in use.

## Context

Each Cosmos repository (Access, Governance, Press, Sphere) runs in its own Dev Container, reached
through Cloudflare Tunnel. Inside a container, `OutboundHttp::LocalBackChannel` rewrites
server-to-server calls for first-party hosts to `http://<host>:<PORT>`, assuming one Rails process
answers every surface. The split broke that assumption: a rewritten call to another repository's
host reaches the caller's own container or no listener at all. Development and production also take
different paths (HTTP to the same process versus HTTPS between services).

## Decision

1. **Development leaves the Dev Containers.** Each repository runs directly on a VM ("bare metal"
   from the application's point of view), terminates TLS itself, and is reached under its real
   domain names locally, so development uses the same hostnames and HTTPS as production.
2. **`OutboundHttp::LocalBackChannel` is removed.** Every server-to-server call, including OIDC
   Discovery, JWKS, token, UserInfo and revocation, and an RP's own JWKS, uses its public HTTPS URL
   in every environment. No environment-specific URL rewriting remains.
3. **RP client keys for `private_key_jwt` follow the same design as the OP's signing keys**
   (`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`, amended 2026-11-10): in production each
   repository signs through AWS KMS and never holds its private key; in development and test the KMS
   client is stubbed and signs with a key kept in that repository's credentials, created
   deliberately by a person; a missing key stops boot. Keys are no longer generated at boot. Each RP
   publishes its public keys at `/.well-known/jwks.json` (Governance Base App:
   `https://www.umaxica.app/.well-known/jwks.json`) and Access fetches them through the client
   registration's `jwks_uri` (`docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md` in
   Access, problem 3).

## Consequences

- Until the VMs exist, removing `LocalBackChannel` routes cross-repository calls through each
  repository's Cloudflare Tunnel, with the failure modes in
  `docs/operations/cloudflare-private-origin.md` (Access lock, connector state, container
  lifecycle). A call from a repository to its own host also leaves and re-enters through its tunnel.
- `OutboundHttp::ConnectionAdapterPort` refuses endpoints that resolve to non-public addresses. On a
  VM where the real domain names resolve to local or private addresses, server-to-server calls will
  be refused. The development name resolution and this guard must be reconciled before the VMs are
  used; weakening the guard needs its own decision.
- Locally terminated TLS needs certificates that Ruby, the OS trust store and browsers accept. The
  issuing method (for example a local CA) is not decided here.
- The Dev Container, Compose and tunnel documentation becomes historical once the migration ends.

## Not Decided Here

- VM layout (one VM per repository or shared), provisioning, and how the VM hostnames resolve.
- Certificate issuance and trust distribution.
- Whether Cloudflare Tunnel remains for external access to development.
- Databases and supporting services (PostgreSQL, Valkey, observability) on the VMs.
