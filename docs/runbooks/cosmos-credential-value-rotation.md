# Cosmos Credential Value Rotation

## Scope and trigger

Rotates the values inside each Cosmos repository's development and test credentials (HMAC salts,
blind-index keys, provider secrets and other entries) that are still identical across Access,
Governance, Press and Sphere because the repositories were copied from one tree. The master keys
were already replaced on 2026-11-08; this runbook covers the values. Run it once, in all four
repositories in one coordinated step, just before the cross-repository connection work starts
(`docs/backlog/2026-11-08-github-actions-master-key-rotation.md`, schedule 2026-11-10).

## Prerequisites and owners

- Owner approval for the whole step, and a pause of every agent working in the four repositories.
- Governing records: `adr/runtime-secret-isolation-deferred.md`,
  `adr/cosmos-secret-key-base-in-ssm-parameter-store.md`,
  `docs/runbooks/rails-master-key-rotation.md`.
- Values are never printed, pasted into chat, tracked files or shell history.

## Procedure

1. **Inventory (read-only).** In each repository, list credential entry names (never values) for
   development and test.
2. **Check the old shared key against production (critical).** Until 2026-11-08 development and
   production shared one master key, and `config/credentials/production.yml.enc` remained in Git
   history until then. Anyone holding a previous development key can therefore decrypt the
   historical production credentials. In a private, offline session, compare the names in that
   historical production file with what staging and production use today (their secret stores).
   Every value that is still live in staging or production must be rotated there through that
   environment's own procedure, and the previous development keys must then be handled with
   production-level care.
3. **Check development values are not reused in staging or production (critical).** For every
   provider application (Google, Apple, Microsoft Entra ID, Cloudflare Turnstile and others), blind
   index and HMAC key, confirm that development and test values differ from staging and production.
   Any shared value is rotated in staging or production as well. **Apple (owner, 2026-11-10):** the
   Sign in with Apple private key is not rotated, to avoid the Apple Developer Program cost.
   Accepted for development only, and only if step 2 or 3 confirms the key is not used in staging or
   production; if it is, production switches to a different key. If the Apple membership lapses,
   remove the Apple key from development credentials instead of keeping a key that may have leaked.
   **Update (owner, 2026-11-11): accepted risk.** The key is confirmed exposed: the Apple private
   key, key ID and team ID were decryptable from public Git history from 2025-09-03. The membership
   has lapsed, so the key probably cannot be revoked now. The owner accepts the risk and keeps the
   key in Access development credentials only (removed from Governance, Sphere and Press on
   2026-11-11). Before production: renew the membership, create a new key for production, revoke the
   exposed key, and never use the exposed key outside development.
4. **Rotate development and test values** per repository with
   `bin/rails credentials:edit --environment <environment>` inside that repository's runtime.
   Provider secrets are regenerated in each provider's console first. Rotating blind-index keys
   makes existing development data unsearchable; this is accepted under the hard reset.
5. **Restart** each application and confirm it boots.
6. **Back up the previous master keys** only now (so the backup can reveal retired values only): an
   encrypted archive on a USB memory stick kept in the owner's safe, with its passphrase stored
   separately. Remove any working copies from the machine used, including temporary folders and the
   trash. No other copy is kept.

## Verification

- Each repository's credentials open only with its own key and contain no value shared with another
  repository (compare fingerprints, never values).
- Development and test values differ from staging and production values.
- Each application boots, and sign-in, Turnstile and provider sign-in work in development.

## Rollback or recovery

Rotation is not reversible in place. If a step fails, keep the new values, fix forward, and use the
cold-storage backup only for incident investigation, never to restore retired values.
