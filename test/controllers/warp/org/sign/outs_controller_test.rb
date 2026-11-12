# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "confirmation is a nonmutating page and has no successful completion notice" do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL")
    https!
    get edit_warp_org_sign_out_path(ri: "jp")

    assert_response :success
    assert_not_includes response.headers.to_h, "Clear-Site-Data"
    assert_includes response.body, "warp/org/sign/outs/edit"

    get warp_org_sign_out_path(ri: "jp")

    assert_response :not_found
  end

  test "uncredentialed logout fails before any Access revocation" do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL")
    https!
    get edit_warp_org_sign_out_path(ri: "jp")

    assert_response :success
    # Rails owns this page's CSRF token; Access is an external dependency and must not be called.
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    OidcOpRevocationClient.stub(:revoke, ->(**) { flunk("no local session can authorize revocation") }) do
      post warp_org_sign_out_path(ri: "jp"), headers: {
        "Origin" => "https://#{ENV.fetch("PUBLIC_WARP_STAFF_URL")}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => token.to_s,
      }
    end

    assert_response :unauthorized
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
  end
end
