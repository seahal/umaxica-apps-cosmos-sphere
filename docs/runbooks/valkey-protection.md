# Valkey Protection

## Scope and trigger

Covers the Valkey instances that back `Rails.cache`, the rate-limit store and the auth-state store
(`config/valkey.yml`; production reads `CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL` and
`AUTH_STATE_REDIS_URL`). Run it when provisioning a Valkey instance for staging or production, when
changing its network placement or credentials, and as a periodic review.

Anyone who can write to these stores can change what the application reads back. Protecting Valkey
is therefore a security control, not only an availability concern.

## Prerequisites and owners

- Owner approval for any change to a deployed Valkey instance.
- Credentials come from the approved secret inventory; never paste them into documents or logs.
- Governing decisions: `adr/cosmos-outbound-network-access-policy.md`.

## Procedure

1. **Network.** Place every instance on a private network reachable only from this repository's
   application workloads. No public endpoint, no shared access from other repositories.
2. **Authentication.** Enable ACL users with passwords. Give each repository and each store (cache,
   rate limit, auth state) its own user, restricted to the commands and key patterns it needs.
   Disable the default user.
3. **Encryption in transit.** Use TLS (`rediss://` URLs) and verify the server certificate.
4. **Dangerous commands.** Deny administrative and scripting commands the application does not use
   (for example `CONFIG`, `FLUSHALL`, `KEYS`, `DEBUG`, `MODULE`, `EVAL`) for application users.
5. **Persistence and backups.** Treat snapshots as sensitive data; restrict and encrypt them.
6. **Monitoring.** Alert on authentication failures, connections from unexpected sources and
   unexpected command usage.

## Verification

- From outside the private network the instance is unreachable.
- An unauthenticated connection and a connection with another repository's user are refused.
- `rediss://` is in use and a certificate mismatch fails the connection.
- Application users cannot run the denied commands.

## Rollback or recovery

Network and ACL changes are reversible by restoring the previous configuration. If unauthorized
writes are suspected, treat cached data as untrusted: flush the cache store (owner approval
required), rotate the Valkey credentials, and review the risks below.

## Risks recorded for follow-up

- **Deserialization of cached data (open).** Until 2026-11-10 `Rails.cache` and the rate-limit store
  wrote entries with Marshal. They now write MessagePack (`serializer: :message_pack`), but Rails'
  `ActiveSupport::Cache::SerializerWithFallback#load` still recognizes and `Marshal.load`s any entry
  carrying a Marshal prefix, whatever serializer is configured. A value written into Valkey can
  therefore still become remote code execution on read. Closing this needs a cache coder that
  accepts only MessagePack and refuses every other payload (a code change, not yet made).
- **Poisoned public keys in the cache (open).** `Rails.cache` holds fetched JWKS for Apple
  (`AppleNotificationJwksCache`), Microsoft Entra ID (`EntraJwksCache`), Google
  (`external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb`) and Jump
  (`JumpRtReturnVerifier`). Anyone who can write to the cache can replace these keys and make forged
  tokens verify. A serializer change does not prevent this. Mitigation needs code changes (validate
  cached key sets, or keep them in process memory instead of Valkey) and is not scheduled; until
  then, the controls in this runbook are the only protection.
