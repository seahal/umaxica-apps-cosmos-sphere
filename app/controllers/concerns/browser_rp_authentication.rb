# typed: false
# frozen_string_literal: true

# Browser RP authentication verifies the Access JWT and its own cell session.
# Controllers supply browser_rp_client_id and browser_rp_resource_type.
module BrowserRpAuthentication
  extend ActiveSupport::Concern

  include RpCellLocalSession

  AccessState = Data.define(:status, :resource, :rp_session, :payload)
  AUTHENTICATION_MODE_RULES = Concurrent::Map.new
  AUTHENTICATION_REQUIRED_REASONS = {
    missing: "access_credential_missing",
    invalid: "access_credential_invalid",
  }.freeze
  private_constant :AUTHENTICATION_REQUIRED_REASONS

  class InvalidPolicyError < StandardError; end

  class MissingPolicyError < StandardError; end

  class SkipNotAllowedError < StandardError; end

  class_methods do
    def authentication_mode_rules
      AUTHENTICATION_MODE_RULES.fetch_or_store(self) { [] }
    end

    def local_authentication_mode_rules
      authentication_mode_rules
    end

    def declare_authentication_mode!(mode, only: nil, except: nil, **options)
      mode = mode.to_sym
      unless %i(bare deny_all guest private open).include?(mode)
        raise InvalidPolicyError, "Invalid authentication mode: #{mode.inspect}"
      end

      rule = {
        mode: mode,
        only: Array(only).map(&:to_s).presence,
        except: Array(except).map(&:to_s).presence,
        options: options,
      }
      AUTHENTICATION_MODE_RULES[self] = authentication_mode_rules + [rule]
    end

    def authentication_mode_for(action)
      action = action.to_s
      authentication_mode_rules.reverse_each do |rule|
        next if rule[:only].present? && rule[:only].exclude?(action)
        next if rule[:except].present? && rule[:except].include?(action)

        return rule[:mode]
      end

      return const_get(:AUTHENTICATION_MODE, false) if const_defined?(:AUTHENTICATION_MODE, false)

      :deny_all
    end

    def skip_before_action(*filters, **options)
      flattened = filters.flatten
      action_names =
        flattened.filter_map do |filter|
          next unless filter.respond_to?(:to_sym) && !filter.is_a?(Hash)

          filter.to_sym
        end
      if action_names.include?(:enforce_access_policy!)
        raise SkipNotAllowedError, "skip_before_action :enforce_access_policy! is prohibited (#{name})"
      end

      super
    end
  end

  public

  def current_resource
    browser_rp_access_state.resource
  end

  def logged_in?
    browser_rp_authenticated?
  end

  def authentication_credentials_invalid?
    browser_rp_access_state.status == :invalid
  end

  def verify_private_action_authorized!
    return unless self.class.authentication_mode_for(action_name) == :private

    verify_authorized
  end

  def apply_authenticated_page_cache_policy!
    return unless authenticated_page_response?
    return if response.headers["Cache-Control"].to_s.split(",").map(&:strip).include?("no-store")

    response.set_header("Cache-Control", "no-store")
  end

  def authenticated_page_response?
    return false unless response.media_type == "text/html"

    mode = self.class.authentication_mode_for(action_name)
    return true if mode == :private
    return false if mode == :bare

    logged_in?
  end

  def enforce_access_policy!
    mode = self.class.authentication_mode_for(action_name)
    case mode
    when :deny_all
      raise MissingPolicyError,
            # rubocop:disable I18n/RailsI18n/DecorateString -- This is a diagnostic exception, not customer copy.
            "Denied by default authentication mode for #{self.class.name}##{action_name}. " \
            "Declare a concrete authentication mode before exposing this endpoint."
    when :bare, :open
      return true unless authentication_credentials_invalid?

      clear_browser_rp_cookies!
      return true if browser_rp_invalid_credentials_are_ignored?

      render_browser_rp_invalid_credentials!
      false
    when :private
      authenticate_browser_rp!
    when :guest
      return true unless browser_rp_authenticated?

      render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
             content_type: "text/plain"
      false
    else
      raise InvalidPolicyError, "Unexpected authentication mode: #{mode.inspect}"
    end
  end

  # Guards shared with root-authenticated controllers branch on this instead of probing for
  # Browser RP methods.
  def browser_rp_controller? = true

  def browser_rp_authenticated?
    browser_rp_access_state.status == :valid
  end

  def authenticate_browser_rp!
    return true if browser_rp_authenticated?
    return false if browser_rp_dependency_failed?

    log_browser_rp_authentication_required!
    clear_browser_rp_cookies! if browser_rp_access_state.status == :invalid
    render_browser_rp_unauthenticated!
    false
  end

  def current_session_public_id
    browser_rp_access_state.rp_session&.public_id
  end

  def current_session
    browser_rp_access_state.rp_session
  end

  def browser_rp_session_public_id
    browser_rp_access_state.rp_session&.public_id
  end

  protected

  # Presence flags only: they separate an access credential the browser stopped sending from a
  # refused one, without recording either credential.
  def log_browser_rp_authentication_required!
    refused_status = @browser_rp_refused_access_status
    refused_status = browser_rp_access_state.status if refused_status.nil?
    Rails.logger.info(
      JitLogEvent.format(
        "auth.session.authentication_required",
        occurred_at: Time.current.utc.iso8601(3),
        request_id: request.request_id,
        controller: self.class.name,
        action: action_name,
        failure_reason: AUTHENTICATION_REQUIRED_REASONS.fetch(refused_status),
        access_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::ACCESS_COOKIE),
        refresh_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::REFRESH_COOKIE),
        # Strict credentials are withheld on a cross-site navigation; this tells that case apart.
        fetch_site: request.headers["Sec-Fetch-Site"].presence_in(%w(same-origin same-site cross-site none)),
      ),
    )
  end

  def browser_rp_client_id
    raise NotImplementedError, "controller must define browser_rp_client_id"
  end

  def browser_rp_resource_type
    raise NotImplementedError, "controller must define browser_rp_resource_type"
  end

  def resource_type
    browser_rp_resource_type
  end

  def browser_rp_trusted_origins
    []
  end

  # A refused credential on a public HTML page is detached and the page renders anonymous
  # (adr/invalid-browser-credential-recovery.md); other representations keep their
  # authentication failure response.
  def browser_rp_invalid_credentials_are_ignored?
    request.format.html?
  end

  def render_browser_rp_unauthenticated!
    response.set_header("Cache-Control", "no-store")
    return render(json: { error: "Unauthorized" }, status: :unauthorized) if request.format.json?

    render plain: I18n.t("errors.messages.login_required"), status: :unauthorized, content_type: "text/plain"
  end

  def render_browser_rp_invalid_credentials!
    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.login_required"), status: :unauthorized, content_type: "text/plain"
  end

  # Names the failed stage and an exception class or closed outcome; never a credential or message.
  def log_browser_rp_dependency_failure(stage:, detail:)
    Rails.logger.warn(
      JitLogEvent.format(
        "browser_rp.dependency.failed",
        request_id: request.request_id,
        stage: stage,
        detail: detail,
      ),
    )
  end

  def render_browser_rp_dependency_failure!
    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.temporarily_unavailable"), status: :service_unavailable,
           content_type: "text/plain"
  end

  def browser_rp_access_state
    return @browser_rp_access_state if defined?(@browser_rp_access_state)

    @browser_rp_access_state = resolve_browser_rp_access_cookie
  rescue ActiveRecord::ActiveRecordError, OidcOpJwksClient::FetchError => e
    log_browser_rp_dependency_failure(stage: "access_state", detail: e.class.name)
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure! unless performed?
    @browser_rp_access_state = AccessState.new(
      status: :missing,
      resource: nil,
      rp_session: nil,
      payload: nil,
    )
  end

  def browser_rp_dependency_failed?
    defined?(@browser_rp_dependency_failed) && @browser_rp_dependency_failed
  end

  def resolve_browser_rp_access_cookie(access_token: nil)
    access_token ||= BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    resolve_rp_cell_access(access_token)
  end

  # R5-WU17 cell process: the resource is the cell's local principal, the session its local session.
  def resolve_rp_cell_access(access_token)
    result = authenticate_rp_cell_request(access_token:)
    return AccessState.new(
      status: result.status, resource: nil, rp_session: nil, payload: nil,
    ) unless
      result.authenticated?

    @current_access_token_payload = result.payload
    AccessState.new(
      status: :valid, resource: result.principal, rp_session: result.session, payload: result.payload,
    )
  end

  def rp_cell_client_id = browser_rp_client_id

  def rp_cell_resource_type = browser_rp_resource_type

  def clear_browser_rp_access_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    @current_access_token_payload = nil
  end

  def clear_browser_rp_cookies!
    clear_browser_rp_access_cookie!
    clear_rp_cell_session_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
    @browser_rp_access_state = AccessState.new(
      status: :missing,
      resource: nil,
      rp_session: nil,
      payload: nil,
    )
  end

  def install_browser_rp_token_response!(result)
    token_response = result.token_response
    access_token, refresh_token = OidcRpBrowserCredentialContract.require_token_response!(token_response)
    now = Time.current
    access_expires_at = OidcRpBrowserCredentialContract.access_expires_at_from_response(token_response, now: now)
    refresh_expires_at = OidcRpBrowserCredentialContract.refresh_expires_at_from_response(token_response, now: now)
    raise ArgumentError, "RP refresh expiry precedes access expiry" if refresh_expires_at < access_expires_at

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(expires_at: access_expires_at).merge(
        value: access_token,
      )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options(expires_at: refresh_expires_at).merge(
        value: refresh_token,
      )
    @browser_rp_access_state = resolve_browser_rp_access_cookie(access_token: access_token)
    browser_rp_access_state
  end

  def refresh_browser_rp_credentials!
    refresh_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    return :missing if invalid_browser_rp_refresh_value?(refresh_token)

    refresh_rp_cell_credentials!(refresh_token)
  rescue ActiveRecord::ActiveRecordError, Umaxica::Valkey::Unavailable,
         Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError => e
    log_browser_rp_dependency_failure(stage: "refresh", detail: e.class.name)
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure!
    :dependency
  end

  # R5-WU17 cell process: check/dispatch/install under the local session (RpRefreshCommitter).
  def refresh_rp_cell_credentials!(refresh_token)
    cell = rp_cell
    # The explicit Refresh path reserves and installs on the cell writer.
    result =
      "#{cell.record_prefix}Record".constantize.connected_to(role: :writing) do
        RpRefreshCommitter.call(
          cell:, local_session_id: cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].to_s,
          refresh_token:, issuer: rp_cell_issuer,
          jwks_client: rp_cell_jwks_client, token_url: OidcIssuer.token_endpoint(browser_rp_resource_type),
        )
      end
    case result.outcome
    when :installed
      install_browser_rp_token_response!(result)
      :success
    when :refused, :revoked
      @browser_rp_refused_access_status = browser_rp_access_state.status
      @browser_rp_refresh_refused = true
      clear_browser_rp_cookies!
      :invalid
    else
      # dependency, or superseded by a concurrent request: keep the cookies; a retry reads the
      # generation the other request installed.
      log_browser_rp_dependency_failure(stage: "cell_refresh", detail: result.outcome)
      @browser_rp_dependency_failed = true
      render_browser_rp_dependency_failure!
      :dependency
    end
  end

  def invalid_browser_rp_refresh_value?(value)
    value.blank? || value.include?("\0") || value != value.strip
  end
end
# rubocop:enable I18n/RailsI18n/DecorateString
