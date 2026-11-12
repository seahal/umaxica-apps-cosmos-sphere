# typed: false
# frozen_string_literal: true

module Warp
  module App
    class SettingsController < Warp::App::ApplicationController
      include ::WarpSettingsPage

      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }
      # Reachable from the anonymous Warp landing, which links here before the visitor signs in.
      AUTHENTICATION_MODE = :open

      public

      def show
        render inertia: true, props: settings_page_props
      end
    end
  end
end
