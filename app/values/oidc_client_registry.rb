# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  class ClientAuthenticationConfigurationError < StandardError; end

  DEFAULT_ALLOWED_SCOPES = %w(openid profile email).freeze

  ClientConfiguration =
    Data.define(
      :client_id, :redirect_uris, :redirect_uris_by_realm, :post_logout_redirect_uris,
      :aud, :resource_type,
      :name, :domains, :allowed_scopes, :registered_token_endpoint_auth_method,
      :jwt_namespace,
    ) do
      def public_client?
        registered_token_endpoint_auth_method == "none"
      end

      def confidential_client?
        !public_client?
      end

      def private_key_jwt_client?
        registered_token_endpoint_auth_method == "private_key_jwt"
      end
    end
  CLIENTS_MUTEX = Mutex.new
  CLIENTS_CACHE = Concurrent::AtomicReference.new(nil)

  module_function

  # @param client_id [String]
  # @return [ClientConfiguration, nil]
  def find(client_id)
    config = clients[client_id.to_s]
    return nil unless config

    registered_auth_method = config[:token_endpoint_auth_method]
    # Public and process-local RP origins can resolve to the same host outside production, so
    # collapse repeats here rather than letting consumers see the same URI twice.
    redirect_uris_by_realm = redirect_uris_by_realm_for(config).transform_values(&:uniq)
    all_redirect_uris = redirect_uris_by_realm.values.flatten
    all_redirect_uris.uniq!

    ClientConfiguration.new(
      client_id: client_id.to_s,
      redirect_uris: all_redirect_uris,
      redirect_uris_by_realm: redirect_uris_by_realm,
      post_logout_redirect_uris: (config[:post_logout_redirect_uris] || []).uniq,
      aud: config[:aud],
      resource_type: config[:resource_type],
      name: config[:name],
      domains: domains_from_redirect_uris(all_redirect_uris),
      allowed_scopes: normalize_allowed_scopes(config.fetch(:allowed_scopes, DEFAULT_ALLOWED_SCOPES)),
      registered_token_endpoint_auth_method: registered_auth_method,
      jwt_namespace: config[:jwt_namespace],
    )
  end

  # @param client_id [String]
  # @return [ClientConfiguration]
  # @raise [ClientNotFound]
  def find!(client_id)
    find(client_id) || raise(ClientNotFound, "Unknown OIDC client: #{client_id}")
  end

  # @param client_id [String]
  # @param uri [String]
  # @param resource_type [String, nil] when given, the redirect_uri must be registered for this
  #   realm (client/operator) specifically, not merely registered anywhere for the client.
  # @return [Boolean]
  def valid_redirect_uri?(client_id, uri, resource_type: nil)
    client = find(client_id)

    OidcRedirectUriPolicy.valid_redirect_uri?(client, uri, resource_type: resource_type)
  end

  def valid_post_logout_redirect_uri?(client_id:, uri:, resource_type:)
    client = find(client_id)
    return false unless OidcRedirectUriPolicy.valid_post_logout_redirect_uri?(client, uri)

    normalize_resource_type(client.resource_type) == normalize_resource_type(resource_type)
  end

  def jwt_namespace_for(client_id)
    find(client_id)&.jwt_namespace
  end

  def client_ids
    clients.keys
  end

  def validate_private_key_jwt_configuration!
    # An RP cell process holds only its own client key (RuntimeRole.rp_private_env_names).
    checked_ids =
      if RuntimeRole::RP_ROLES.include?(RuntimeRole.current)
        [RpCellBinding.fetch(RuntimeRole.cell_connection).client_id]
      else
        client_ids
      end
    missing =
      checked_ids.filter_map do |client_id|
        client = find(client_id)
        next unless client&.private_key_jwt_client?
        next if client.jwt_namespace.present? &&
          JitSecurityJwtRegistry.private_key_for("oidc_client:#{client.jwt_namespace}").present?

        "#{client.client_id}(#{client.jwt_namespace.presence || "missing_namespace"})"
      end

    return true if missing.empty?

    raise ClientAuthenticationConfigurationError,
          "private_key_jwt OIDC clients are missing signing keys: #{missing.join(", ")}"
  end

  def normalize_allowed_scopes(allowed_scopes)
    Array(allowed_scopes).map(&:to_s).freeze
  end

  # --- private ---

  def clients
    cached_clients = CLIENTS_CACHE.get
    signature = client_config_signature
    return cached_clients.fetch(:clients) if cached_clients&.fetch(:signature, nil) == signature

    CLIENTS_MUTEX.synchronize do
      cached_clients = CLIENTS_CACHE.get
      return cached_clients.fetch(:clients) if cached_clients&.fetch(:signature, nil) == signature

      begin
        built_clients = build_clients
        CLIENTS_CACHE.set({ signature: signature, clients: built_clients }.freeze)
        built_clients
      end
    end
  end

  def client_config_signature
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [hosts.core_service, hosts.core_staff, hosts.warp_service, hosts.warp_staff, hosts.palm_service]
      .map(&:to_s).freeze
  end

  def build_clients
    OidcClientStoresStaticClientStore.clients
  end

  def domains_from_redirect_uris(redirect_uris)
    result = redirect_uris.filter_map { |uri| URI.parse(uri).host.presence }
    result.uniq!
    result
  rescue URI::InvalidURIError
    []
  end

  def redirect_uris_by_realm_for(config)
    return config[:redirect_uris_by_realm] if config[:redirect_uris_by_realm]

    { normalize_resource_type(config[:resource_type]) => Array(config[:redirect_uris]) }
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "client" then "client"
    else raise ArgumentError, "unsupported OIDC resource type"
    end
  end

  private_class_method :clients, :build_clients, :client_config_signature,
                       :domains_from_redirect_uris,
                       :redirect_uris_by_realm_for,
                       :normalize_resource_type, :normalize_allowed_scopes
end
