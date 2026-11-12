# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RoutingEntrypointsTest < ActiveSupport::TestCase
  test "global routing entrypoints are loaded" do
    assert_nothing_raised { Rails.application.reload_routes! }

    routes = Rails.application.routes.routes
    route_names = routes.filter_map(&:name)
    retired_route_names = route_names.grep(
      /\A(?:auth|base|tech|visa|docs|news|help|info|guid|performance)_|\Aedit_(?:app|org|com)_/,
    )

    assert_empty retired_route_names
    %w(core_app core_org warp_app warp_org palm_app).each do |prefix|
      assert(route_names.any? { |name| name.start_with?("#{prefix}_") }, "missing route prefix: #{prefix}")
    end

    root_route = Rails.application.routes.recognize_path("https://unclaimed.invalid/")

    assert_equal "unknown_hosts", root_route[:controller]
    assert_equal "show", root_route[:action]
  end
end
