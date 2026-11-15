# typed: false
# frozen_string_literal: true

module OidcSsoInitiator
  extend ActiveSupport::Concern
  include CommonRedirect

  OIDC_PENDING_FLOWS_SESSION_KEY = "oidc_pending_flows"
  # D-155: one sign-in per browser and RP. Each POST /sign replaces the entry, so an earlier tab is
  # refused at the callback. This is the intended behavior, not a limit to raise.
  OIDC_PENDING_FLOW_LIMIT = 1

  private

  def initiate_oidc_session!(target_link_uri: nil)
    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    nonce = SecureRandom.urlsafe_base64(32)
    state, jti = OidcStateJwt.issue(
      client_id: oidc_client_id,
      target_link_uri: RpTargetLinkUri.normalize(target_link_uri),
    )

    remember_oidc_pending_flow!(jti:, verifier:, nonce:)
    log_oidc_pending_flow_created

    oidc_authorization_url(
      code_challenge: challenge,
      state: state,
      nonce: nonce,
    )
  end

  def redirect_to_oidc_authorization_url(url, **options)
    if url.start_with?("/") && !url.start_with?("//")
      return redirect_to(url, allow_other_host: false, **options.except(:fallback_internal, :preserve_query_keys))
    end

    decision = oidc_redirect_decision(url)
    log_oidc_redirect_decision(decision)

    case decision.kind
    when :jump
      redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], **options)
    else
      head :bad_request
    end
  end

  def oidc_redirect_decision(url)
    decision = oidc_acme_service_origin.decision_for_authorize_url(url, request: request)
    return decision unless decision.direct?

    # A shared registrable domain does not merge RP and Base trust boundaries.
    decision.with(kind: :jump, reason_code: "jump_authorize_handoff")
  end

  def oidc_authorization_url(code_challenge:, state:, nonce:)
    query = {
      response_type: "code",
      client_id: oidc_client_id,
      redirect_uri: oidc_callback_url,
      code_challenge: code_challenge,
      code_challenge_method: "S256",
      state: state,
      nonce: nonce,
      scope: "openid profile",
      # The authorization endpoint skips region normalization, so it can only carry the region the
      # initiating request already resolved. Without this the ceremony reaches the credential
      # gateway region-less and every URL built from it downstream loses the region too.
      # `RequestContextContract` is used directly rather than `current_region_identifier` because
      # this concern is also included on controllers that do not mix in `PreferenceGlobal`.
      ri: RequestContextContract.normalize_region(params[:ri]),
    }
    oidc_acme_service_origin.authorization_endpoint(query: query)
  end

  # The pending entry is keyed by the `state` JWS's `jti` and replaces any earlier one (D-155).
  def remember_oidc_pending_flow!(jti:, verifier:, nonce:)
    session[OIDC_PENDING_FLOWS_SESSION_KEY] = {
      jti => {
        "code_verifier" => verifier,
        "nonce" => nonce,
        "created_at" => Time.current.to_i,
      },
    }
  end

  def log_oidc_pending_flow_created
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.sso.pending_flow.created",
        client_id: oidc_client_id,
        request_id: request.request_id,
        status: "created",
      ),
    )
  end

  def oidc_callback_url
    client = OidcClientRegistry.find!(oidc_client_id)
    client.redirect_uris.find { |uri| URI.parse(uri).host == request.host } ||
      raise(ActionController::BadRequest, "OIDC redirect URI is not registered for this host")
  rescue URI::InvalidURIError
    raise ActionController::BadRequest, "OIDC redirect URI is invalid"
  end

  def oidc_token_url
    oidc_back_channel_url(oidc_acme_service_origin.token_endpoint)
  end

  # Server-to-server calls to the OP (token, UserInfo) reach this same Rails process. Locally the
  # public HTTPS origin is served by the tunnel, not by this host, so the call goes to the local port.
  def oidc_back_channel_url(public_endpoint)
    OutboundHttp::LocalBackChannel.url(public_endpoint)
  end

  def oidc_client_id
    raise NotImplementedError, "controller must define oidc_client_id"
  end

  def oidc_visa_authority_host
    raise NotImplementedError, "controller must define oidc_visa_authority_host"
  end

  def oidc_visa_service_origin
    @oidc_visa_service_origin ||=
      Oidc::AcmeServiceOrigin.from(
        oidc_visa_authority_host,
        default_scheme: oidc_visa_default_scheme,
      )
  end

  def oidc_visa_default_scheme
    host = Oidc::AcmeServiceOrigin.host_from(oidc_visa_authority_host)
    return request.ssl? ? "https" : "http" if host.present? && host.end_with?(".localhost")

    "https"
  end

  def oidc_acme_service_origin
    oidc_visa_service_origin
  end

  def log_oidc_redirect_decision(decision)
    event_name =
      case decision.kind
      when :jump then "oidc.sso.redirect_policy.jump"
      else "oidc.sso.redirect_policy.rejected"
      end

    payload = {
      request_id: request.request_id,
      surface: oidc_redirect_surface,
      client_id: oidc_client_id,
      request_host: decision.request_host,
      request_scheme: decision.request_scheme,
      target_scheme: decision.target_scheme,
      target_host: decision.target_host,
      target_port: decision.target_port,
      target_path: decision.target_path,
      decision: decision.kind,
      reason_code: decision.reason_code,
      same_site: decision.same_site,
      acme_host: decision.acme_host,
      acme_port: decision.acme_port,
      acme_scheme: decision.acme_scheme,
    }.compact

    Rails.logger.info(JSON.generate(event: event_name, data: payload))
  end

  def oidc_redirect_surface
    "edit_org"
  end
end
