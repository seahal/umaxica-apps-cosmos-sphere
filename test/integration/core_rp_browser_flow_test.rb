# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpBrowserFlowTest < ActionDispatch::IntegrationTest
  test "Core app and org expose only their host-owned callback and passive sign entry" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["PUBLIC_CORE_SERVICE_URL", "core/app/oidc/callbacks"],
      ["PUBLIC_CORE_STAFF_URL", "core/org/oidc/callbacks"],
    ].each do |host_setting, controller|
      host = ENV.fetch(host_setting)
      route = Rails.application.routes.recognize_path("https://#{host}/oidc/callback", method: :get)

      assert_equal controller, route.fetch(:controller)
      browser = open_session
      browser.host!(host)
      browser.https!
      OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("passive entry must not exchange a code") }) do
        browser.get("/sign", params: { ri: "jp" })
      end

      assert_equal 200, browser.response.status
      assert_nil browser.response.location
      assert_includes browser.response.body, 'name="authenticity_token"'
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end

  test "Core POST sign creates an Access authorization request with state nonce and PKCE" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["PUBLIC_CORE_SERVICE_URL", "core-app-jp"],
      ["PUBLIC_CORE_STAFF_URL", "core-org-jp"],
    ].each do |host_setting, client_id|
      host = ENV.fetch(host_setting)
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.get("/sign", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      token = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/sign", params: { ri: "jp", target_link_uri: "/", authenticity_token: token }, headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => token,
        },
      )

      assert_equal 303, browser.response.status
      uri = URI.parse(browser.response.location)
      query = Rack::Utils.parse_nested_query(uri.query)
      if query.key?("rt")
        jump_payload, = JWT.decode(query.fetch("rt"), nil, false)
        uri = URI.parse(jump_payload.fetch("url"))
        query = Rack::Utils.parse_nested_query(uri.query)
      end

      assert_equal "/oauth/authorize", uri.path
      assert_equal client_id, query.fetch("client_id")
      assert_equal "S256", query.fetch("code_challenge_method")
      assert_predicate query.fetch("state"), :present?
      assert_predicate query.fetch("nonce"), :present?
      assert_predicate query.fetch("code_challenge"), :present?
      assert_equal host, URI.parse(query.fetch("redirect_uri")).host
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end
end
