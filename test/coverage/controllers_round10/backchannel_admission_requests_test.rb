# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTenBackchannelAdmissionRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "each RP backchannel receiver bounds unauthenticated malformed traffic below at and above quota" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each_with_index do |setting, index|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      headers = { "REMOTE_ADDR" => "192.0.2.#{190 + index}" }
      travel_to Time.current.beginning_of_minute do
        59.times do
          browser.post("/oidc/closures", params: { logout_token: "malformed" }, headers:)
        end

        assert_equal 400, browser.response.status
        assert_equal "no-store", browser.response.headers["Cache-Control"]
        assert_empty browser.response.body
        browser.post("/oidc/closures", params: { logout_token: "malformed" }, headers:)

        assert_equal 400, browser.response.status
        assert_equal "no-store", browser.response.headers["Cache-Control"]
        browser.post("/oidc/closures", params: { logout_token: "malformed" }, headers:)

        assert_equal 429, browser.response.status
        assert_empty browser.response.body
        assert_nil browser.response.location
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      end
    end
  end
end
