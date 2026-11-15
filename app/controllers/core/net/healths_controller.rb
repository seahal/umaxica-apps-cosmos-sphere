# typed: false
# frozen_string_literal: true

module Core
  module Net
    class HealthsController < BareController
      include ::HealthCheckRendering

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::App
      before_action :disable_health_response_cache

      public

      def show
        render_snapshot(::Health::SnapshotCheck.call(profile: health_profile))
      end
    end
  end
end
