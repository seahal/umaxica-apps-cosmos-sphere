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

  test "a registered destination with unsafe query data cannot become an accepted navigation target" do
    result = RedirectsNavigationTargetResolver.call(
      :home, routes: Rails.application.routes.url_helpers,
             params: { ri: "\x00" },
    )

    assert_not_predicate result, :ok?
    assert_equal "invalid_registered_path", result.failure_reason
    assert_nil result.value
    assert_equal :nt, result.kind
  end

  test "the public registry preserves home and signed-out paths without resolving retired helpers" do
    home = RedirectsNavigationTargetResolver.call(
      "home", routes: Rails.application.routes.url_helpers,
              params: { "ri" => "jp" }, scope: :public,
    )
    signed_out = RedirectsNavigationTargetResolver.call(
      :signed_out, routes: Rails.application.routes.url_helpers,
                   scope: :public,
    )

    assert_equal "/?ri=jp", home.value
    assert_equal "/sign/out", signed_out.value
    assert_predicate home, :ok?
    assert_predicate signed_out, :ok?
    denied = RedirectsNavigationTargetResolver.call(
      :home, routes: Rails.application.routes.url_helpers,
             scope: :unknown,
    )

    assert_equal "scope_denied", denied.failure_reason
    assert_equal "app", RedirectsNavigationTargetResolver.surface({})
    assert_equal "org", RedirectsNavigationTargetResolver.surface(surface: "org")
  end
end
