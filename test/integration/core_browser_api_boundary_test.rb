# frozen_string_literal: true

require "test_helper"

class CoreBrowserApiBoundaryTest < ActionDispatch::IntegrationTest
  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
  end

  teardown do
    @previous_flag.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] =
                                                                            @previous_flag
    Actor.clear
  end

  test "core browser api refuses an explicitly disabled feature flag" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "0"

    get("/api/v0/session", headers: { "Accept" => "application/json" })

    assert_response :service_unavailable
    body = response.parsed_body

    assert_equal "urn:umaxica:problem:service-unavailable", body.fetch("type")
    assert_predicate body.fetch("request_id"), :present?
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  test "a disabled boundary answers with an RFC 9457 problem document" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "0"

    get("/api/v0/session", headers: { "Accept" => "application/json" })

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type

    body = response.parsed_body

    assert_equal "urn:umaxica:problem:service-unavailable", body.fetch("type")
    assert_equal response.status, body.fetch("status")
    assert_equal "/api/v0/session", body.fetch("instance")
    assert_predicate body.fetch("request_id"), :present?
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  test "a csrf failure answers with the csrf-verification-failed problem type" do
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "opaque-refresh-token"

    post "/api/v0/token/refresh", headers: { "Accept" => "application/json" }

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type

    body = response.parsed_body

    assert_equal "urn:umaxica:problem:csrf-verification-failed", body.fetch("type")
    assert_equal response.status, body.fetch("status")
  end

  test "an oversized JSON request is rejected before API authentication and parameter parsing" do
    body = "x" * (RequestBodySizeLimit::MAX_JSON_BODY_BYTES + 1)

    post "/api/v0/token/refresh",
         params: body,
         headers: { "Accept" => "application/json" }.merge(
           "CONTENT_TYPE" => "application/json",
           "CONTENT_LENGTH" => body.bytesize.to_s,
         )

    assert_response :content_too_large
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:content-too-large", response.parsed_body.fetch("type")
  end

  test "no transitional error member remains in the problem document" do
    get(
      "/api/v0/session",
      headers: { "Accept" => "application/json" }.merge("Authorization" => "Bearer presented-access-token"),
    )

    assert_response :unauthorized

    body = response.parsed_body

    assert_equal "urn:umaxica:problem:authentication-required", body.fetch("type")
    assert_not body.key?("error"), "the transitional error member is gone"
    assert_equal %w(instance request_id status title type), body.keys.sort
  end

  test "every response on this boundary is uncacheable" do
    get("/api/v0/session", headers: { "Accept" => "application/json" })

    assert_response :success
    # The body carries a CSRF token and per-subject state; a shared cache must never hold it.
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "an error response on this boundary is uncacheable too" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "0"

    get("/api/v0/session", headers: { "Accept" => "application/json" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  test "a request without an Accept header is still served by the JSON session endpoint" do
    get "/api/v0/session", headers: {}

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_not response.parsed_body.fetch("authenticated")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "a JSON body passes media-type negotiation before the CSRF boundary refuses the refresh" do
    post "/api/v0/token/refresh", params: "{}", headers: {
      "Accept" => "application/json", "CONTENT_TYPE" => "application/json", "CONTENT_LENGTH" => "2",
    }

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
  end

  test "an unknown path under the api namespace answers with a problem document, not html" do
    previous = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    get("/api/v0/no-such-endpoint", headers: { "Accept" => "application/json" })

    assert_response :not_found
    assert_equal "application/problem+json", response.media_type

    body = response.parsed_body

    assert_equal "urn:umaxica:problem:not-found", body.fetch("type")
    assert_equal 404, body.fetch("status")
    assert_equal "/api/v0/no-such-endpoint", body.fetch("instance")
    assert_not_includes response.body, "<html"
  ensure
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = previous
  end

  test "an unknown path outside the api namespace still gets the html page" do
    previous = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    get("/no-such-page", headers: { "Accept" => "text/html" })

    assert_response :not_found
    assert_equal "text/html", response.media_type
  ensure
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = previous
  end

  test "unauthenticated session response returns csrf token and no credentials" do
    get "/api/v0/session", headers: { "Accept" => "application/json" }

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_not_includes response.body, OidcRpBrowserCredentialContract::ACCESS_COOKIE
    assert_not_includes response.body, OidcRpBrowserCredentialContract::REFRESH_COOKIE
  end

  test "core-browser access token is rejected from authorization header transport" do
    access_token = "presented-access-token"

    get "/api/v0/session",
        headers: { "Accept" => "application/json" }.merge("Authorization" => "Bearer #{access_token}")

    assert_response :unauthorized
    body = response.parsed_body

    assert_equal "urn:umaxica:problem:authentication-required", body.fetch("type")
    assert_predicate body.fetch("request_id"), :present?
  end

  test "unsafe refresh without csrf returns json csrf error contract" do
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "opaque-refresh-token"

    post "/api/v0/token/refresh", headers: { "Accept" => "application/json" }

    assert_response :forbidden
    body = response.parsed_body

    assert_equal "urn:umaxica:problem:csrf-verification-failed", body.fetch("type")
    assert_predicate body.fetch("request_id"), :present?
    assert_not body.key?("detail")
  end

  test "refresh rejects authorization header transport even when refresh cookie is present" do
    get "/api/v0/session", headers: { "Accept" => "application/json" }
    csrf_token = response.parsed_body.fetch("csrf_token")
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "opaque-refresh-token"

    post "/api/v0/token/refresh",
         headers: { "Accept" => "application/json" }.merge(
           "X-CSRF-Token" => csrf_token,
           "Origin" => "https://#{ENV.fetch("PUBLIC_CORE_SERVICE_URL")}",
           "Authorization" => "Bearer presented-access-token",
         )

    assert_response :unauthorized
    body = response.parsed_body

    assert_equal "urn:umaxica:problem:authentication-required", body.fetch("type")
  end
end
