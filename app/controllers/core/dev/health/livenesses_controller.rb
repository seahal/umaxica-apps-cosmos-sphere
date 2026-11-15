# typed: false
# frozen_string_literal: true

module Core
  module Dev
    module Health
      class LivenessesController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App
        before_action :disable_health_response_cache

        public

        def show
          render_probe(::Health::LivenessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
