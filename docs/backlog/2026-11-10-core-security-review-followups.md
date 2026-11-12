# Core Security Review Follow-ups (2026-11-10)

Source: a quick read-only review of core components in `umaxica-apps-cosmos-access` (the four
repositories share this code). Baseline controls were found in place: Rails CSRF protection with
exceptions only for the CSP report endpoint and the service-worker retirement GET; no `html_safe`,
`raw` or `<%==`; nonce-based CSP with reporting; `force_ssl`, `assume_ssl` and `config.hosts`;
`__Host-` session cookie, `HttpOnly`, `Secure`, `SameSite=Lax`; Argon2 password hashing; JWT
verification with fixed algorithm allowlists (one algorithm for application JWTs; DPoP and DBSC
allow ES256/ES384 or ES256/RS256; Apple sign-in delegated, see item 2); broad log parameter
filtering; JSON-only cookie serialization. The items below are not implemented yet; Codex is busy
with the split, so they wait.

## 1. Cross-host redirects only through Jump or Away (decided, owner)

Ten places redirect with `allow_other_host: true` (a 2026-11-10 review found no request-controlled
destination host; for example `common_redirect.rb`, `oidc_sso_initiator.rb`,
`oidc_rp_logout_launcher.rb`, `auth_oidc_result_handoff.rb`, `auth_step_up_result_handoff.rb`,
`visa_ceremony_binding_confirmation.rb`, `auth/org/ceremony_bindings_controller.rb`,
`auth/org/verification/cancellations_controller.rb`). Rebuild so that:

- a redirect to another subdomain of the same registered domain (same TLD, for example
  `www.umaxica.app` to `visa.umaxica.app`) goes through the Jump gateway;
- a redirect that crosses top-level domains, including first-party (for example `.com` to `.app`),
  and any external site goes through Away;
- every other redirect stays on the current host; `allow_other_host: true` is used only inside the
  Jump and Away paths, and a static check guards it.

Open redirects are especially dangerous with OAuth (authorization code and token theft), and the
destinations must never come from request input.

Confirmed 2026-11-10 (owner): this is the existing rule in `adr/secure-jump-link-redirector.md`
(amendment 2026-10-22); an earlier draft of this item wrongly said first-party cross-TLD goes
through Jump. Until Away exists, cross-TLD navigation fails closed, with no direct or Jump fallback.
Away has no runtime implementation yet. The Jump token issuer (`app/lib/jump_rt_issuer.rb`) signs
final destinations but has no allowlist of permitted final hosts; signing is not permission, so add
one under `adr/cosmos-outbound-network-access-policy.md`.

## 2. Ignore key-carrying JWT headers (decided, owner)

Several verifiers decode the header without verification to read `kid`, then verify with a pinned
algorithm. Confirm and enforce, with tests, that `jku`, `x5u`, `jwk` and `x5c` headers are never
used to locate or supply a key, and that a token carrying them is refused or the headers are
ignored, for every JWT the application verifies (OIDC, logout, step-up and ceremony contracts, Jump,
DPoP, Apple, Entra ID).

### Reviewed 2026-11-10

Every application-owned verifier was reviewed; none uses `jku`, `x5u`, `jwk` or `x5c` to locate or
supply a trusted key. Intentional exceptions, commented at the code with `NOTE:`: DPoP
(`app/lib/dpop_proof_verifier.rb`, RFC 9449) and DBSC registration
(`app/services/dbsc_registration_service.rb`) take a proof-of-possession key from `jwk`.

**Apple sign-in (reconsidered, owner):** the earlier acceptance of upstream algorithm policy
(`adr/jwt-validation-and-key-risk-decisions.md`) is reopened. omniauth-apple 1.4.0 calls
`id_token.verify!(jwk)` without an algorithm list. A second opinion (2026-11-10, local experiments
with generated keys) found no forgery route: `none` is refused explicitly and HMAC fails because of
how json-jwt types the key. But RS384, RS512, PS256, PS384 and PS512 tokens correctly signed with
Apple's key are accepted although Apple publishes RS256 only, and the policy depends on json-jwt's
key typing rather than an explicit list. Fix: pin RS256 in the application by overriding
`verify_signature!` in
`lib/external_authentication_infrastructure_omniauth_apple_nonce_enforcement.rb` (marked `FIXME:`),
add tests for `none`, HS256 and unknown `kid`, and submit the same change upstream to
omniauth-apple. Update the ADR when done.

Work order (prepared 2026-11-10, queued until the acceptance test of the Access split ends):

1. In the same module, override `verify_signature!`: refuse any header `alg` other than RS256 before
   verification, then verify with json-jwt passing `[:RS256]` (a symbol; a string does not match);
   raise omniauth-apple's `CallbackError` (`:id_token_signature_invalid`); keep the nonce
   enforcement unchanged.
2. Replace the `FIXME:` with a comment stating what is pinned and why.
3. Tests with a locally generated RSA key and JWKS (no Apple network): valid RS256 passes; **RS384,
   RS512, PS256, PS384 and PS512 correctly signed with the same trusted key are refused** (the
   discriminating cases: they pass today); `none`, HMAC algorithms, ES variants, malformed `alg`, a
   different RSA key and an unknown `kid` are refused; `jku`, `x5u`, `jwk` and `x5c` headers never
   select a key. Adjust any existing test that expects RS512 acceptance and say why.
4. Update `adr/jwt-validation-and-key-risk-decisions.md` and this item.

Separate finding, not affecting Apple's RSA path (details are not kept in the repository):
json-jwt's `verify_ecdsa_group!` checks a newly generated key instead of the supplied one, so the ES
algorithm label is not tied to the key's curve. Analyse separately before any report to the json-jwt
maintainer.

The owner wants to verify these findings independently before submitting anything upstream; see
`docs/backlog/2026-11-10-omniauth-apple-upstream-hardening.md`.

Do not modify the installed gems; do not weaken nonce checks. A local second opinion on the gem was
obtained and then deleted on purpose (it contained reproduction details).

## 3. Constant-time comparison where request-derived values meet stored values (decided, owner)

`ActiveSupport::SecurityUtils.secure_compare` is already used in about 60 files for codes, token
digests and fingerprints. Some places still compare with `==`, mostly digests and blind indexes
derived from request input against stored digests (for example
`email_sign_up_otp_delivery_guard.rb`, `telephone_sign_up_otp_delivery_guard.rb`,
`telephone_credential_registration_otp_delivery_guard.rb`,
`oidc_step_up_authorization_cancellation_committer.rb`,
`oidc_step_up_authorization_completion_committer.rb`, `base_step_up_admission_issuer.rb`,
`email_credential_registration_bootstrap_guard.rb`, `social_auth_signup_finalizer.rb`). Because the
compared values are hashes, a timing attack is impractical, but the rule is simpler to keep if every
comparison involving a secret or a request-derived digest uses `secure_compare`. Comparisons of
public identifiers (`public_id`, `*_ref`) do not need it.

A 2026-11-10 review found no raw password, OTP or bearer token compared with `==`. Raw binding
values compared with `==`/`!=` (medium priority, marked `NOTICE:` at the code): resolution challenge
(`visa_sign_in_limitations.rb`, `visa/app/sign/in/limitations_controller.rb`), DBSC challenge before
signature verification (`app/lib/dbsc_proof_verifier.rb`), session nonces after signature
verification (`identity_one_time_reveal.rb`, `redirects_signed_target_support.rb`). About fifty
further digest comparisons are low priority. Do not replace array or record comparisons blindly with
string APIs.

## 4. Access: refuse every abnormal path (Swiss cheese, owner)

Access holds the most sensitive surfaces. Apply layered defenses so the normal path passes and every
abnormal path is refused by more than one independent control: signature and algorithm checks,
binding to session and purpose, one-time use, expiry, server-side state, constant-time comparison
and explicit refusal of unknown inputs. Where a control is judged unnecessary, or a risk is
accepted, leave a comment at the code (`NOTICE:`, `NOTE:` or `FIXME:`) saying what was considered
and why, so reviewers can see that it was deliberate.
