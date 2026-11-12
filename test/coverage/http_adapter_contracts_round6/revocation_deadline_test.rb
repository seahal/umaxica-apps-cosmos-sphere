# frozen_string_literal: true

require "test_helper"

class HttpAdapterContractsRound6RevocationDeadlineTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a depleted total budget rejects revocation before issuing an assertion" do
    readings = [0.0, 2.0]
    clock = ->(*) { readings.shift }
    result =
      Process.stub(:clock_gettime, clock) do
        OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque-refresh")
      end

    assert_equal :timeout, result.outcome
    assert_empty readings
  end

  test "assertion generation cannot extend the total revocation budget" do
    now = 0.0
    clock = ->(*) { now }
    issue =
      lambda do |**|
        now = 2.0
        "client-assertion"
      end
    result =
      Process.stub(:clock_gettime, clock) do
        OidcClientAssertionJwt.stub(:issue, issue) do
          OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque-refresh")
        end
      end

    assert_equal :timeout, result.outcome
  end

  test "a successful HTTP response arriving at the total deadline is still a timeout" do
    now = 0.0
    clock = ->(*) { now }
    connection = Faraday.new
    requests = []
    request =
      lambda do |uri, body|
        requests << [uri, body]
        now = 2.0
        Faraday::Response.new(status: 200, body: "")
      end
    result =
      Process.stub(:clock_gettime, clock) do
        OidcClientAssertionJwt.stub(:issue, "client-assertion") do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:post, request) do
              OidcOpRevocationClient.revoke(
                client_id: "core-app-jp", resource_type: "client",
                token: "opaque-refresh",
              )
            end
          end
        end
      end

    assert_equal :timeout, result.outcome
    assert_equal 1, requests.length
    assert_equal "opaque-refresh", requests.fetch(0).fetch(1).fetch(:token)
  end

  test "connection setup exhausting the total budget cannot send the refresh token" do
    now = 0.0
    clock = ->(*) { now }
    builds = []
    build =
      lambda do |**options|
        builds << options
        now = 2.0
        Minitest::Mock.new
      end
    result =
      Process.stub(:clock_gettime, clock) do
        OidcClientAssertionJwt.stub(:issue, "client-assertion") do
          OutboundHttp::Connection.stub(:build, build) do
            OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque-refresh")
          end
        end
      end

    assert_equal :network_unavailable, result.outcome
    assert_equal 1, builds.length
  end
end
