# typed: false
# frozen_string_literal: true

module ActorSupport
  extend ActiveSupport::Concern

  class ResolutionError < StandardError; end

  public

  def current_actor
    Actor.context
  end

  private

  # Time.zone is thread-local, so a zone set for one request would otherwise stay
  # on the thread and be inherited by the next request, a job, or a mailer that
  # never resolved a preference of its own. Restoring it here keeps every
  # rendered date -- the copyright year included -- a function of the request's
  # own preference rather than of whatever ran before it.
  def with_actor_lifecycle
    previous_time_zone = Time.zone
    yield
  ensure
    Time.zone = previous_time_zone
    Actor.clear
  end

  def set_current_context
    context = resolved_current_context
    # Note: HostContextResolver's `surface` is the TLD tier, not the ActorValuesContext
    # `surface` route/product axis. The latter, plus transport/channel, are left at
    # their safe baseline here.
    # TODO: derive surface from routing and refine transport/channel from the
    # resolved credential source when those axes gain consumers. Until then the
    # anonymous baseline is transport: :none, channel/surface: :unknown.
    Actor.install_context!(
      tld: context.surface,
      surface: :unknown,
      transport: :none,
      channel: :unknown,
      account: context.account,
      tenant: context.tenant,
      actor: Unauthenticated.instance,
      actor_type: :unauthenticated,
      authn: Actor::Authentication::NULL,
      authz: Actor::Authz::NULL,
      configuration: Actor::Configuration::NULL,
      step_up: Actor::StepUp::NULL,
      trace_id: nil,
      span_id: nil,
    )
  end

  def set_current_actor
    set_current_context if Actor.tld.blank?
    resource = safe_current_resource
    actor = resource.presence || Unauthenticated.instance
    actor_type = resolved_current_actor_type(resource)
    authn = resolved_current_authentication(resource: resource, actor_type: actor_type)
    Actor.install_context!(
      actor: actor,
      actor_type: actor_type,
      authn: authn,
      authz: resolved_current_authz(resource: resource, authn: authn),
      configuration: resolved_current_configuration(resource),
      step_up: resolved_current_step_up,
    )
  end

  alias set_current set_current_actor

  def current_policy_user
    Actor.authz.policy_user || safe_current_resource
  end

  def resolved_current_context
    if Actor.tld.present?
      return HostContextResolver::Context.new(
        surface: Actor.tld,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end
    unless respond_to?(:request, true) && request.present?
      return HostContextResolver::Context.new(
        surface: nil,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end

    HostContextResolver.call(request)
  end

  def resolved_current_tld
    resolved_current_context.surface
  end

  def safe_current_resource
    return unless respond_to?(:current_resource, true)

    current_resource
  rescue StandardError => e
    return nil if respond_to?(:authentication_credentials_invalid?, true) && authentication_credentials_invalid?

    raise_actor_resolution_error!(:current_resource, e)
  end

  def resolved_current_actor_type(resource)
    actor_type = Actor.actor_type
    return actor_type if actor_type.present? && actor_type != :unauthenticated
    return :unauthenticated if resource.blank?

    return :operator if browser_rp_resource_type == "operator"
    return :client if browser_rp_resource_type == "client"

    raise ArgumentError, "unsupported actor resource: #{resource.class.name}"
  end

  def resolved_current_session
    return @current_session_public_id if defined?(@current_session_public_id) && @current_session_public_id.present?

    resolved_current_token&.dig("sid")
  end

  # The verified access-token claims recorded by BrowserRpAuthentication. This must
  # not fall back to another token: ApplicationPolicy reads its Emergency context from here.
  def resolved_current_token
    @current_access_token_payload if defined?(@current_access_token_payload)
  end

  def resolved_current_authentication(resource: safe_current_resource,
                                      actor_type: resolved_current_actor_type(resource))
    token = resolved_current_token
    session_id = resolved_current_session
    return Actor::Authentication::NULL if token.blank? && session_id.blank? && resource.blank?

    Actor::Authentication.new(
      login_public_id: session_id,
      access_claims: token,
      acr: token&.dig("acr"),
      amr: token&.dig("amr"),
      actor_type: actor_type,
      actor_id: resource&.id,
      active_sign_sequence_id: nil,
    )
  end

  def resolved_current_configuration(_resource)
    Actor::Configuration::NULL
  end

  def resolved_current_authz(resource:, authn:)
    Actor::Authz.new(
      policy_user: resource,
      token_claims: authn.access_claims,
      surface: resolved_current_tld,
    )
  end

  def resolved_current_step_up
    Actor::StepUp::NULL
  end

  def raise_actor_resolution_error!(component, exception)
    Rails.logger.warn(
      JitLogEvent.format(
        "actor.resolution.failed",
        component: component,
        error_class: exception.class.name,
      ),
    )

    raise ResolutionError.new("Actor #{component} resolution failed"), cause: exception
  end

  def set_current_observability
    observability_context = ObservabilityContextResolver.call
    Actor.install_context!(
      trace_id: observability_context.trace_id,
      span_id: observability_context.span_id,
    )
  end
end
