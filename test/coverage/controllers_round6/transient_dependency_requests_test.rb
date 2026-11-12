# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundSixTransientDependencyRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "a notice consumption outage after a real logout never manufactures a completed ceremony" do
    host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    host!(host)
    https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "consume-outage-subject", sid: "consume-outage-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "consume-outage-subject",
      "sid" => "consume-outage-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "consume-outage-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) do
      post "/sign/out", params: { ri: "jp" }, headers: {
        "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
      }
    end

    assert_response :see_other
    state = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state")

    assert_predicate enrollment.session.reload.revoked_at, :present?
    cache = Valkey::AuthState::SignOutNoticeStore.new
    attempts = 0
    # The producer and read use the real notice store. Only the storage consumption boundary
    # fails, representing an unavailable cache after the matching continuation was validated.
    cache.stub(
      :consume, ->(**) {
                  attempts += 1
                  raise Umaxica::Valkey::Unavailable, "notice consumption unavailable"
                },
    ) do
      Valkey::AuthState::SignOutNoticeStore.stub(:new, cache) do
        get "/sign/out/completion", params: { ri: "jp", state: }
      end
    end

    assert_equal 1, attempts
    assert_response :not_found
    assert_nil response.location
    assert_nil response.headers["Clear-Site-Data"]
    assert_predicate enrollment.session.reload.revoked_at, :present?
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
    get "/sign/out/completion", params: { ri: "jp", state: }

    assert_response :not_found
    assert_nil response.location
  end

  test "contradictory remote refresh lifetimes fail explicitly before new browser credentials are installed" do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL")
    https!
    cell = RpCellBinding.fetch("rp_warp_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "bad-lifetime-subject", sid: "bad-lifetime-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    refresh = "bad-lifetime-sid.original"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
    key = OpenSSL::PKey::EC.generate("secp384r1")
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "bad-lifetime-subject",
      "sid" => "bad-lifetime-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "bad-lifetime-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    access = JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    # The HTTP client's success contract checks access-token presence; this malformed OP
    # response has positive lifetimes but violates their ordering at the browser boundary.
    tokens = {
      access_token: access,
      refresh_token: "bad-lifetime-sid.rotated",
      token_type: "Bearer",
      expires_in: 300,
      refresh_token_expires_in: 1,
    }
    remote = OidcOpTokenClient::Result.new(outcome: :success, token_response: tokens, error: nil)
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) do
      OidcOpTokenClient.stub(:refresh, remote) do
        error = assert_raises(ArgumentError) { get("/dashboard", params: { ri: "jp" }) }
        assert_equal "RP refresh expiry precedes access expiry", error.message
      end
    end

    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal refresh, cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_nil enrollment.session.reload.revoked_at
  end
end
