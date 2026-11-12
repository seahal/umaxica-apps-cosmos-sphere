# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationErrorTest < ActiveSupport::TestCase
  test "ApplicationError stores status code, context, and translated message" do
    error = ApplicationError.new("errors.messages.login_required", :unauthorized, resource: "client")

    assert_equal :unauthorized, error.status_code
    assert_equal({ resource: "client" }, error.context)
    assert_predicate error.message, :present?
  end

  test "ApplicationError uses raw non-ascii messages without translation" do
    error = ApplicationError.new("こんにちは", :bad_request)

    assert_equal "こんにちは", error.message
  end
end
