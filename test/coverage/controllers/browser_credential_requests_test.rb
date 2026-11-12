# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerBrowserCredentialRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "signed standby context is visible on the owning org surface without canonical actor reads" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL")
    https!
    cell = RpCellBinding.fetch("rp_core_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "standby-subject", sid: "standby-sid", absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "standby-subject",
      "sid" => "standby-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "standby-access",
      "scope" => "openid profile",
      "authn_ctx" => "standby",
    }
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) { get "/", params: { ri: "jp" } }

    assert_response :success
    page = JSON.parse(Nokogiri::HTML(response.body).at_css('script[data-page="app"]').text)
    indicator = page.fetch("props").fetch("chrome").fetch("restricted_mode")

    assert_predicate indicator.fetch("label"), :present?
    assert_equal "/sign/out/new?ri=jp", indicator.fetch("sign_out").fetch("href")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "unavailable OP signing keys preserve presented browser credentials and return unavailable" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "jwks-subject", sid: "jwks-sid", absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "jwks-subject",
      "sid" => "jwks-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "jwks-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    access = JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "jwks-sid.opaque"
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :unavailable, key: nil, reason: "fetch_failed")
    jwks.stub(:lookup, lookup) { get "/", params: { ri: "jp" } }

    assert_response :service_unavailable
    assert_equal access, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_equal "jwks-sid.opaque", cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_nil enrollment.session.reload.revoked_at
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "invalid credentials on a JSON public page are refused instead of silently treated as anonymous" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed"
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "presented-local-session"
    get "/", params: { ri: "jp" }, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
  end
end
