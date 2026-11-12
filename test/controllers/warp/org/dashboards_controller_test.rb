# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous dashboard refuses access without starting an OIDC transaction" do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL")
    https!
    get warp_org_dashboard_path(ri: "jp")

    assert_response :not_found
    assert_nil response.location
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end
end
