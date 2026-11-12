# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS
  CANONICAL_RP_CALLBACK_PATH = "/oidc/callback"
  CANONICAL_RP_SIGN_OUT_PATH = "/sign/out/completion"

  module_function

  def clients
    first_party_browser_rp_clients
      .freeze
  end

  def first_party_browser_rp_clients
    FIRST_PARTY_RP_SPECS.to_h do |client_id, spec|
      jwt_namespace = spec.fetch(:jwt_namespace) { client_id.upcase.tr("-", "_") }
      [client_id, face_rp_client(**spec, aud: client_id, jwt_namespace:)]
    end
  end

  # RP-local metadata for the existing five cell bindings; Access owns OP registration.
  FIRST_PARTY_RP_SPECS = {
    "core-app-jp" => { env_key: "PUBLIC_CORE_SERVICE_URL",
                       resource_type: "client",
                       name: "Core app",
                       jwt_namespace: "CORE_APP_JP", }.freeze,
    "core-org-jp" => { env_key: "PUBLIC_CORE_STAFF_URL",
                       resource_type: "operator",
                       name: "Core org",
                       jwt_namespace: "CORE_ORG_JP", }.freeze,
    "warp-app-jp" => { env_key: "PUBLIC_WARP_SERVICE_URL",
                       resource_type: "client",
                       name: "Warp app",
                       jwt_namespace: "WARP_APP_JP", }.freeze,
    "warp-org-jp" => { env_key: "PUBLIC_WARP_STAFF_URL",
                       resource_type: "operator",
                       name: "Warp org",
                       jwt_namespace: "WARP_ORG_JP", }.freeze,
    "palm-app-jp" => { env_key: "PUBLIC_PALM_SERVICE_URL",
                       resource_type: "client",
                       name: "Palm app",
                       jwt_namespace: "PALM_APP_JP", }.freeze,
  }.freeze

  RP_BACKCHANNEL_LOGOUT_PATH = "/oidc/closures"

  # The frozen back-channel logout endpoint for an active first-party RP (R5-WU10, one.md 7.6).
  # It is derived from the same registered host as the RP callback; no logout delivery target is
  # ever taken from a grant, token or request.
  def backchannel_logout_uri(client_id)
    spec = FIRST_PARTY_RP_SPECS[client_id.to_s]
    raise KeyError, "no registered back-channel logout endpoint for #{client_id.inspect}" unless spec

    build_redirect_uris(spec.fetch(:env_key), spec[:default_host], path: RP_BACKCHANNEL_LOGOUT_PATH).first
  end

  def face_rp_client(env_key:, resource_type:, aud:, name:, jwt_namespace:, default_host: nil,
                     callback_path: CANONICAL_RP_CALLBACK_PATH,
                     sign_out_path: CANONICAL_RP_SIGN_OUT_PATH)
    {
      redirect_uris_by_realm: {
        resource_type => build_redirect_uris(env_key, default_host, path: callback_path),
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris(
        env_key, default_host, path: sign_out_path,
      ),
      aud: aud,
      resource_type: resource_type,
      name: name,
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: jwt_namespace,
    }
  end

  # default_host is only consulted for env keys boot_host_for does not map; keys it maps resolve
  # from boot config and must not carry a literal default that can drift from the real host.
  def build_redirect_uris(env_key, default_host = nil, path: "/oidc/callback")
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      validate_registered_redirect_uri!("#{protocol}://#{host}#{port_suffix}#{path}")
    end
  end

  RESERVED_REDIRECT_QUERY_KEYS = %w(code state iss error error_description error_uri session_state).freeze

  # D-147 N-4: an invalid registration stops the boot (RFC 6749 3.1.2 absolute, no fragment;
  # TLS in production, RFC 6749 3.1.2.1 and RFC 9700 2.1; no reserved query key, UMAXICA).
  def validate_registered_redirect_uri!(value)
    uri = URI.parse(value)
    valid = uri.absolute? && uri.host.present? && uri.fragment.nil? && uri.userinfo.nil? &&
      %w(http https).include?(uri.scheme) && (!Rails.env.production? || uri.scheme == "https") &&
      (URI.decode_www_form(uri.query.to_s).map(&:first) & RESERVED_REDIRECT_QUERY_KEYS).empty?
    raise ArgumentError, "invalid registered redirect_uri: #{value}" unless valid

    value
  rescue URI::InvalidURIError
    raise ArgumentError, "invalid registered redirect_uri: #{value}"
  end

  def build_post_logout_redirect_uris(env_key, default_host = nil,
                                      path: CANONICAL_RP_SIGN_OUT_PATH)
    configured_hosts_for(env_key, default_host).flat_map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      RequestContextContract.allowed_regions.map do |region|
        "#{protocol}://#{host}#{port_suffix}#{path}?ri=#{region}"
      end
    end
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def configured_hosts_for(env_keys, default_host = nil)
    hosts = Array(env_keys).map { |env_key| boot_host_for(env_key, default_host) }
    hosts.uniq!
    hosts
  end

  def boot_host_for(env_key, default_host = nil)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host =
      case env_key
      when "PUBLIC_CORE_SERVICE_URL" then hosts.core_service.to_s
      when "PUBLIC_CORE_STAFF_URL" then hosts.core_staff.to_s
      when "PUBLIC_WARP_SERVICE_URL" then hosts.warp_service.to_s
      when "PUBLIC_WARP_STAFF_URL" then hosts.warp_staff.to_s
      when "PUBLIC_PALM_SERVICE_URL" then hosts.palm_service.to_s
      else
        raise KeyError, "No boot host mapping for #{env_key} and no default host given" if default_host.blank?

        default_host
      end

    normalize_host(host)
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :first_party_browser_rp_clients, :face_rp_client, :build_redirect_uris,
                       :build_post_logout_redirect_uris,
                       :public_host?, :configured_hosts_for, :boot_host_for,
                       :normalize_host, :validate_registered_redirect_uri!
end
