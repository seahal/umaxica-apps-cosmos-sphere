# typed: false
# frozen_string_literal: true

# Concern for auditing authorization failures
# Records when users/staff attempt unauthorized actions
module AuthorizationAudit
  extend ActiveSupport::Concern

  include CommonRedirect

  private

  def handle_authorization_error(exception)
    # Log the authorization failure
    log_authorization_failure(exception)

    # Respond based on request format
    respond_to do |format|
      format.html do
        flash[:alert] = I18n.t("errors.messages.not_authorized")
        safe_redirect_back_or_to(authorization_failure_fallback_path)
      end
      format.json do
        render json: { error: "Unauthorized" }, status: :forbidden
      end
    end
  rescue SphereOwnerDataUnavailableError => e
    handle_owner_data_unavailable(e)
  end

  def log_authorization_failure(exception)
    actor = authorization_audit_actor
    return unless actor

    log_data = build_log_data(actor, exception)

    # Log the authorization failure event
    Rails.logger.info(JitLogEvent.format("authorization.failure", log_data))

    create_audit_record(actor, log_data)
  rescue SphereOwnerDataUnavailableError
    raise
  rescue StandardError => e
    # Audit infrastructure failures remain visible
    Rails.logger.error(
      JitLogEvent.format(
        "authorization.failure_log.failed", error_class: e.class.name,
                                            message: e.message,
      ),
    )
  end

  def authorization_failure_fallback_path
    return root_path if respond_to?(:root_path)

    "/"
  end

  def build_log_data(actor, exception)
    {
      actor_type: actor.class.name,
      actor_id: audit_identifier(actor),
      actor_state: defined?(Actor) ? Actor.whoami : nil,
      login_public_id: defined?(Actor) ? Actor.authn.login_public_id : nil,
      action: action_name,
      controller: controller_name,
      # ActionPolicy::Unauthorized carries the policy class and rule, not the authorized record.
      policy: exception.policy.name,
      query: exception.rule,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_id: request.respond_to?(:request_id) ? request.request_id : nil,
      trace_id: defined?(Actor) ? Actor.trace_id : nil,
      span_id: defined?(Actor) ? Actor.span_id : nil,
      timestamp: Time.current,
    }.compact
  end

  # Existing audit rows name Governance actors. A local RP principal cannot stand in for them.
  def create_audit_record(_actor, _log_data)
    raise SphereOwnerDataUnavailableError, "Governance authorization audit identity is unavailable in Sphere"
  end

  def authorization_audit_actor
    current_resource
  end

  def audit_identifier(record)
    return if record.blank?
    return record.public_id if record.respond_to?(:public_id) && record.public_id.present?

    record.id if record.respond_to?(:id)
  end
end
