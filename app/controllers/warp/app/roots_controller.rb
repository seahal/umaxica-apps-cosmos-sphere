# typed: false
# frozen_string_literal: true

module Warp
  module App
    class RootsController < Warp::App::ApplicationController
      include ::WarpDashboardPage

      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open

      public

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_authenticated_home_forbidden if logged_in?

        render inertia: true, props: root_landing_props,
               clear_history: session[:inertia_clear_history] == true
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Warp App",
          description: t("landing.thin_endpoint"),
          links: [
            { label: "Settings", href: warp_app_settings_path(ri: params[:ri]) },
            { label: t("actions.continue"), href: warp_app_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end
