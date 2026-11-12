# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpCookieSurfaceContractTest < ActionDispatch::IntegrationTest
  test "each Core surface binds the signed client and subject to its own local session" do
    previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    [
      %w(rp_core_app PUBLIC_CORE_SERVICE_URL client),
      %w(rp_core_org PUBLIC_CORE_STAFF_URL operator),
    ].each do |connection, host_setting, resource_type|
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "exact-subject", sid: "exact-#{connection}",
        absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::EC.generate("secp384r1")
      payload = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "exact-subject",
        "sid" => "exact-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "exact-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      [
        payload.merge("sub" => "another-subject"),
        payload.merge("sid" => "another-session"),
        payload.merge("aud" => ["palm-app-jp"]),
        payload.merge("client_id" => "palm-app-jp"),
      ].each do |mismatched|
        browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
          JWT.encode(mismatched, key, "ES384", { kid: "external-op", typ: "at+jwt" })
        browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
        jwks.stub(:lookup, lookup) do
          browser.get("/api/v0/session", headers: { "Accept" => "application/json" })
        end

        assert_equal 401, browser.response.status, connection
        assert_equal "urn:umaxica:problem:authentication-required", browser.response.parsed_body.fetch("type")
        assert_not browser.response.parsed_body.key?("actor")
        assert_nil enrollment.session.reload.revoked_at
      end
    end
  ensure
    previous_flag.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] =
                                                                           previous_flag
  end
end
