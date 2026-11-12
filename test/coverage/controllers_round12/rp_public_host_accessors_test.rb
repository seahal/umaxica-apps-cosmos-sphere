# frozen_string_literal: true

require "test_helper"

class RpPublicHostAccessorsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public RP controllers expose their configured authentication and authority hosts" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    cases = [
      [Core::App::ApplicationController, ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), hosts.visa_service.host],
      [Core::Org::ApplicationController, ENV.fetch("PRIVATE_AUTH_STAFF_URL"), hosts.visa_staff.host],
      [Palm::App::ApplicationController, ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), hosts.visa_service.host],
      [Warp::App::ApplicationController, ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), hosts.visa_service.host],
      [Warp::Org::ApplicationController, ENV.fetch("PRIVATE_AUTH_STAFF_URL"), hosts.visa_staff.host],
    ]

    cases.each do |controller_class, sign_host, authority_host|
      controller = controller_class.new

      assert_equal sign_host, controller.oidc_sign_host, controller_class.name
      assert_equal authority_host, controller.oidc_acme_host, controller_class.name
    end
  end
end
