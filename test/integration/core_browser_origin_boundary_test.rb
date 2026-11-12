# frozen_string_literal: true

require "test_helper"

class CoreBrowserOriginBoundaryTest < ActionDispatch::IntegrationTest
  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
  end

  test "app and org reject missing Origin with sibling-site metadata despite valid csrf" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Sec-Fetch-Site" => "same-site",
      }

      assert_response :forbidden
      assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
    end
  end

  test "exact same Origin keeps the existing explicit POST refresh refusal contract" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://#{ENV.fetch(setting)}",
        "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :unauthorized
      assert_equal "application/problem+json", response.media_type
    end
  end

  test "every surface rejects foreign malformed null and mismatched Origins before refresh" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      hostname = ENV.fetch(setting)
      host! hostname
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")
      ["https://sibling.#{hostname}", "https://untrusted.example", "http://#{hostname}",
       "https://#{hostname}:444", "null", "invalid-origin",].each do |origin|
        post "/api/v0/token/refresh", headers: {
          "Accept" => "application/json",
          "X-CSRF-Token" => csrf,
          "Origin" => origin,
          "Sec-Fetch-Site" => "same-origin",
        }

        assert_response :forbidden
        assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
      end
    end
  end

  test "same Origin contradicting cross-site metadata is refused on every surface" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      hostname = ENV.fetch(setting)
      host! hostname
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://#{hostname}",
        "Sec-Fetch-Site" => "cross-site",
      }

      assert_response :forbidden
      assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
    end
  end

  test "Origin rejection precedes changes to real app and org refresh credentials" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |setting|
      host! ENV.fetch(setting)
      https!
      get "/api/v0/session", headers: { "Accept" => "application/json" }

      assert_response :success
      csrf = response.parsed_body.fetch("csrf_token")
      cell = RpCellBinding.fetch((setting == "PUBLIC_CORE_SERVICE_URL") ? "rp_core_app" : "rp_core_org")
      enrollment = RpCallbackCommitter.call(
        cell:, issuer: OidcIssuer.for_resource_type((setting == "PUBLIC_CORE_SERVICE_URL") ? "client" : "operator"),
        subject: "origin-subject", sid: "origin-#{cell.connection}", absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      rp = enrollment.session
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp.public_id
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "external-session.external-secret"
      original_generation = rp.installed_generation
      original_expiry = rp.absolute_expires_at

      post "/api/v0/token/refresh", headers: {
        "Accept" => "application/json",
        "X-CSRF-Token" => csrf,
        "Origin" => "https://untrusted.example",
        "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :forbidden
      rp.reload

      assert_equal original_generation, rp.installed_generation
      assert_equal original_expiry, rp.absolute_expires_at
      assert_nil rp.revoked_at
    end
  end
end
