# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundThreeRootAndInterruptionRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "anonymous roots remain owned by their routed Inertia surface" do
    [
      ["PUBLIC_CORE_SERVICE_URL", "core/app", "Core App"],
      ["PUBLIC_CORE_STAFF_URL", "core/org", "Core Org"],
      ["PUBLIC_WARP_SERVICE_URL", "warp/app", "Warp App"],
      ["PUBLIC_WARP_STAFF_URL", "warp/org", "Warp Org"],
      ["PUBLIC_PALM_SERVICE_URL", "palm/app", "Palm App"],
    ].each do |setting, namespace, heading|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      browser.get("/", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      assert_nil browser.response.location
      page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css('script[data-page="app"]').text)

      assert_equal "#{namespace}/roots/index", page.fetch("component")
      assert_equal heading, page.fetch("props").fetch("heading")
      assert_predicate page.fetch("props").fetch("description"), :present?
      assert_equal namespace.split("/").last, page.fetch("props").fetch("chrome").fetch("surface")
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end

  test "Core network and developer roots keep their own plain and standalone representations" do
    browser = open_session
    browser.host!("core.net.localhost")
    browser.https!
    browser.get("/")

    assert_equal 200, browser.response.status
    assert_equal "text/plain", browser.response.media_type
    assert_equal "Core::Net::Roots#index", browser.response.body
    browser = open_session
    browser.host!("core.dev.localhost")
    browser.https!
    browser.get("/")

    assert_equal 200, browser.response.status
    assert_equal "Core Dev", Nokogiri::HTML(browser.response.body).at_css("h1").text
    assert_nil Nokogiri::HTML(browser.response.body).at_css('script[data-page="app"]')
  end

  test "authenticated Warp and Palm roots refuse JSON without redirecting or revoking the local session" do
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
        browser.get("/", params: { ri: "jp" }, headers: { "Accept" => "application/json" })
      end

      assert_equal 403, browser.response.status
      assert_equal({ "status" => 403, "error" => "Forbidden" }, browser.response.parsed_body)
      assert_equal "private, no-store", browser.response.headers["Cache-Control"]
      assert_nil browser.response.location
      assert_nil enrollment.session.reload.revoked_at
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end

  test "anonymous Warp dashboards publish the explicit JSON not-found boundary" do
    %w(PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL).each do |setting|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      browser.get("/dashboard", params: { ri: "jp" }, headers: { "Accept" => "application/json" })

      assert_equal 404, browser.response.status
      assert_equal({ "status" => 404, "error" => "Not Found" }, browser.response.parsed_body)
      assert_equal "private, no-store", browser.response.headers["Cache-Control"]
      assert_nil browser.response.location
    end
  end

  test "all five interruption pages remain generic passive entries without echoing the failure reason" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each do |setting|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      browser.get("/sign/interruption", params: { ri: "jp", reason: "private-diagnostic-fixture" })

      assert_equal 200, browser.response.status
      assert_equal "no-store", browser.response.headers["Cache-Control"]
      assert_nil browser.response.location
      assert_not_includes browser.response.body, "private-diagnostic-fixture"
      page = Nokogiri::HTML(browser.response.body)

      assert_equal I18n.t("oidc_rp.interruption.title"), page.at_css("h1").text
      assert page.at_css('a[href="/sign?ri=jp"]')
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end
end
