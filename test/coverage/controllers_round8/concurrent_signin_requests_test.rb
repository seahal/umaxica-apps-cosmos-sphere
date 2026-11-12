# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundEightConcurrentSigninRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "a newer sign-in replaces the earlier tab while rejected old callbacks preserve the current flow" do
    [
      %w(PUBLIC_CORE_SERVICE_URL client),
      %w(PUBLIC_CORE_STAFF_URL operator),
      %w(PUBLIC_WARP_SERVICE_URL client),
      %w(PUBLIC_WARP_STAFF_URL operator),
      %w(PUBLIC_PALM_SERVICE_URL client),
    ].each do |setting, resource_type|
      browser = open_session
      surface_host = ENV.fetch(setting)
      browser.host!(surface_host)
      browser.https!
      states = []
      2.times do
        browser.post(
          "/sign", params: { ri: "jp" },
                   headers: { "Origin" => "https://#{surface_host}", "Sec-Fetch-Site" => "same-origin" },
        )

        assert_equal 303, browser.response.status
        authorization = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query)
        if authorization.key?("rt")
          handoff, = JWT.decode(authorization.fetch("rt"), nil, false)
          authorization = Rack::Utils.parse_nested_query(URI.parse(handoff.fetch("url")).query)
        end
        states << authorization.fetch("state")
      end

      assert_not_equal states.first, states.last
      [states.first, states.last].each_with_index do |state, index|
        browser.get(
          "/oidc/callback", params: {
            state: state, iss: OidcIssuer.for_resource_type(resource_type), error: "login_required",
          },
        )

        assert_equal 303, browser.response.status
        assert_equal(index.zero? ? "/sign/interruption" : "/sign", URI.parse(browser.response.location).path)
        assert_equal "no-store", browser.response.headers["Cache-Control"]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      end

      browser.get(
        "/oidc/callback", params: {
          state: states.last, iss: OidcIssuer.for_resource_type(resource_type), error: "login_required",
        },
      )

      assert_equal 303, browser.response.status
      assert_equal "/sign/interruption", URI.parse(browser.response.location).path
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end
end
