# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerLocalLogoutRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "local logout revokes only the authenticated RP session and completion consumes its bound notice once" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      %w(rp_core_app PUBLIC_CORE_SERVICE_URL client),
      %w(rp_core_org PUBLIC_CORE_STAFF_URL operator),
      %w(rp_warp_app PUBLIC_WARP_SERVICE_URL client),
      %w(rp_warp_org PUBLIC_WARP_STAFF_URL operator),
      %w(rp_palm_app PUBLIC_PALM_SERVICE_URL client),
    ].each do |connection, host_setting, resource_type|
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      sid = "logout-#{connection}"
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "logout-subject", sid:, absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      browser = open_session
      host = ENV.fetch(host_setting)
      browser.host!(host)
      browser.https!
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "logout-subject",
        "sid" => sid,
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "logout-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "#{sid}.external-secret"
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      revocations = []
      jwks.stub(:lookup, lookup) do
        browser.get("/sign/out/new", params: { ri: "jp" })

        assert_equal 303, browser.response.status
        assert_equal "/sign/out/edit", URI.parse(browser.response.location).path
        browser.follow_redirect!

        assert_equal 200, browser.response.status
        assert_nil enrollment.session.reload.revoked_at
        csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
        OidcOpRevocationClient.stub(
          :revoke, ->(**arguments) {
                     revocations << arguments
                     OidcOpRevocationClient::Result.new(outcome: :success)
                   },
        ) do
          browser.post(
            "/sign/out", params: { ri: "jp" }, headers: {
              "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
            },
          )
        end
      end

      assert_equal 303, browser.response.status
      assert_predicate enrollment.session.reload.revoked_at, :present?
      assert_equal [{ client_id: cell.client_id, resource_type:, token: "#{sid}.external-secret" }], revocations
      assert_predicate browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
      assert_predicate browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
      assert_predicate browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE], :blank?
      handoff = URI.parse(browser.response.location)
      query = Rack::Utils.parse_nested_query(handoff.query)

      assert_equal cell.client_id, query.fetch("client_id")
      assert_not query.key?("id_token_hint")
      assert_equal URI.parse(OidcIssuer.end_session_endpoint(resource_type)).host, handoff.host
      completion = URI.parse(query.fetch("post_logout_redirect_uri"))

      assert_equal host, completion.host
      assert_equal "/sign/out/completion", completion.path
      browser.get(completion.path, params: { ri: "jp", state: "wrong-state" })

      assert_equal 404, browser.response.status
      browser.get(completion.path, params: { ri: "jp", state: query.fetch("state") })
      if %w(rp_warp_app rp_warp_org).include?(connection)
        assert_equal 303, browser.response.status
        assert_equal "/", URI.parse(browser.response.location).path
        browser.follow_redirect!

        assert_equal 200, browser.response.status
      else
        assert_equal 200, browser.response.status
        assert_equal '"cache", "storage"', browser.response.headers["Clear-Site-Data"]
        page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css('script[data-page="app"]').text)
        component = {
          "rp_core_app" => "core/app/sign/outs/complete",
          "rp_core_org" => "core/org/sign/outs/complete",
          "rp_palm_app" => "palm/app/sign/out/completions/complete",
        }.fetch(connection)

        assert_equal component, page.fetch("component")
        assert_equal I18n.t("sign.shared.sign_out.completed_description"), page.fetch("props").fetch("description")
        assert_equal "/?ri=jp", page.fetch("props").fetch("home_link").fetch("href")
      end
      browser.get(completion.path, params: { ri: "jp", state: query.fetch("state") })

      assert_equal 404, browser.response.status
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end
  test "only a bound refresh cookie is revoked and remote outages never restore the local session" do
    [nil, "", "malformed", ".secret", "bound.", "unrelated.secret", "bound.secret"].each_with_index do |refresh, index|
      sid = "bound-#{index}"
      refresh = refresh.sub("bound", sid) unless refresh.nil?
      cell = RpCellBinding.fetch("rp_core_org")
      issuer = OidcIssuer.for_resource_type("operator")
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "refresh-contract-#{index}", sid:, absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      browser = open_session
      host = ENV.fetch("PUBLIC_CORE_STAFF_URL")
      browser.host!(host)
      browser.https!
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "refresh-contract-#{index}",
        "sid" => sid,
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "refresh-access-#{index}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh unless refresh.nil?
      jwks = OidcOpJwksClient.for_resource_type("operator")
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      revocations = []
      jwks.stub(:lookup, lookup) do
        OidcOpRevocationClient.stub(
          :revoke, ->(**arguments) {
                     revocations << arguments
                     OidcOpRevocationClient::Result.new(outcome: :endpoint_unavailable)
                   },
        ) do
          browser.post(
            "/sign/out", params: { ri: "jp" }, headers: {
              "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end

      assert_equal 303, browser.response.status
      assert_predicate enrollment.session.reload.revoked_at, :present?
      assert_equal((index == 6) ? 1 : 0, revocations.size)
      assert_predicate browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
      assert_predicate browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE], :blank?
    end
  end
end
