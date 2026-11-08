# frozen_string_literal: true

require "test_helper"

class OtpIssueResultInspectionTest < ActiveSupport::TestCase
  test "OTP issue result diagnostics redact the issued code" do
    [EmailSignUpOtpIssueResult, TelephoneSignUpOtpIssueResult].each do |result_class|
      secret_code = "one-time-secret"
      result = result_class.new(status: :issued, transaction: nil, code: secret_code)
      diagnostic = result.inspect

      assert_predicate result, :success?
      assert_includes diagnostic, "proof=[FILTERED]"
      assert_not_includes diagnostic, secret_code
      assert_not_predicate result_class.new(status: :refused, transaction: nil, code: nil), :success?
    end
  end
end
