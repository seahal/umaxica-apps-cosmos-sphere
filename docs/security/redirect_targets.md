# Redirect targets

The retained Rails surfaces are Docs, News, Help, Info, Edit (`org`), and the operator tools listed
in `README.md`. Edit RP sign-in returns through the path-only `target_link_uri` held in its signed
OIDC state. The former `pt`, `nt`, and `xt` request lanes and their Auth/Base navigation callers are
retired. Earlier redirect ADRs preserve their decision history.

## Local path redirects

Use `RedirectsPathTargetResolver` before redirecting to a request-derived local path. It accepts
path and query only. It rejects schemes, hosts, protocol-relative URLs, userinfo, fragments,
backslashes, control characters, encoded slash or backslash escapes, blank values, and executable
schemes. Rejection results carry a reason and a digest of the unsafe input; logs do not include the
raw target.

`CommonRedirect#safe_redirect_to`, `#safe_redirect_back_or_to`, and `#safe_internal_path` are the
current controller helpers for local paths. Local redirects set `allow_other_host: false`. A missing
or rejected candidate uses the caller's explicit internal fallback.

## Edit RP OIDC redirects

`OidcSsoInitiator` starts authorization with a registered client, registered callback URL, PKCE,
nonce, and signed state. `target_link_uri` is normalized to an internal path before it enters that
state. The callback verifies the state, browser flow, OP issuer, code response, nonce, and ID Token
before committing the local RP session.

An absolute authorization endpoint is redirected directly only after `Oidc::AcmeServiceOrigin`
validates it for the Edit client. Invalid or unsupported destinations are refused.
`allow_other_host: true` remains limited to the approved OIDC authorization handoff, the validated
Jump gateway response, and the registered OIDC logout handoff.

## Jump return tokens

`JumpRtIssuer` signs a short-lived token containing a validated destination, issuer, audience,
purpose, and replay policy. `RedirectsJumpGatewayUrl` accepts only a bounded JWT-shaped token and
the boot-validated HTTPS gateway origin. The destination URL is never placed directly in the gateway
URL.

`JumpRtReturnVerification` runs before the Edit RP's normal request flow for requests carrying a
return token. `JumpRtReturnVerifier` checks the signature, issuer, audience, directed source edge,
token age, replay-policy claim, and exact normalized request URL before it removes `rt`. Invalid
returns are refused before normal authentication.

## OIDC protocol destinations

OIDC `redirect_uri` and `post_logout_redirect_uri` values come from the registered client store.
They identify the final RP callback or completion endpoint and are checked against that client's
registration. They are protocol fields; request parameters cannot replace the registered
destination.

## Verification references

- `test/services/redirects_path_target_resolver_security_test.rb`
- `test/services/redirects/jump_gateway_url_test.rb`
- `test/services/jump_rt/issuer_test.rb`
- `test/services/jump_rt/return_verifier_test.rb`
- `test/integration/edit_org_jump_rt_sign_in_test.rb`
- `test/unit/security/redirect_target_usage_test.rb`
