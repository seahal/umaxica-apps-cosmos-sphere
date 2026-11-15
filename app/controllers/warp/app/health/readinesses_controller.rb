# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Health
      class ReadinessesController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App
        before_action :disable_health_response_cache

        public

        def show
          render_probe(::Health::ReadinessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
