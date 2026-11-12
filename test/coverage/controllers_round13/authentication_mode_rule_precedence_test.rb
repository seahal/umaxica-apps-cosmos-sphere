# frozen_string_literal: true

require "test_helper"

class BrowserRpAuthenticationModeRulePrecedenceController < Core::App::ApplicationController
  declare_authentication_mode! :private, except: :create
  declare_authentication_mode! :open, only: :show
end

class BrowserRpAuthenticationGuestBoundaryController < Core::App::ApplicationController
  declare_authentication_mode! :guest
end

class BrowserRpAuthenticationBareBoundaryController < Core::App::ApplicationController
  AUTHENTICATION_MODE = :bare
end

class ControllersRoundThirteenAuthenticationModeRulePrecedenceTest < ActiveSupport::TestCase
  test "public mode lookup honors only and except rules in reverse declaration order" do
    assert_equal :open, BrowserRpAuthenticationModeRulePrecedenceController.authentication_mode_for(:show)
    assert_equal :private, BrowserRpAuthenticationModeRulePrecedenceController.authentication_mode_for(:edit)
    assert_equal :deny_all, BrowserRpAuthenticationModeRulePrecedenceController.authentication_mode_for(:create)
  end

  test "deny by default raises until an action declares its authentication mode" do
    controller = Core::App::ApplicationController.new

    error =
      assert_raises(BrowserRpAuthentication::MissingPolicyError) do
        controller.enforce_access_policy!
      end

    assert_match("Denied by default authentication mode for Core::App::ApplicationController#", error.message)
  end

  test "guest mode admits a request with no valid RP credentials" do
    controller = BrowserRpAuthenticationGuestBoundaryController.new
    request = ActionDispatch::TestRequest.create
    controller.set_request!(request)
    framework_response = ActionDispatch::TestResponse.new
    framework_response.request = request
    controller.set_response!(framework_response)

    assert controller.enforce_access_policy!
    assert_equal 200, controller.response.status
    assert_empty controller.response.body
  end

  test "guest mode refuses a request with an authenticated RP session" do
    controller = BrowserRpAuthenticationGuestBoundaryController.new
    request = ActionDispatch::TestRequest.create
    controller.set_request!(request)
    framework_response = ActionDispatch::TestResponse.new
    framework_response.request = request
    controller.set_response!(framework_response)
    authenticated = RpRequestAuthenticator::Result.new(
      status: :authenticated, principal: nil, session: nil, payload: nil,
    )

    RpRequestAuthenticator.stub(:call, authenticated) do
      assert_not controller.enforce_access_policy!
    end

    assert_equal 403, controller.response.status
    assert_equal I18n.t("errors.messages.operation_not_permitted"), controller.response.body
    assert_equal "text/plain", controller.response.media_type
    assert_nil controller.response.location
  end

  test "bare mode never marks an HTML response as authenticated content" do
    controller = BrowserRpAuthenticationBareBoundaryController.new
    framework_response = ActionDispatch::TestResponse.new
    framework_response.content_type = "text/html"
    controller.set_response!(framework_response)

    assert_not controller.authenticated_page_response?
  end
end
