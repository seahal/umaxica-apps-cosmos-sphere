# typed: false
# frozen_string_literal: true

module Core
  module Org
    class RootsController < Core::Org::ApplicationController
      include ::SurfaceInertiaPage

      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }
      AUTHENTICATION_MODE = :open

      public

      def index
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Core Org",
          description: t("landing.thin_endpoint"),
        }
      end
    end
  end
end
