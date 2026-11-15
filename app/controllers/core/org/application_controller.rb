# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::JumpRtReturnVerification
      include ::BrowserRpAuthentication
      include ::BrowserRpSafeRequestRefresh
      include ::BrowserRpUnsafeRequestRefresh

      include ::SignErrorResponses
      include ::AuthorizationAudit
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      include ::ActorSupport

      AUTHENTICATION_MODE = :deny_all
      prepend_before_action(:enforce_fqdn_availability!)
      after_action :verify_private_action_authorized!
      after_action :apply_authenticated_page_cache_policy!
      before_action :authenticate_browser_rp_safe_request!
      prepend_before_action :authenticate_browser_rp_unsafe_request!
      ensure_fqdn_gate_first!

      layout "core/org/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from SphereOwnerDataUnavailableError, with: :handle_owner_data_unavailable
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "core_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :set_current_actor
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      public

      def oidc_client_id
        RpDeploymentBindingValue.client_id("core-org")
      end

      def browser_rp_client_id
        RpDeploymentBindingValue.client_id("core-org")
      end

      def browser_rp_resource_type
        "operator"
      end

      public :browser_rp_client_id, :browser_rp_resource_type

      public

      def oidc_sign_host
        ENV.fetch("PRIVATE_AUTH_STAFF_URL")
      end

      public

      def oidc_visa_authority_host
        Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host
      end

      public

      def oidc_acme_host
        oidc_visa_authority_host
      end

      private
    end
  end
end
