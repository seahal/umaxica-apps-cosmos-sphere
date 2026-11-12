# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTwelveNeutralRecoveryRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "neutral sign and interruption pages detach refused credentials before rendering generic HTML" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each do |setting|
      %w(/sign /sign/interruption).each do |path|
        browser = open_session
        browser.host!(ENV.fetch(setting))
        browser.https!
        browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed"
        browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "unknown-session"
        browser.get(path, params: { ri: "jp" }, headers: { "Accept" => "text/html" })

        assert_equal 200, browser.response.status
        assert_equal "no-store", browser.response.headers["Cache-Control"]
        assert_nil browser.response.location
        assert_predicate browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
        assert_predicate browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
        document = Nokogiri::HTML(browser.response.body)

        assert document.at_css("h1")
        assert_not_includes browser.response.body, "unknown-session"
        assert_not_includes browser.response.body, "malformed"
      end
    end
  end
end
