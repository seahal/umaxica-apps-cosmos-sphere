# frozen_string_literal: true

require "test_helper"

class ResolversAndAuthValuesRound5RedirectTargetPublicBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "malformed paths and conflicting nested queries fail closed with a digest instead of a redirect" do
    {
      "/path with space" => "invalid_uri",
      "/page\u0001" => "control_char",
      "/?a=1&a[b]=2" => "dangerous_query_key",
      "////external.example/path" => "protocol_relative",
      "//user@/path" => "userinfo",
      "/page#section" => "fragment",
      "?q=value" => "blank_path",
      "relative/path" => "relative_path",
      "/\\host" => "backslash",
      "/page%00" => "encoded_control_char",
    }.each do |path, reason|
      result = RedirectsPathTargetResolver.call(path, source: :runtime_boundary)

      assert_not_predicate result, :ok?
      assert_equal reason, result.failure_reason
      assert_equal :runtime_boundary, result.source
      assert_nil result.value
      assert_equal Digest::SHA256.hexdigest(path), result.unsafe_value_digest
    end
  end

  test "valid internal paths retain only their original path and query" do
    result = RedirectsPathTargetResolver.call("/dashboard?filter=active&tag[]=one", source: :runtime_boundary)

    assert_predicate result, :ok?
    assert_equal "/dashboard?filter=active&tag[]=one", result.value
    assert_equal :pt, result.kind
    assert_nil result.unsafe_value_digest
  end
end
