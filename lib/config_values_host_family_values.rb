# frozen_string_literal: true

module ConfigValues
  HostFamilyValues =
    Data.define(
      :acme_service, :acme_staff,
      :base_service, :base_corporate, :base_staff,
      :visa_service, :visa_staff,
      :core_service, :core_staff,
      :warp_service, :warp_staff,
      :palm_service,
    )
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  public

  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(**host_family_origins(env:, production:)).freeze
  end

  def host_family_origins(env:, production:)
    {
      acme_service: origin(env, "PRIVATE_BASE_SERVICE_URL", production:),
      acme_staff: origin(env, "PRIVATE_BASE_STAFF_URL", production:),
      base_service: origin(env, "PUBLIC_BASE_SERVICE_URL", production:),
      base_corporate: origin(env, "PUBLIC_BASE_CORPORATE_URL", production:),
      base_staff: origin(env, "PUBLIC_BASE_STAFF_URL", production:),
      visa_service: origin(env, "PUBLIC_VISA_SERVICE_URL", production:),
      visa_staff: origin(env, "PUBLIC_VISA_STAFF_URL", production:),
      core_service: origin(env, "PUBLIC_CORE_SERVICE_URL", production:),
      core_staff: origin(env, "PUBLIC_CORE_STAFF_URL", production:),
      warp_service: origin(env, "PUBLIC_WARP_SERVICE_URL", production:),
      warp_staff: origin(env, "PUBLIC_WARP_STAFF_URL", production:),
      palm_service: origin(env, "PUBLIC_PALM_SERVICE_URL", production:),
    }
  end

  def origin(env, key, production:)
    raw = env.fetch(key)
    allow_localhost = !production
    uri = raw.to_s.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end

  private :host_family_origins, :origin
end
