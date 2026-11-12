# typed: false
# frozen_string_literal: true

# Core bridge models remain in place until the separate model and database removal step.
class RpDeploymentBindingValue
  REGIONS = %w(jp us).freeze
  SPHERE_RP_FAMILY_REALMS = %w(core-app core-org warp-app warp-org palm-app).freeze

  class UnknownRegion < ArgumentError; end

  class UnknownRp < KeyError; end

  class << self
    public

    def client_id(family_realm)
      key = family_realm.to_s
      raise UnknownRp, "unknown RP family/realm: #{key.inspect}" unless SPHERE_RP_FAMILY_REALMS.include?(key)

      region = ENV.fetch("UMAXICA_DEPLOYMENT_REGION")
      raise UnknownRegion, "unknown deployment region: #{region.inspect}" unless REGIONS.include?(region)

      "#{key}-#{region}"
    end
  end
end
