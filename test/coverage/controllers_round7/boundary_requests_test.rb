# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundSevenBoundaryRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "retained browser roots reject malformed scalar and ambiguous raw Jump return tokens" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each do |setting|
      ["rt=malformed", "rt=", "rt=first&rt=second", "rt%5Bchild%5D=value"].each do |query|
        browser = open_session
        browser.host!(ENV.fetch(setting))
        browser.https!
        browser.get("/?#{query}")

        assert_equal 400, browser.response.status
        assert_equal I18n.t("errors.messages.invalid_request"), browser.response.body
        assert_nil browser.response.location
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      end
    end
  end

  test "HEAD Jump returns fail closed without rendering a browser page" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    head "/?rt=malformed"

    assert_response :bad_request
    assert_empty response.body
    assert_nil response.location
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
  end

  test "network and developer CSP intake keeps the telemetry no-content contract" do
    %w(core.net.localhost core.dev.localhost).each do |surface_host|
      browser = open_session
      browser.host!(surface_host)
      browser.https!
      browser.post(
        "/csp-violation-report", params: '{"csp-report":{"violated-directive":"script-src"}}',
                                 headers: { "CONTENT_TYPE" => "application/csp-report", "Origin" => "null" },
      )

      assert_equal 204, browser.response.status
      assert_empty browser.response.body
      assert_nil browser.response.location
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end

  test "authenticated Warp and Palm roots refuse HTML without redirecting or revoking the local session" do
    [
      %w(rp_warp_app PUBLIC_WARP_SERVICE_URL client),
      %w(rp_warp_org PUBLIC_WARP_STAFF_URL operator),
      %w(rp_palm_app PUBLIC_PALM_SERVICE_URL client),
    ].each do |connection, setting, resource_type|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "root-subject", sid: "root-#{connection}", absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::EC.generate("secp384r1")
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "root-subject",
        "sid" => "root-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "root-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      access = JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        browser.get("/", params: { ri: "jp" }, headers: { "Accept" => "text/html" })
      end

      assert_equal 403, browser.response.status
      assert_equal "text/plain", browser.response.media_type
      assert_equal I18n.t("errors.messages.not_authorized"), browser.response.body
      assert_equal "private, no-store", browser.response.headers["Cache-Control"]
      assert_nil browser.response.location
      assert_nil enrollment.session.reload.revoked_at
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end
end
