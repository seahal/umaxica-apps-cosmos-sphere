# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutRenderedTitleSmokeTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "Sphere entry pages render their surface title" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    cases = [
      { host: hosts.core_service.host, path: "/", tld: "APP" },
      { host: hosts.core_staff.host, path: "/", tld: "ORG" },
      { host: hosts.warp_service.host, path: "/", tld: "APP" },
      { host: hosts.warp_staff.host, path: "/", tld: "ORG" },
      { host: hosts.palm_service.host, path: "/", tld: "APP" },
    ]

    cases.each do |entry|
      host! entry.fetch(:host)
      get entry.fetch(:path)

      if response.redirect?
        assert_predicate URI.parse(response.location).host, :present?
      else
        assert_response :success
        expected_title = "#{BRAND} (#{entry.fetch(:tld)})"

        assert_select "title", /#{Regexp.escape(expected_title)}\z/
      end
    end
  end
end
