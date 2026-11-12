# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "confirmation is a nonmutating page and has no successful completion notice" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    get edit_core_app_sign_out_path(ri: "jp")

    assert_response :success
    assert_not_includes response.headers.to_h, "Clear-Site-Data"
    assert_includes response.body, "core/app/sign/outs/edit"

    get core_app_sign_out_path(ri: "jp")

    assert_response :not_found
  end

  test "uncredentialed logout fails before any Access revocation" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    get edit_core_app_sign_out_path(ri: "jp")

    assert_response :success
    # Rails owns this page's CSRF token; Access is an external dependency and must not be called.
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    OidcOpRevocationClient.stub(:revoke, ->(**) { flunk("no local session can authorize revocation") }) do
      post core_app_sign_out_path(ri: "jp"), headers: {
        "Origin" => "https://#{ENV.fetch("PUBLIC_CORE_SERVICE_URL")}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => token.to_s,
      }
    end

    assert_response :unauthorized
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
  end
end
