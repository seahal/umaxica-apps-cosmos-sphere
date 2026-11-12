# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTwoRequestAdmissionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "unsafe RP admission rejects foreign Origin and contradictory Fetch Metadata before refreshing credentials" do
    [
      ["https://untrusted.example", "same-origin"], ["null", "same-origin"],
      ["https://#{ENV.fetch("PUBLIC_CORE_SERVICE_URL")}", "cross-site"],
    ].each do |origin, fetch_site|
      browser = open_session
      browser.host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
      browser.https!
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "external-session.opaque"
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("admission must precede refresh") }) do
        browser.post("/sign", params: { ri: "jp" }, headers: { "Origin" => origin, "Sec-Fetch-Site" => fetch_site })
      end

      assert_equal 422, browser.response.status
      assert_equal "no-store", browser.response.headers["Cache-Control"]
      assert_equal "external-session.opaque", browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      assert_nil browser.response.location
    end
  end

  test "the backchannel public Rack action refuses an unregistered host before touching signing keys" do
    environment = Rack::MockRequest.env_for(
      "https://unregistered.example/oidc/closures", {
        :method => "POST",
        :input => "logout_token=untrusted",
        "CONTENT_TYPE" => "application/x-www-form-urlencoded",
        "REMOTE_ADDR" => "192.0.2.89",
      },
    )
    OidcOpJwksClient.stub(:for_resource_type, ->(*) { flunk("host refusal must precede verifier construction") }) do
      status, _headers, body = Core::App::Oidc::ClosuresController.action(:create).call(environment)

      assert_equal 404, status
      assert_empty body.each.to_a.join
      body.close
    end
  end
end
