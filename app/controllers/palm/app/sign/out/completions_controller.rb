# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      module Out
        class CompletionsController < Palm::App::ApplicationController
          include ::SignOutNotice
          include ::OidcRpLogoutLauncher
          include ::SurfaceInertiaPage

          inertia_share chrome: -> { surface_chrome }
          inertia_share clear_history: -> { session[:inertia_clear_history] == true }
          include ::SignOutInertiaPages
          include ::SignOutClearSiteData

          AUTHENTICATION_MODE = :open
          prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
          ensure_fqdn_gate_first!
          layout "palm/app/inertia"

          public

          def show
            complete_oidc_rp_logout!
          end

          private

          def sign_out_confirmation_form_path
            palm_app_sign_out_completion_path
          end

          def sign_out_post_path(**options)
            palm_app_sign_out_completion_path(**sign_out_route_params, **options.compact)
          end

          # The durable logout challenge authorizes origin cleanup after parent revocation; refreshing
          # here would only fail and clear the Palm RP cookies.
          def browser_rp_unsafe_request_refresh_enabled?
            false
          end
        end
      end
    end
  end
end
