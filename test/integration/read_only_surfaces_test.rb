# frozen_string_literal: true

require "test_helper"

class ReadOnlySurfacesTest < ActionDispatch::IntegrationTest
  test "Core Warp and Palm retain public root routes" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [hosts.core_service.host, hosts.core_staff.host, hosts.warp_service.host,
     hosts.warp_staff.host, hosts.palm_service.host,].each do |host|
      host! host
      get "/"

      if response.redirect?
        location = URI.parse(response.location)

        assert_equal host, location.host
        assert_equal "/", location.path
        follow_redirect!
      end

      assert_response :success, "Sphere root must remain public on #{host}"
    end
  end
end
