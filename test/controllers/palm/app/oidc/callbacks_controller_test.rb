# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::Oidc::CallbacksControllerTest < ActionDispatch::IntegrationTest
  test "callback rejects missing browser state before token exchange" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    https!
    OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("state rejection must precede exchange") }) do
      get palm_app_oidc_callback_path, params: { code: "untrusted-code" }
    end

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
  end
end
