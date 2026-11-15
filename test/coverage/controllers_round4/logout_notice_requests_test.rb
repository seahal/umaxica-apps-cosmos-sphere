# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundFourLogoutNoticeRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "an active local session cannot use any retained surface completion endpoint" do
    [
      %w(rp_core_app PUBLIC_CORE_SERVICE_URL client),
      %w(rp_core_org PUBLIC_CORE_STAFF_URL operator),
      %w(rp_warp_app PUBLIC_WARP_SERVICE_URL client),
      %w(rp_warp_org PUBLIC_WARP_STAFF_URL operator),
      %w(rp_palm_app PUBLIC_PALM_SERVICE_URL client),
    ].each do |connection, setting, resource_type|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      sid = "active-completion-#{connection}"
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "active-completion-subject", sid:, absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "active-completion-subject",
        "sid" => sid,
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "active-jti-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      access = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        browser.get("/sign/out/completion", params: { ri: "jp", state: "untrusted-state" })
      end

      assert_equal 404, browser.response.status
      assert_nil browser.response.location
      assert_nil enrollment.session.reload.revoked_at
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end

  test "logout notices reject missing or mismatched state and cross-realm or stale browser replay" do
    browser = open_session
    host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    browser.host!(host)
    browser.https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "notice-bound-subject", sid: "notice-bound-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::RSA.generate(3072)
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "notice-bound-subject",
      "sid" => "notice-bound-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "notice-bound-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
    browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, lookup) do
      browser.post(
        "/sign/out", params: { ri: "jp" }, headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_equal 303, browser.response.status
    state = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query).fetch("state")
    cookie_key = Rails.application.config.session_options.fetch(:key)
    notice_cookie = browser.cookies[cookie_key]

    assert notice_cookie.is_a?(String) && !notice_cookie.empty?, "logout must issue a Rails notice cookie"
    browser.get("/sign/out/completion", params: { ri: "jp" })

    assert_equal 404, browser.response.status
    different_state = (state.start_with?("a") ? "b" : "a") + state[1..]
    browser.get("/sign/out/completion", params: { ri: "jp", state: different_state })

    assert_equal 404, browser.response.status
    other_realm = open_session
    other_realm.host!(ENV.fetch("PUBLIC_CORE_STAFF_URL"))
    other_realm.https!
    other_realm.cookies[cookie_key] = notice_cookie
    other_realm.get("/sign/out/completion", params: { ri: "jp", state: })

    assert_equal 404, other_realm.response.status
    browser.get("/sign/out/completion", params: { ri: "jp", state: })

    assert_equal 200, browser.response.status
    assert_equal '"cache", "storage"', browser.response.headers["Clear-Site-Data"]
    stale_browser = open_session
    stale_browser.host!(host)
    stale_browser.https!
    stale_browser.cookies[cookie_key] = notice_cookie
    stale_browser.get("/sign/out/completion", params: { ri: "jp", state: })

    assert_equal 404, stale_browser.response.status
    assert_nil stale_browser.response.location
  end

  test "logout completion enforces the notice lifetime immediately below at and above expiry" do
    [-1, 0, 1].each do |offset|
      browser = open_session
      host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      browser.host!(host)
      browser.https!
      cell = RpCellBinding.fetch("rp_core_app")
      issuer = OidcIssuer.for_resource_type("client")
      now = Time.current.change(usec: 0)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "expiry-subject-#{offset}", sid: "expiry-sid-#{offset}",
        absolute_expires_at: now + 10.minutes,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "expiry-subject-#{offset}",
        "sid" => "expiry-sid-#{offset}",
        "iat" => now.to_i,
        "nbf" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
        "jti" => "expiry-access-#{offset}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      jwks = OidcOpJwksClient.for_resource_type("client")
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      Time.stub(:current, now) do
        jwks.stub(:lookup, lookup) do
          browser.post(
            "/sign/out", params: { ri: "jp" }, headers: {
              "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end

      assert_equal 303, browser.response.status
      state = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query).fetch("state")
      Time.stub(:current, now + SignOutNotice::SIGN_OUT_NOTICE_TTL + offset) do
        browser.get("/sign/out/completion", params: { ri: "jp", state: })
      end

      assert_equal(offset.negative? ? 200 : 404, browser.response.status)
      assert_nil browser.response.location
      assert_predicate enrollment.session.reload.revoked_at, :present?
    end
  end
end
