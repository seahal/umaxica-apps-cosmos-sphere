# typed: false
# frozen_string_literal: true

require "test_helper"

# Closes the remaining method/branch gap after the feature merge:
# method floor needs ~8 more hits; branch floor needs ~128.
class BranchCoverageBatch38ThresholdPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJtiGenerator encoded_length remainder arms" do
    assert_equal 2, JitSecurityJwtJtiGenerator.encoded_length(1)
    assert_equal 3, JitSecurityJwtJtiGenerator.encoded_length(2)
    assert_equal 4, JitSecurityJwtJtiGenerator.encoded_length(3)
    assert_equal 0, JitSecurityJwtJtiGenerator.encoded_length(0)
  end
end
