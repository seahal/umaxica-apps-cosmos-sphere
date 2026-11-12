# frozen_string_literal: true

require "test_helper"

class CoreAccessRefusalRefreshRetentionTest < ActionDispatch::IntegrationTest
  test "access refusal preserves the local session and explicit refresh installs verified credentials" do
    previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    [
      %w(rp_core_app PUBLIC_CORE_SERVICE_URL client),
      %w(rp_core_org PUBLIC_CORE_STAFF_URL operator),
    ].each do |connection, host_setting, resource_type|
      browser = open_session
      host = ENV.fetch(host_setting)
      browser.host!(host)
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "refresh-subject", sid: "refresh-#{connection}",
        absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      local_session = enrollment.session
      snapshot = local_session.attributes
      refresh = "external-session.external-secret"
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = local_session.public_id
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed-access-token"
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh

      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("GET must not consume the independent refresh credential") }) do
        browser.get("/api/v0/session", headers: { "Accept" => "application/json" })
      end

      assert_equal 401, browser.response.status
      assert_equal "urn:umaxica:problem:authentication-required", browser.response.parsed_body.fetch("type")
      assert_equal refresh, browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      assert_equal snapshot, local_session.reload.attributes
      assert_not browser.response.parsed_body.key?("actor")
      assert_not_includes browser.response.body, refresh

      browser.get("/api/v0/session", headers: { "Accept" => "application/json" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.fetch("csrf_token")
      key = OpenSSL::PKey::EC.generate("secp384r1")
      payload = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "refresh-subject",
        "sid" => "refresh-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "refresh-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      access = JWT.encode(payload, key, "ES384", { kid: "external-op", typ: "at+jwt" })
      token_response = {
        access_token: access,
        refresh_token: "external-session.rotated-secret",
        token_type: "Bearer",
        expires_in: 300,
        refresh_token_expires_in: 600,
      }
      remote = OidcOpTokenClient::Result.new(outcome: :success, token_response:, error: nil)
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        OidcOpTokenClient.stub(:refresh, remote) do
          browser.post(
            "/api/v0/token/refresh", headers: {
              "Accept" => "application/json",
              "X-CSRF-Token" => csrf,
              "Origin" => "https://#{host}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
        end

        assert_equal 204, browser.response.status
        assert_empty browser.response.body
        assert_equal 1, local_session.reload.installed_generation
        assert_equal Digest::SHA256.hexdigest(payload.fetch("jti")), local_session.current_access_jti_digest
        assert_equal snapshot.fetch("absolute_expires_at"), local_session.absolute_expires_at
        assert_equal "external-session.rotated-secret", browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]

        local_session.update!(revoked_at: Time.current)
        generation = local_session.installed_generation
        OidcOpTokenClient.stub(:refresh, ->(**) { flunk("a revoked local session must not dispatch to Access") }) do
          browser.post(
            "/api/v0/token/refresh", headers: {
              "Accept" => "application/json",
              "X-CSRF-Token" => csrf,
              "Origin" => "https://#{host}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
        end

        assert_equal 401, browser.response.status
        assert_equal generation, local_session.reload.installed_generation
      end
    end
  ensure
    previous_flag.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] =
                                                                           previous_flag
    Actor.clear
  end
end
