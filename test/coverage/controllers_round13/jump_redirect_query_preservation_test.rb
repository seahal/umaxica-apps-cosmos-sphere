# frozen_string_literal: true

require "test_helper"

class ControllersRoundThirteenJumpRedirectQueryPreservationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only a registered callback survives the public OIDC authorization URL check" do
    client = OidcClientRegistry.find!("core-app-jp")
    callback = client.redirect_uris.fetch(0)
    authorize_uri = URI.parse(OidcIssuer.authorization_endpoint("client"))
    valid_url = authorize_uri.to_s + "?" + { client_id: client.client_id, redirect_uri: callback }.to_query
    controller = Core::App::ApplicationController.new

    assert_equal ["redirect_uri"], controller.safe_jump_preserved_query_keys(valid_url)
    assert_empty controller.safe_jump_preserved_query_keys("javascript:alert(1)")
    other_path = "#{authorize_uri.origin}/oauth/other?client_id=#{client.client_id}&redirect_uri=#{callback}"

    assert_empty controller.safe_jump_preserved_query_keys(other_path)
    untrusted_host = "https://untrusted.example/oauth/authorize?client_id=#{client.client_id}&redirect_uri=#{callback}"

    assert_empty controller.safe_jump_preserved_query_keys(untrusted_host)
    assert_empty controller.safe_jump_preserved_query_keys(
      authorize_uri.to_s + "?" + {
        client_id: client.client_id,
        redirect_uri: "https://unregistered.example/callback",
      }.to_query,
    )
    assert_empty controller.safe_jump_preserved_query_keys("https://[")
  end
end
