# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundFiveCoreApiRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Core session storage failure is unavailable and preserves both independent credentials" do
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
    https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "api-storage-subject", sid: "api-storage-sid", absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "api-storage-subject",
      "sid" => "api-storage-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "api-storage-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    access = JWT.encode(claims, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "api-storage-sid.opaque"
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) do
      RpCoreAppRecord.stub(:connected_to, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
        get("/api/v0/session", headers: { "Accept" => "application/json" })
      end
    end

    assert_response :service_unavailable
    assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal access, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal "api-storage-sid.opaque", cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_nil enrollment.session.reload.revoked_at
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end

  test "Core refresh dependency failures remain retryable without rotating local state or opaque credentials" do
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    %i(dependency invalid_remote).each do |outcome|
      browser = open_session
      host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      browser.host!(host)
      browser.https!
      browser.get("/api/v0/session", headers: { "Accept" => "application/json" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.fetch("csrf_token")
      cell = RpCellBinding.fetch("rp_core_app")
      enrollment = RpCallbackCommitter.call(
        cell:, issuer: OidcIssuer.for_resource_type("client"), subject: "api-refresh-#{outcome}",
        sid: "api-refresh-#{outcome}", absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      refresh = "api-refresh-#{outcome}.opaque"
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
      result = OidcOpTokenClient::Result.new(outcome:, token_response: nil, error: "transport_failure")
      dispatches = 0
      OidcOpTokenClient.stub(
        :refresh, ->(**) {
                    dispatches += 1
                    result
                  },
      ) do
        browser.post(
          "/api/v0/token/refresh", headers: {
            "Accept" => "application/json",
            "Origin" => "https://#{host}",
            "Sec-Fetch-Site" => "same-origin",
            "X-CSRF-Token" => csrf,
          },
        )
      end

      assert_equal 1, dispatches
      assert_equal 503, browser.response.status
      assert_equal "urn:umaxica:problem:service-unavailable", browser.response.parsed_body.fetch("type")
      assert_equal refresh, browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      assert_equal 0, enrollment.session.reload.installed_generation
      assert_nil enrollment.session.revoked_at
      assert_empty browser.response.parsed_body.keys & %w(access_token refresh_token actor)
    end
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end

  test "Core API refuses unsupported response and body types before CSRF and remote credential dispatch" do
    previous = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
    https!
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "unconsumed.opaque"
    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("negotiation refusal must precede remote refresh") }) do
      get("/api/v0/session", headers: { "Accept" => "image/png" })

      assert_response :not_acceptable
      assert_equal "urn:umaxica:problem:not-acceptable", response.parsed_body.fetch("type")
      post(
        "/api/v0/token/refresh", params: "opaque-body", headers: {
          "Accept" => "application/json", "CONTENT_TYPE" => "text/plain",
        },
      )

      assert_response :unsupported_media_type
      assert_equal "urn:umaxica:problem:unsupported-media-type", response.parsed_body.fetch("type")
    end
    assert_equal "unconsumed.opaque", cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    previous.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous
  end
end
