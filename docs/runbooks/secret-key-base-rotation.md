# Secret Key Base Rotation

## Scope and trigger

This runbook covers replacing `secret_key_base` in a deployed environment. Run it only when the
value is suspected to be disclosed. **No zero-downtime or lossless rotation is currently
supported**; this runbook is the forced replacement and its accepted consequences.

The Rails master key, which decrypts the file that holds `secret_key_base`, is rotated separately by
[Rails master key rotation](rails-master-key-rotation.md). Rotating the master key does not change
`secret_key_base`.

## Why rotation is not lossless

Rails offers rotation only for its own primitives: `config.action_dispatch.cookies_rotations` for
signed and encrypted cookies, and `Rails.application.message_verifiers.rotate` for
`Rails.application.message_verifier`. This application also derives keys from `secret_key_base`
directly, through `Rails.application.secret_key_base`, `Rails.application.key_generator` and
`ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)`. None of those uses accepts an
old value, so Rails rotation settings do not reach them.

Inventory observed on 2026-11-08 at HEAD `308af3589fb2877f77ca65af63c85ed5744db5cc` (search for
`secret_key_base`, `key_generator` and `message_verifier(` under `app/`, `lib/` and `config/`):

| Effect of a new value                                           | Uses                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Persisted digests stop matching; permanent until re-issued**  | `SignSecretLookupDigest` (`lookup_digest` of issued secret credentials, for example `operator_secret_credentials`); `ClientSocialAuditOutbox.subject_digest_for` (audit `provider_subject_digest`, so new audit rows no longer correlate with old ones); `AuthenticationAuditWriter` audit digests; `StepUpObservabilityDigest`; `lookup_digest` of `app_enforcement_identifier_effects` and `org_enforcement_identifier_effects` if derived from this key (owner not confirmed)                                                                                                    |
| In-flight ceremonies, codes and handoffs fail; users restart    | OTP and email-code digests in `app/lib/*_code_digest.rb`; flow binding codecs in `app/lib/*binding_codec.rb`; `EmailVerificationChallengeable`; `StepUpPkceVerifierCipherAdapter`; `BaseAuthAdmissionCoordinator` handoffs; `SignInOtpResendState`; TOTP and secret-credential ceremony candidate stores; `SocialAuthSignupFinalizer`, `SignUpSocialPendingClientSupport` and the OmniAuth callback digest; OIDC authorization continuations (`message_verifier(:visa_authorization_continuation)`); `OidcLogoutRequest`; `IdentityOneTimeReveal`; `ClientSecretPresentationIssuer` |
| Signed references and cookies are rejected; users sign in again | Signed and encrypted cookies; `SignedSessionReference`; `SessionLimitResolutionTokenRef`; `RedirectsSignedTargetSupport`                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Queued outbound messages fail to decrypt                        | `OutboundSensitivePayload` (OTP and verification tokens in notifications not yet delivered)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Rate-limit buckets reset once                                   | `AuthenticationRateLimitKey`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |

Treat this table as a starting point, not a complete contract: re-run the search before acting.
Making rotation lossless needs a code and data decision (per-use rotation support and a re-digest
plan for persisted digests); it is outside this runbook.

## Prerequisites and owners

- An approved incident decision accepting the consequences above, including re-issuing affected
  secret credentials. Replacing the value is irreversible for anything issued under the old value.
- Write access to the credentials of the affected environment (see
  [Rails master key rotation](rails-master-key-rotation.md) for key handling).
- Where the deployed environment takes the value from: Rails reads `ENV["SECRET_KEY_BASE"]` first,
  then `Rails.application.credentials.secret_key_base`. Confirm which one the environment uses
  before starting; this repository does not record it for production.

## Procedure

1. Generate a new value: `bin/rails secret` (128 hex characters).
2. Store it where the environment reads it: in the credentials file through
   `bin/rails credentials:edit --environment <environment>` (with a single master key, see the
   master key runbook), or as a new version of `SECRET_KEY_BASE` in the secret store. Never write it
   to a tracked plaintext file, an issue or a chat.
3. Drain or accept the loss of queued notification jobs that carry `OutboundSensitivePayload`.
4. Deploy and restart every node in one rollout. Nodes with different values reject each other's
   cookies and handoffs while both run.
5. Re-issue every secret credential whose `lookup_digest` was computed with the old value, through
   its owning procedure, and notify affected holders.
6. Record the incident and the cut-over time, so audit readers know that `provider_subject_digest`
   values before and after it are not comparable.

## Verification

- Application boot succeeds on every node.
- A new sign-in, a new OTP and a new secret credential each succeed end to end.
- A secret credential issued before the cut-over is rejected (expected) until re-issued.

## Rollback or recovery

Restoring the old value restores everything issued under it and invalidates everything issued after
the cut-over. Do not restore it after a disclosure; the old value must be treated as compromised.

## Basis

The inventory above was read from code only. The consequences were not exercised against a deployed
environment, and the derivation source of the enforcement `lookup_digest` columns was not traced.
