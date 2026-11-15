# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      class OutsController < Palm::App::ApplicationController
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher
        include ::SurfaceInertiaPage

        inertia_share chrome: -> { surface_chrome }
        inertia_share clear_history: -> { session[:inertia_clear_history] == true }
        include ::SignOutInertiaPages

        AUTHENTICATION_MODE = :open
        prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
        ensure_fqdn_gate_first!
        layout "palm/app/inertia"
        declare_authentication_mode! :open
        before_action :authenticate_oidc_rp_session!, only: :create
        after_action :sign_out_notice_cache_headers!, only: %i(show edit)

        public

        def show
          complete_oidc_rp_logout!
        end

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render_sign_out_confirmation_page
        end

        def create
          launch_oidc_rp_logout!(client_id: RpDeploymentBindingValue.client_id("palm-app"))
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
