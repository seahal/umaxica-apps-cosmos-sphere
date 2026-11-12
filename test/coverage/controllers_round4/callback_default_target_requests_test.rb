# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundFourCallbackDefaultTargetRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "each retained callback without a target uses its explicit own landing after verified OIDC" do
    [
      ["rp_core_app", "PUBLIC_CORE_SERVICE_URL", "client", "/", RpCoreAppSession],
      ["rp_core_org", "PUBLIC_CORE_STAFF_URL", "operator", "/", RpCoreOrgSession],
      ["rp_warp_app", "PUBLIC_WARP_SERVICE_URL", "client", "/dashboard", RpWarpAppSession],
      ["rp_warp_org", "PUBLIC_WARP_STAFF_URL", "operator", "/dashboard", RpWarpOrgSession],
      ["rp_palm_app", "PUBLIC_PALM_SERVICE_URL", "client", "/dashboard", RpPalmAppSession],
    ].each do |connection, setting, resource_type, destination, session_class|
      browser = open_session
      host = ENV.fetch(setting)
      browser.host!(host)
      browser.https!
      browser.post(
        "/sign", params: { ri: "jp" }, headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 303, browser.response.status
      redirect = URI.parse(browser.response.location)
      authorization = Rack::Utils.parse_nested_query(redirect.query)
      if authorization.key?("rt")
        jump_payload, = JWT.decode(authorization.fetch("rt"), nil, false)
        authorization = Rack::Utils.parse_nested_query(URI.parse(jump_payload.fetch("url")).query)
      end
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      key = OpenSSL::PKey::EC.generate("secp384r1")
      identity = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => "default-target-subject",
        "sid" => "default-target-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "nonce" => authorization.fetch("nonce"),
        "jti" => "default-target-id-#{connection}",
        "typ" => "id-token+jwt",
        "act" => resource_type,
        "auth_time" => 1.minute.ago.to_i,
      }
      id_token = JWT.encode(identity, key, "ES384", { kid: "external-op", typ: "id-token+jwt" })
      access_claims = identity.except("nonce", "typ", "act").merge(
        "client_id" => cell.client_id, "scope" => "openid profile", "authn_ctx" => "normal",
      )
      access = JWT.encode(access_claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
      tokens = {
        id_token:,
        access_token: access,
        refresh_token: "default-target-#{connection}.opaque",
        token_type: "Bearer",
        expires_in: 300,
        refresh_token_expires_in: 600,
      }
      result = OidcOpTokenClient::Result.new(outcome: :success, token_response: tokens, error: nil)
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      OidcOpTokenClient.stub(:authorization_code, result) do
        jwks.stub(:lookup, lookup) do
          browser.get(
            "/oidc/callback", params: {
              state: authorization.fetch("state"), iss: issuer, code: "external-code", ri: "jp",
            },
          )
        end
      end

      assert_equal 302, browser.response.status
      assert_equal destination, URI.parse(browser.response.location).path
      assert_equal host, URI.parse(browser.response.location).host
      local = session_class.includes(:op_session_binding)
        .find_by!(public_id: browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE])

      assert_predicate local, :active?
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_equal tokens.fetch(:refresh_token), browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    end
  end
end
