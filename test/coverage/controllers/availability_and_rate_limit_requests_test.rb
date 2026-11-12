# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerAvailabilityAndRateLimitRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "unavailable host flags fail closed for HTML and JSON while health remains observable" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    FeatureFlags.stub(:enabled?, false) do
      get "/", headers: { "Accept" => "text/html" }

      assert_response :service_unavailable
      assert_equal "60", response.headers["Retry-After"]
      assert_nil response.location
      get "/", headers: { "Accept" => "application/json" }

      assert_response :service_unavailable
      assert_equal "fqdn_unavailable", response.parsed_body.fetch("error")
      assert_predicate response.parsed_body.fetch("surface"), :present?
      get "/health/liveness"

      assert_response :success
      assert_equal "ok\n", response.body
    end
  end

  test "an unavailable flag store never permits the public request" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    FeatureFlags.stub(:enabled?, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      get "/", headers: { "Accept" => "application/json" }
    end

    assert_response :service_unavailable
    assert_equal "fqdn_unavailable", response.parsed_body.fetch("error")
    assert_equal "60", response.headers["Retry-After"]
  end

  test "the public Rails Rack action refuses an unregistered host before consulting flags" do
    environment = Rack::MockRequest.env_for(
      "https://unregistered.example/", {
        "HTTP_ACCEPT" => "application/json", "REMOTE_ADDR" => "192.0.2.81",
      },
    )
    FeatureFlags.stub(:enabled?, ->(*) { flunk("an unknown host must not select a feature flag") }) do
      status, headers, body = Core::App::RootsController.action(:index).call(environment)
      content = JSON.parse(body.each.to_a.join)

      assert_equal 503, status
      assert_equal "60", headers.fetch("retry-after")
      assert_equal "unknown_fqdn", content.fetch("error")
      assert_not content.key?("surface")
      body.close
    end
  end

  test "surface rate limit accepts the nearest requests below and at quota and refuses the next" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    299.times do
      get "/", headers: { "REMOTE_ADDR" => "192.0.2.82", "Accept" => "application/json" }
    end

    assert_response :success
    get "/", headers: { "REMOTE_ADDR" => "192.0.2.82", "Accept" => "application/json" }

    assert_response :success
    get "/", headers: { "REMOTE_ADDR" => "192.0.2.82", "Accept" => "application/json" }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_equal '"default";r=0;t=60', response.headers["RateLimit"]
    assert_equal "urn:umaxica:problem:rate-limited", response.parsed_body.fetch("type")
    assert_nil response.headers["RateLimit-Policy"]
    get "/", headers: { "REMOTE_ADDR" => "192.0.2.82", "Accept" => "text/html" }

    assert_response :too_many_requests
    assert_equal "text/plain", response.media_type
    assert_equal "60", response.headers["Retry-After"]
  end
end
