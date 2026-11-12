# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous dashboard refuses access without starting an OIDC transaction" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    https!
    get palm_app_dashboard_path(ri: "jp")

    assert_response :unauthorized
    assert_nil response.location
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end
end
