# typed: false
# frozen_string_literal: true

require "jwt"
require "openssl"

module JitSecurityJwtJwk
  module_function

  ALGORITHM = "PS256"
  MINIMUM_RSA_BITS = 3072
  REQUIRED_PUBLIC_FIELDS = %w(kty kid alg use n e).freeze
  PRIVATE_FIELDS = %w(d p q dp dq qi oth k).freeze

  Error = Class.new(StandardError)

  def normalize_public(entry)
    raise Error, "entry must be a JSON object" unless entry.is_a?(Hash)

    source_hash = entry.stringify_keys
    if PRIVATE_FIELDS.any? { |field| source_hash.key?(field) }
      raise Error, "entry #{source_hash["kid"].inspect} contains private JWK material"
    end

    jwk = source_hash.slice(*(REQUIRED_PUBLIC_FIELDS + ["state"]))
    validate_public!(jwk)
    jwk
  end

  def validate_public!(jwk)
    missing = REQUIRED_PUBLIC_FIELDS.reject { |field| jwk[field].present? }
    raise Error, "public JWK is missing #{missing.join(", ")}" if missing.present?
    raise Error, "public JWK alg must be #{ALGORITHM}" unless jwk["alg"] == ALGORITHM
    raise Error, "public JWK use must be sig" unless jwk["use"] == "sig"
    raise Error, "public JWK kty must be RSA" unless jwk["kty"] == "RSA"

    import_public_key(jwk)
  end

  def export_public(key, kid:)
    unless key.is_a?(OpenSSL::PKey::RSA) && key.n.num_bits >= MINIMUM_RSA_BITS
      raise Error, "signing key must be RSA with at least #{MINIMUM_RSA_BITS} bits"
    end

    JWT::JWK.new(key, kid: kid).export.stringify_keys.except(*PRIVATE_FIELDS).merge(
      "alg" => ALGORITHM,
      "use" => "sig",
    )
  end

  def import_public_key(jwk)
    key = JWT::JWK.import(jwk.except("state")).public_key
    raise Error, "public JWK key must be RSA" unless key.is_a?(OpenSSL::PKey::RSA)
    unless key.n.num_bits >= MINIMUM_RSA_BITS
      raise Error, "public JWK RSA modulus must be at least #{MINIMUM_RSA_BITS} bits"
    end

    key
  rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError => e
    raise Error, "contains invalid public JWK material: #{e.class.name}"
  end
end
