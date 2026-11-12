# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch28ConcernEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ActorSupport exposes no canonical step-up accessor" do
    helper = Class.new(ApplicationController) { include ActorSupport }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:current_step_up, true)
  end

  test "SignErrorResponses null Origin classification" do
    helper = Class.new(ApplicationController) { include SignErrorResponses }.new
    request = ActionDispatch::TestRequest.create
    request.headers["Origin"] = "null"
    helper.set_request!(request)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:csrf_failure_reason, true)
    assert_not helper.respond_to?(:reject_csrf!, true)
  end
end
