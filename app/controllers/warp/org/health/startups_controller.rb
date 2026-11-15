# typed: false
# frozen_string_literal: true

module Warp
  module Org
    module Health
      class StartupsController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org
        before_action :disable_health_response_cache

        public

        def show
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
