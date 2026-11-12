# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound8NeutralSsoEntryContractTest < ActionDispatch::IntegrationTest
  test "the neutral sign route carries only the server-selected OIDC ceremony parameters" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host = Rails.configuration.x.boot_config.fetch(:hosts).core_service.host
    host!(host)
    https!
    get("/sign", params: { ri: "jp", target_link_uri: "/dashboard" })

    assert_response :success
    csrf = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign", params: {
        ri: "jp", target_link_uri: "/dashboard", prompt: "create", max_age: "0", authenticity_token: csrf,
      }, headers: {
        "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
      },
    )

    assert_response :see_other
    gateway = URI.parse(response.location)
    gateway_query = Rack::Utils.parse_nested_query(gateway.query)
    handoff, = JWT.decode(gateway_query.fetch("rt"), nil, false)
    authorization = URI.parse(handoff.fetch("url"))
    query = Rack::Utils.parse_nested_query(authorization.query)

    assert_equal "/oauth/authorize", authorization.path
    assert_equal "core-app-jp", query.fetch("client_id")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_equal "jp", query.fetch("ri")
    assert_not query.key?("prompt")
    assert_not query.key?("max_age")
    state = OidcStateJwt.verify(client_id: "core-app-jp", token: query.fetch("state"))

    assert_predicate state, :valid?
    assert_equal "/dashboard", state.target_link_uri
    assert_predicate query.fetch("nonce"), :present?
    assert_predicate query.fetch("code_challenge"), :present?
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end
end
