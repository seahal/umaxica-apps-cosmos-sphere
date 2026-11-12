# frozen_string_literal: true

require "test_helper"

class WarpRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Warp app and org hosts retain roots dashboards and OIDC entry paths without preference resources" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    { hosts.warp_service.host => "app", hosts.warp_staff.host => "org" }.each do |host, surface|
      {
        "/" => ["roots", "index"],
        "/dashboard" => ["dashboards", "show"],
        "/sign" => ["sign/entries", "show"],
        "/oidc/callback" => ["oidc/callbacks", "show"],
      }.each do |path, (controller, action)|
        assert_equal(
          { controller: "warp/#{surface}/#{controller}", action: },
          Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)
            .slice(:controller, :action),
        )
      end
      %w(theme cookie).each do |resource|
        %i(get patch put).each do |method|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("https://#{host}/api/v0/preferences/#{resource}", method:)
          end
        end
      end

      %w(/sign/in /sign/callback /oidc/authorization).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)
        end
      end
    end
  end

  test "Warp corporate hosts expose no Warp routes" do
    %w(warp-jp.umaxica.com warp.com.localhost).each do |host|
      %w(/dashboard /sign /oidc/callback /api/v0/preferences/theme).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)
        end
      end
    end
  end
end
