# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreBffSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "Core callbacks reject missing browser state and logout completion rejects a forged notice" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |host_setting|
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      browser.get("/oidc/callback")

      assert_equal 303, browser.response.status
      assert_equal "/sign/interruption", URI.parse(browser.response.location).path
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      browser.get("/sign/out", params: { state: "forged-state", ri: "jp" })

      assert_equal 404, browser.response.status
    end
  end
end
