# typed: false
# frozen_string_literal: true

module Warp
  module Org
    class RootsController < Warp::Org::ApplicationController
      include ::WarpDashboardPage

      inertia_share chrome: -> { surface_chrome }
      inertia_share clear_history: -> { session[:inertia_clear_history] == true }
      include ::SessionBoundaryNotFound

      AUTHENTICATION_MODE = :open
      layout "warp/org/inertia"

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
          heading: "Warp Org",
          description: t("landing.thin_endpoint"),
          links: [
            { label: "Settings", href: warp_org_settings_path(ri: params[:ri]) },
            { label: t("actions.continue"), href: warp_org_sign_show_path(ri: params[:ri]) },
          ],
        }
      end
    end
  end
end
