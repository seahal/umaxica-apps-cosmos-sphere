# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::App::Oidc::CallbacksControllerTest < ActionController::TestCase
  tests Core::App::Oidc::CallbacksController

  test "a valid state without its pending PKCE verifier fails closed before code exchange" do
    @request.host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @request.env["HTTPS"] = "on"
    state, jti = OidcStateJwt.issue(client_id: "core-app-jp", target_link_uri: nil)
    session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY] = {
      jti => { "code_verifier" => "", "nonce" => "pending-nonce", "created_at" => Time.current.to_i },
    }

    OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("missing PKCE must prevent code exchange") }) do
      get :show, params: {
        state:, iss: OidcIssuer.for_resource_type("client"), code: "unexchangable-code",
      }
    end

    assert_response :see_other
    assert_equal "/sign/interruption", URI.parse(response.location).path
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
    assert_nil cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
  end
end
