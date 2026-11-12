# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch34MassReturnsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JumpRtReturnPolicy normalize_origin rejection arms" do
    assert_nil JumpRtReturnPolicy.normalize_origin("ftp://x")
    assert_nil JumpRtReturnPolicy.normalize_origin("not a uri")
    assert_nil JumpRtReturnPolicy.normalize_origin("http://user:pass@example.test")
    assert_nil JumpRtReturnPolicy.normalize_origin("")
    assert_kind_of String, JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app")
  end

  test "LocalEnvironment load fallbacks with missing UMAXICA_ENV_FILE" do
    assert_nil LocalEnvironment.parse("# comment")[0]
    assert_nil LocalEnvironment.parse("")[0]
    assert_equal %w(FOO bar), LocalEnvironment.parse("FOO=bar")
  end
end
