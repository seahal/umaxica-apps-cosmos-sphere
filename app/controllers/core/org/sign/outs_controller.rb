# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Sign
      class OutsController < Core::Org::ApplicationController
        include ::SignOutNotice
        include ::SignOutInertiaPages
        include ::OidcRpLogoutLauncher
        include ::SignOutClearSiteData

        AUTHENTICATION_MODE = :open
        prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
        ensure_fqdn_gate_first!
        declare_authentication_mode! :open

        before_action :authenticate_oidc_rp_session!, only: :create
        after_action :sign_out_notice_cache_headers!, only: %i(show edit)

        public

        def show
          complete_oidc_rp_logout!
        end

        public

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        public

        def edit
          render_sign_out_confirmation_page
        end

        public

        def create
          launch_oidc_rp_logout!(client_id: RpDeploymentBindingValue.client_id("core-org"))
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
