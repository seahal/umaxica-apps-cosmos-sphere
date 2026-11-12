# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundFiveBrowserCsrfRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "missing empty or malformed CSRF proof fails after Origin admission but before refresh" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [nil, "", "malformed-csrf-proof"].each do |proof|
      browser = open_session
      host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      browser.host!(host)
      browser.https!
      browser.get("/sign", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      assert Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "csrf-independent.opaque"
      # Explicit absence bypasses the harness's automatic modern-browser header, so Rails
      # exercises its accepted legacy-token fallback rather than modern same-origin proof.
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => nil }
      headers["X-CSRF-Token"] = proof unless proof.nil?
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("invalid CSRF cannot consume refresh authority") }) do
        browser.post("/sign", params: { ri: "jp" }, headers:)
      end

      assert_equal 422, browser.response.status
      assert_equal "no-store", browser.response.headers["Cache-Control"]
      assert_equal "csrf-independent.opaque", browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      assert_nil browser.response.location
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
