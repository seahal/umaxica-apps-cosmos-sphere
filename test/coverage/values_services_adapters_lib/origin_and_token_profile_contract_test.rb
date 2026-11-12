# frozen_string_literal: true

require "test_helper"

class OriginAndTokenProfileContractTest < ActiveSupport::TestCase
  test "origin parsing normalizes default ports and rejects non origins" do
    origin = Oidc::AcmeServiceOrigin.from(" HTTPS://LOGIN.EXAMPLE.TEST:443/ ", default_scheme: "https")

    assert_equal "https://login.example.test", origin.origin
    assert_equal "https://login.example.test/oauth/token", origin.token_endpoint
    assert_equal "https://login.example.test/oauth/authorize?scope=openid",
                 origin.authorization_endpoint(query: { scope: "openid" })
    assert_equal "login.example.test", Oidc::AcmeServiceOrigin.host_from("login.example.test")
    assert_nil Oidc::AcmeServiceOrigin.host_from(nil)
    assert_nil Oidc::AcmeServiceOrigin.host_from("http://[invalid")
    [nil, "", "https://user:secret@example.test", "https://example.test/path", "https://example.test?x=y",
     "https://example.test/#fragment",].each do |value|
      assert_raises(ArgumentError) { Oidc::AcmeServiceOrigin.from(value, default_scheme: "https") }
    end
    assert_equal "http://localhost:8080", Oidc::AcmeServiceOrigin.from("localhost:8080", default_scheme: "http").origin
  end

  test "authorization decisions distinguish direct requests from each navigation boundary" do
    origin = Oidc::AcmeServiceOrigin.from("https://acme.example.test", default_scheme: "https")
    request = ActionDispatch::TestRequest.create("HTTP_HOST" => "core.example.test", "HTTPS" => "on")
    url = "https://acme.example.test/oauth/authorize"
    decision = origin.decision_for_authorize_url(url, request: request)

    assert_predicate decision, :direct?
    assert_not decision.jump?
    assert_not decision.rejected?
    assert origin.same_site_authorize_url?(url, request: request)
    assert_nil origin.same_site_rejection_reason(url, request: request)
    { "/relative" => "invalid_url",
      "http://[bad" => "invalid_url",
      "nativeapp:/callback" => "native_custom_scheme",
      "https://acme.example.test/other" => "not_acme_authorize",
      "http://acme.example.test/oauth/authorize" => "scheme_mismatch",
      "https://other.example.test/oauth/authorize" => "host_mismatch",
      "https://acme.example.test:8443/oauth/authorize" => "port_mismatch", }.each do |target, reason|
      result = origin.decision_for_authorize_url(target, request: request)

      assert_equal reason, result.reason_code
      assert_equal reason, origin.same_site_rejection_reason(target, request: request)
      (reason == "invalid_url") ? assert_predicate(result, :rejected?) : assert_predicate(result, :jump?)
    end
    request = ActionDispatch::TestRequest.create("HTTP_HOST" => "external.other.test", "HTTPS" => "on")

    assert_equal "site_mismatch", origin.decision_for_authorize_url(url, request: request).reason_code
    local = Oidc::AcmeServiceOrigin.from("http://localhost", default_scheme: "http")

    assert local.same_site_authorize_url?(
      "http://localhost/oauth/authorize",
      request: ActionDispatch::TestRequest.create("HTTP_HOST" => "localhost"),
    )
  end

  test "invalid authorization destinations are rejected without target metadata" do
    origin = Oidc::AcmeServiceOrigin.from("https://acme.example.test", default_scheme: "https")
    request = ActionDispatch::TestRequest.create("HTTP_HOST" => "core.example.test")

    ["", "/relative", "http://[invalid"].each do |url|
      decision = origin.decision_for_authorize_url(url, request: request)

      assert_predicate decision, :rejected?
      assert_equal "invalid_url", decision.reason_code
      assert_nil decision.target_scheme
      assert_nil decision.target_host
      assert_nil decision.target_port
      assert_nil decision.target_path
    end
  end

  test "RFC9068 validates every JOSE rejection partition" do
    valid = { "alg" => "ES384", "typ" => "at+jwt", "kid" => "key" }

    assert SecurityJwtRfc9068AccessTokenProfile.header_valid?(valid)
    [[nil, "MALFORMED_TOKEN"], [{}, "MALFORMED_TOKEN"], [valid.merge("kid" => ""), "MISSING_KID"],
     [valid.merge("alg" => "none"), "ALG_NONE"], [valid.merge("alg" => "RS256"), "ALG_MISMATCH"],
     [valid.merge("typ" => nil), "MISSING_TYP"],
     [valid.merge("typ" => "JWT"), "TYP_MISMATCH"],].each do |header, reason|
      assert_not SecurityJwtRfc9068AccessTokenProfile.header_valid?(header)
      assert_equal reason, SecurityJwtRfc9068AccessTokenProfile.header_rejection_reason(header)
    end
    assert_equal "INVALID_HEADER", SecurityJwtRfc9068AccessTokenProfile.header_rejection_reason(valid)
  end

  test "RFC9068 rejects invalid claim types and ambiguous resource scopes" do
    claims = { "iss" => "issuer",
               "exp" => 200,
               "aud" => "audience",
               "sub" => "subject",
               "client_id" => "client",
               "iat" => 100,
               "jti" => "identifier",
               "scope" => "openid domain:client", }

    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(claims)
    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(
      claims.merge(
        "aud" => ["a", "b"],
        "nbf" => 100,
      ),
    )
    [nil, claims.except("iss"), claims.merge("sub" => 1), claims.merge("iat" => "100"), claims.merge("exp" => nil),
     claims.merge("aud" => []), claims.merge("aud" => [""]), claims.merge("aud" => 1), claims.merge("aud" => ""),
     claims.merge("scope" => []), claims.merge("scope" => " "), claims.merge("nbf" => "100"),].each do |payload|
      assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
    end
    SecurityJwtRfc9068AccessTokenProfile::FORBIDDEN_CLAIMS.each do |claim|
      assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(claims.merge(claim => "legacy"))
    end
    assert_equal "client", SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(claims)
    ambiguous = claims.merge("scope" => "domain:client domain:operator")

    assert_nil SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(ambiguous)
    assert_nil SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(claims.merge("scope" => "domain:"))
    assert_empty SecurityJwtRfc9068AccessTokenProfile.parse_scopes(nil)
    assert_empty SecurityJwtRfc9068AccessTokenProfile.parse_scopes("scope" => [])
    assert_nothing_raised {
      SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!(
        ["https://accounts.example.com"],
        label: "issuer", production: true,
      )
    }
    assert_raises(ArgumentError) {
      SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!(
        ["localhost"], label: "issuer",
                       production: true,
      )
    }
    assert_nothing_raised {
      SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!(
        ["localhost"], label: "issuer",
                       production: false,
      )
    }
  end
end
