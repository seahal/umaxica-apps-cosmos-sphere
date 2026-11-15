# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTwoBrowserRefreshRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "safe browser navigation installs verified refresh output and distinguishes refusals from dependencies" do
    [[:success, 200], [:refused, 404], [:indeterminate, 404], [:dependency, 503],
     [:invalid_remote, 503],].each do |outcome, status|
      browser = open_session
      browser.host!(ENV.fetch("PUBLIC_WARP_STAFF_URL"))
      browser.https!
      cell = RpCellBinding.fetch("rp_warp_org")
      issuer = OidcIssuer.for_resource_type("operator")
      sid = "browser-refresh-#{outcome}"
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "browser-refresh-#{outcome}", sid:, absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      refresh = "#{sid}.external-secret"
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "browser-refresh-#{outcome}",
        "sid" => sid,
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "browser-access-#{outcome}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      access = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      tokens = {
        access_token: access,
        refresh_token: "#{sid}.rotated-secret",
        expires_in: 300,
        refresh_token_expires_in: 600,
        token_type: "Bearer",
      }
      remote = OidcOpTokenClient::Result.new(
        outcome:, token_response: (outcome == :success) ? tokens : nil,
        error: (outcome == :success) ? nil : "protocol_refusal",
      )
      jwks = OidcOpJwksClient.for_resource_type("operator")
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        OidcOpTokenClient.stub(:refresh, remote) { browser.get("/dashboard", params: { ri: "jp" }) }
      end

      assert_equal status, browser.response.status, outcome
      assert_includes browser.response.headers.fetch("Cache-Control"), "no-store"
      assert_nil enrollment.session.reload.revoked_at
      if outcome == :success
        assert_equal 1, enrollment.session.installed_generation
        assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_equal "#{sid}.rotated-secret", browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
        controller = browser.request.controller_instance

        assert_equal enrollment.session, controller.current_session
        assert_equal enrollment.session.public_id, controller.current_session_public_id
        assert_equal enrollment.session.public_id, controller.browser_rp_session_public_id
        assert_predicate controller, :browser_rp_controller?
        assert_predicate controller, :browser_rp_authenticated?
        assert_not controller.authentication_credentials_invalid?
      elsif %i(refused indeterminate).include?(outcome)
        assert_equal 0, enrollment.session.installed_generation
        assert_predicate browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
        assert_predicate browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE], :blank?
        assert_predicate browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
      else
        assert_equal 0, enrollment.session.installed_generation
        assert_equal refresh, browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
        assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      end
    end
  end

  test "a writer failure during browser refresh returns unavailable and preserves opaque credentials" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "local-session"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "external-session.opaque"
    RpCoreAppRecord.stub(:connected_to, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
      get "/", params: { ri: "jp" }
    end

    assert_response :service_unavailable
    assert_equal "external-session.opaque", cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_equal "local-session", cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
  end

  test "class-level authentication policy guard rejects a forbidden skip without changing callbacks" do
    assert_raises(BrowserRpAuthentication::SkipNotAllowedError) do
      Core::App::ApplicationController.skip_before_action([:enforce_access_policy!])
    end
    assert_raises(BrowserRpAuthentication::SkipNotAllowedError) do
      Core::App::ApplicationController.skip_before_action({ only: :index }, :enforce_access_policy!)
    end
    assert_raises(BrowserRpAuthentication::InvalidPolicyError) do
      Core::App::ApplicationController.declare_authentication_mode!(:unsupported)
    end
    assert_equal Core::App::ApplicationController.authentication_mode_rules,
                 Core::App::ApplicationController.local_authentication_mode_rules
  end
end
