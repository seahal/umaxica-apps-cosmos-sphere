# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundElevenPublicAdmissionRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "malformed JSON telemetry remains a bodyless non-authenticating CSP response on each surface" do
    [
      ENV.fetch("PUBLIC_CORE_SERVICE_URL"), ENV.fetch("PUBLIC_CORE_STAFF_URL"),
      ENV.fetch("PUBLIC_WARP_SERVICE_URL"), ENV.fetch("PUBLIC_WARP_STAFF_URL"),
      ENV.fetch("PUBLIC_PALM_SERVICE_URL"), "core.net.localhost", "core.dev.localhost",
    ].each do |surface_host|
      browser = open_session
      browser.host!(surface_host)
      browser.https!
      browser.post(
        "/csp-violation-report", params: "{",
                                 headers: { "CONTENT_TYPE" => "application/json", "Origin" => "null" },
      )

      assert_equal 204, browser.response.status
      assert_empty browser.response.body
      assert_nil browser.response.location
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end

  test "each remaining browser surface enforces its own public request quota without authenticating" do
    %w(PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each_with_index do |setting, index|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      headers = { "REMOTE_ADDR" => "192.0.2.#{210 + index}", "Accept" => "application/json" }
      travel_to Time.current.beginning_of_minute do
        299.times { browser.get("/", headers:) }

        assert_equal 200, browser.response.status
        browser.get("/", headers:)

        assert_equal 200, browser.response.status
        browser.get("/", headers:)

        assert_equal 429, browser.response.status
        assert_equal "60", browser.response.headers["Retry-After"]
        assert_equal "urn:umaxica:problem:rate-limited", browser.response.parsed_body.fetch("type")
        assert_nil browser.response.location
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      end
    end
  end
end
