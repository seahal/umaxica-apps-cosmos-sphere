# frozen_string_literal: true

require_relative "config_values_origin_value"
require_relative "config_values_host_family_values"
require_relative "config_values_jump_gateway_values"

module AppConfigLoader
  module_function

  def load!(env: ENV, rails_env: Rails.env)
    production = rails_env.production?
    hosts = ConfigValues::HostFamilyValues.build(env: env, production: production)
    jump = ConfigValues::JumpGatewayValues.build(env: env)

    {
      hosts: hosts,
      jump: jump,
    }.freeze
  end
end
