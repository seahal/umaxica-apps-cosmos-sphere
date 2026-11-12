# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  # Core, Warp and Palm own the retained Sphere Jump issuers. Base and Visa remain external Jump
  # participants for retained RP contracts. This capability is separate from
  # JitSecurityJwtRegistry::SURFACE_NAMESPACES, which also carries non-Jump issuers.
  ISSUER_ORIGIN_ENV = {
    "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
    "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
    "VISA_APP" => "PUBLIC_VISA_SERVICE_URL",
    "VISA_ORG" => "PUBLIC_VISA_STAFF_URL",
    "CORE_APP" => "PUBLIC_CORE_SERVICE_URL",
    "CORE_ORG" => "PUBLIC_CORE_STAFF_URL",
    "WARP_APP" => "PUBLIC_WARP_SERVICE_URL",
    "WARP_ORG" => "PUBLIC_WARP_STAFF_URL",
    "PALM_APP" => "PUBLIC_PALM_SERVICE_URL",
  }.freeze
  BOOT_HOST_FIELDS = {
    "VISA_APP" => :visa_service,
    "VISA_ORG" => :visa_staff,
    "CORE_APP" => :core_service,
    "CORE_ORG" => :core_staff,
    "WARP_APP" => :warp_service,
    "WARP_ORG" => :warp_staff,
    "PALM_APP" => :palm_service,
  }.freeze
  ISSUER_NAMESPACES = ISSUER_ORIGIN_ENV.keys.freeze

  JWKS_PATH = "/.well-known/jwks.json"

  # The issuer origin is also the Jump return origin for the namespace. Rails.env plays no part: the
  # identity is whatever PUBLIC_* origin publishes this instance's active signing key in its JWKS.
  def issuer_origin(namespace, env: ENV)
    normalized_namespace = normalize_namespace(namespace)
    name = ISSUER_ORIGIN_ENV.fetch(normalized_namespace)
    raw = env[name]
    from_local_boot = raw.blank? && env.equal?(ENV) && Rails.env.local?
    raw = local_boot_origin(normalized_namespace) if from_local_boot
    raise JumpRtConfigurationError, "#{name} is required for Jump issuance" if raw.blank?

    raw = raw.to_s
    candidate = raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? raw : "https://#{raw}"
    begin
      from_local_boot ? ConfigValues.build(
        candidate,
        allow_localhost: true,
      ).to_s : ConfigValues.public_https_origin(candidate)
    rescue ArgumentError => e
      raise JumpRtConfigurationError, "#{name} must be a public HTTPS origin for Jump: #{e.message}"
    end
  end

  def issuer_jwks_uri(namespace, env: ENV)
    "#{issuer_origin(namespace, env: env)}#{JWKS_PATH}"
  end

  # Only external Base and Visa controllers can own Jump issuance. Edit is a receiver and has no
  # issuer namespace.
  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\ACore::/ then "CORE"
      when /\AWarp::/ then "WARP"
      when /\ABase::/ then "BASE"
      when /\AVisa::/ then "VISA"
      when /\APalm::/ then "PALM"
      end
    surface =
      case controller_class_name.to_s
      when /\A\w+::App::/ then "APP"
      when /\A\w+::Org::/ then "ORG"
      end
    if service.nil? || surface.nil?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    normalize_namespace("#{service}_#{surface}")
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    unless ISSUER_ORIGIN_ENV.key?(value)
      raise JumpRtConfigurationError, "unsupported Jump RT issuer surface: #{namespace.inspect}"
    end

    value
  end

  def normalize_host(host)
    host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end

  def local_boot_origin(namespace)
    field = BOOT_HOST_FIELDS.fetch(namespace, nil)
    return unless field

    Rails.configuration.x.boot_config.fetch(:hosts).public_send(field).to_s
  rescue NoMethodError, KeyError
    nil
  end
end
