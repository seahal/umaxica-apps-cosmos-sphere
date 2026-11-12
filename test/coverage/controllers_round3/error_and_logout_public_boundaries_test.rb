# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundThreeErrorAndLogoutPublicBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "registered application error handling preserves explicit JSON and bodyless response status" do
    ["application/json", "text/plain"].each do |accept|
      controller = Core::App::ApplicationController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("HTTP_ACCEPT", accept)
      response = ActionDispatch::TestResponse.new
      response.request = request
      controller.set_request!(request)
      controller.set_response!(response)
      error = ApplicationError.new("errors.messages.invalid_request", :unprocessable_content)
      handled = controller.rescue_with_handler(error)

      assert_same error, handled
      assert_equal 422, response.status
      if accept == "application/json"
        assert_equal({ "error" => I18n.t("errors.messages.invalid_request") }, JSON.parse(response.body))
        assert_equal "application/json", response.media_type
      else
        assert_empty response.body
      end

      assert_nil response.location
    end
  end

  test "the public authorization error renderer refuses JSON and HTML without exposing policy details" do
    ["application/json", "text/html"].each do |accept|
      controller = Warp::Org::ApplicationController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("HTTP_ACCEPT", accept)
      response = ActionDispatch::TestResponse.new
      response.request = request
      controller.set_request!(request)
      controller.set_response!(response)
      controller.handle_not_authorized

      assert_equal 403, response.status
      assert_nil response.location
      if accept == "application/json"
        assert_equal({ "error" => I18n.t("errors.forbidden") }, JSON.parse(response.body))
      else
        assert_empty response.body
      end
    end
  end

  test "registered CSRF response handling keeps JSON forbidden and reraises HTML violations" do
    ["application/json", "text/html"].each do |accept|
      controller = Core::Org::ApplicationController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("HTTP_ACCEPT", accept)
      response = ActionDispatch::TestResponse.new
      response.request = request
      controller.set_request!(request)
      controller.set_response!(response)
      violation = ActionController::InvalidCrossOriginRequest.new
      if accept == "application/json"
        assert_same violation, controller.rescue_with_handler(violation)
        assert_equal 403, response.status
        assert_equal({ "error" => I18n.t("errors.invalid_authenticity_token") }, JSON.parse(response.body))
      else
        assert_raises(ActionController::InvalidCrossOriginRequest) { controller.rescue_with_handler(violation) }
      end

      assert_nil response.location
    end
  end

  test "LogoutResult preserves success fields and never mistakes an absent status for success" do
    blank = LogoutResult.success

    assert_predicate blank, :success?
    assert_equal :ok, blank.response_status
    assert_nil blank.token
    assert_empty blank.revoked_tokens
    assert_nil blank.redirect_to
    assert_nil blank.message
    specified = LogoutResult.success(
      token: "opaque-fixture", revoked_tokens: ["revoked-fixture"],
      redirect_to: "/", message: "completed",
    )

    assert_predicate specified, :success?
    assert_equal "opaque-fixture", specified.token
    assert_equal ["revoked-fixture"], specified.revoked_tokens
    assert_equal "/", specified.redirect_to
    assert_equal "completed", specified.message
    missing_status = LogoutResult.new(
      status: nil, token: nil, revoked_tokens: [], redirect_to: nil,
      response_status: nil, message: nil,
    )

    assert_not missing_status.success?
  end
end
