# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreWebEdgeSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "Core does not route Governance preference reads or writes" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL).each do |host_setting|
      host = ENV.fetch(host_setting)
      %w(cookie theme).each do |resource|
        %i(get patch put).each do |method|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("https://#{host}/api/v0/preferences/#{resource}", method:)
          end
        end
      end
    end
  end
end
