# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundNineOperatorSessionRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Core operator session publishes only its own local public identity and never authenticates a client browser" do
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    browser = open_session
    browser.host!(ENV.fetch("PUBLIC_CORE_STAFF_URL"))
    browser.https!
    cell = RpCellBinding.fetch("rp_core_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "operator-session-subject", sid: "operator-session-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    access = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "operator-session-subject",
        "sid" => "operator-session-sid",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "operator-session-access",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }, key, "ES384", { kid: "external-op", typ: "at+jwt" },
    )
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) do
      browser.get("/api/v0/session", headers: { "Accept" => "application/json" })
    end

    assert_equal 200, browser.response.status
    assert_equal({ "authenticated" => true }, browser.response.parsed_body.slice("authenticated"))
    assert_equal({ "id" => enrollment.principal.public_id }, browser.response.parsed_body.fetch("actor"))
    assert_predicate browser.response.parsed_body.fetch("csrf_token"), :present?
    assert_equal "no-store", browser.response.headers["Cache-Control"]
    assert_nil enrollment.session.reload.revoked_at
    assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]

    client = open_session
    client.host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
    client.https!
    client.get("/api/v0/session", headers: { "Accept" => "application/json" })

    assert_equal 200, client.response.status
    assert_equal({ "authenticated" => false }, client.response.parsed_body.slice("authenticated"))
    assert_not client.response.parsed_body.key?("actor")
    assert_nil client.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_nil client.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end
end
