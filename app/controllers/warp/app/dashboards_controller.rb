# typed: false
# frozen_string_literal: true

module Warp
  module App
    class DashboardsController < Warp::App::ApplicationController
      include ::WarpDashboardPage

      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      public

      def show
        response.headers["Cache-Control"] = "private, no-store"
        return render_session_boundary_not_found unless logged_in?

        authorize!(current_resource, to: :show?)
        render inertia: "warp/app/dashboards/show", props: dashboard_page_props
      end
    end
  end
end
