# typed: false
# frozen_string_literal: true

module CommonRedirect
  extend ActiveSupport::Concern

  def self.normalize_host(val)
    return nil if val.blank?

    str = val.to_s.strip
    begin
      uri = URI.parse(str)
      host = uri.host.presence || str.split("/").first
    rescue URI::InvalidURIError
      host = str
    end
    # strip scheme remnants and spaces
    host.to_s.downcase.sub(%r{^https?://}i, "").split("/").first
  end
  public_class_method :normalize_host

  public

  def redirect_to_jump_url(
    url,
    namespace: jump_rt_issuer_namespace,
    dst: "internal",
    preserve_query_keys: [],
    **
  )
    preserve_query_keys |= safe_jump_preserved_query_keys(url)
    token = JumpRtIssuer.call(
      namespace: namespace,
      url: url,
      dst: dst,
      preserve_query_keys: preserve_query_keys,
    )
    if token.present?
      log_jump_rt_issued(token: token, namespace: namespace, dst: dst, url: url)
      result = RedirectsJumpGatewayUrl.call(token)
      return redirect_to(result.value, allow_other_host: true, **) if result.ok?

      log_redirect_target_failure(result)
      return render plain: I18n.t("errors.messages.invalid_request"),
                    status: :unprocessable_content
    end

    result = RedirectsTargetResult.failure(
      kind: :external, source: :jump_rt_issue, reason: :invalid_jump_rt_url,
      unsafe_value: url,
    )
    log_redirect_target_failure(result)
    render plain: I18n.t("errors.messages.invalid_request"),
           status: :unprocessable_content
  end

  public

  def safe_jump_preserved_query_keys(url)
    uri = URI.parse(url.to_s)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    return [] unless uri.is_a?(URI::HTTP)
    return [] unless uri.path == "/oauth/authorize"
    return [] unless oidc_authorize_host_allowed?(uri.host)
    return [] unless defined?(OidcClientRegistry)
    return [] unless OidcClientRegistry.valid_redirect_uri?(query["client_id"], query["redirect_uri"])

    ["redirect_uri"]
  rescue URI::InvalidURIError,
         Rack::Utils::ParameterTypeError,
         Rack::Utils::InvalidParameterError,
         Rack::Utils::ParamsTooDeepError
    []
  end

  public

  def oidc_authorize_host_allowed?(host)
    allowed_hosts =
      %w(PUBLIC_BASE_SERVICE_URL PUBLIC_BASE_STAFF_URL)
        .filter_map do |key|
        Oidc::AcmeServiceOrigin.host_from(ENV.fetch(key)) || CommonRedirect.normalize_host(ENV.fetch(key))
      end
    allowed_hosts += %w(
      base.app.localhost base.org.localhost
      visa.app.localhost visa.org.localhost
    )
    boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    allowed_hosts.concat([boot_hosts.visa_service.host, boot_hosts.visa_staff.host])
    allowed_hosts.include?(CommonRedirect.normalize_host(host))
  end

  public

  def safe_redirect_to(target, fallback: "/", **)
    result = RedirectsPathTargetResolver.call(target, source: :legacy_safe_redirect)
    safe_path = result.value if result.ok?
    log_redirect_target_failure(result) unless result.ok? || target.blank?

    if safe_path
      redirect_to(safe_path, allow_other_host: false, **)
    else
      redirect_to(fallback, allow_other_host: false, **)
    end
  end

  public

  def safe_redirect_back_or_to(fallback, **)
    result = RedirectsPathTargetResolver.call(request.referer, source: :referer)
    safe_path = result.value if result.ok?
    redirect_to(safe_path || fallback, allow_other_host: false, **)
  end

  public

  def safe_internal_path(target)
    result = RedirectsPathTargetResolver.call(target, source: :internal_path)
    result.value if result.ok?
  end

  public

  def jump_rt_issuer_namespace
    JumpRtSurface.namespace_for_controller(self.class.name)
  end

  public

  def log_jump_rt_issued(token:, namespace:, dst:, url:)
    req = request if respond_to?(:request, true)
    headers = req.headers if req&.respond_to?(:headers)
    request_id = req.request_id if req&.respond_to?(:request_id)
    referer = req.referer if req&.respond_to?(:referer)
    user_agent = req.user_agent if req&.respond_to?(:user_agent)
    remote_ip = req.remote_ip if req&.respond_to?(:remote_ip)
    cf_connecting_ip = headers["CF-Connecting-IP"] if headers
    Rails.logger.info(
      JitLogEvent.format(
        "jump_rt.issued",
        request_id: request_id,
        namespace: namespace,
        dst: dst,
        rt_length: token.to_s.bytesize,
        rt_parts: token.to_s.split(".").size,
        rt_digest12: Digest::SHA256.hexdigest(token.to_s)[0, 12],
        target_url_digest: Digest::SHA256.hexdigest(url.to_s)[0, 12],
        referer_digest12: digest12(referer),
        user_agent_digest12: digest12(user_agent),
        remote_ip_digest12: digest12(remote_ip),
        cf_connecting_ip_digest12: digest12(cf_connecting_ip),
        cf_ray: headers&.[]("CF-Ray").presence,
        cf_asn: headers&.[]("CF-ASN").presence,
        cf_ipcountry: headers&.[]("CF-IPCountry").presence,
      ),
    )
  end

  public

  def digest12(value)
    raw = value.to_s
    return nil if raw.blank?

    Digest::SHA256.hexdigest(raw)[0, 12]
  end

  public

  def log_redirect_target_failure(result)
    return if result.ok?

    request_id = request.request_id if respond_to?(:request, true) && request.respond_to?(:request_id)
    Rails.logger.info(
      JitLogEvent.format(
        "redirect_target.rejected",
        kind: result.kind,
        source: result.source,
        reason: result.failure_reason,
        unsafe_value_digest: result.unsafe_value_digest,
        request_id: request_id,
      ),
    )
  end
end
