# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound7TokenEndpointPublicDeadlinesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "token exchange does not transmit after assertion generation exhausts its budget" do
    now = 0.0
    issue =
      lambda do |**|
        now = 2.0
        "assertion"
      end
    result =
      Process.stub(:clock_gettime, ->(*) { now }) do
        OidcClientAssertionJwt.stub(:issue, issue) do
          OidcOpTokenClient.refresh(
            client_id: "core-app-jp", token_url: "https://op.example/token",
            refresh_token: "opaque",
          )
        end
      end

    assert_equal :indeterminate, result.outcome
    assert_equal "timeout", result.error
    assert_nil result.token_response
  end

  test "connection setup cannot extend the token exchange deadline" do
    now = 0.0
    builds = []
    build =
      lambda do |**options|
        builds << options
        now = 2.0
        Minitest::Mock.new
      end
    result =
      Process.stub(:clock_gettime, ->(*) { now }) do
        OidcClientAssertionJwt.stub(:issue, "assertion") do
          OutboundHttp::Connection.stub(:build, build) do
            OidcOpTokenClient.refresh(
              client_id: "core-app-jp", token_url: "https://op.example/token",
              refresh_token: "opaque",
            )
          end
        end
      end

    assert_equal :indeterminate, result.outcome
    assert_equal "timeout", result.error
    assert_equal 1, builds.length
  end

  test "malformed token endpoints return the public invalid endpoint classification" do
    result =
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: "https://[bad", refresh_token: "opaque")
      end

    assert_equal :invalid_remote, result.outcome
    assert_equal "invalid_endpoint", result.error
    assert_nil result.token_response
  end

  test "a nonstandard successful HTTP status never becomes a successful token exchange" do
    connection = Faraday.new
    response = Faraday::Response.new(status: 201, body: JSON.generate(access_token: "opaque-access"))
    result =
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, response) do
            OidcOpTokenClient.refresh(
              client_id: "core-app-jp", token_url: "https://op.example/token",
              refresh_token: "opaque",
            )
          end
        end
      end

    assert_equal :invalid_remote, result.outcome
    assert_equal "unexpected_status", result.error
    assert_nil result.token_response
  end
end
