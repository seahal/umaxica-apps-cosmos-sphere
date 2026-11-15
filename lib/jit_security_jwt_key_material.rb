# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "jit_security_jwt_jwk"

module JitSecurityJwtKeyMaterial
  module_function

  Error = Class.new(StandardError)

  def parse_private_keyset(raw)
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    raise Error, "must be a JSON object" unless parsed.is_a?(Hash)

    parsed.transform_values { |value| decode_private_key(value) }.compact
  rescue JSON::ParserError => e
    raise Error, "contains invalid JSON: #{e.message}"
  end

  def decode_private_key(value)
    return nil if value.blank?

    raw = value.to_s
    key = raw.include?("BEGIN") ? OpenSSL::PKey.read(raw) : OpenSSL::PKey.read(Base64.decode64(raw))
    unless key.is_a?(OpenSSL::PKey::RSA) && key.private? &&
        key.n.num_bits >= JitSecurityJwtJwk::MINIMUM_RSA_BITS
      raise Error,
            "must be an RSA private key with at least #{JitSecurityJwtJwk::MINIMUM_RSA_BITS} bits"
    end

    key
  rescue OpenSSL::PKey::PKeyError, ArgumentError => e
    raise Error, "contains invalid RSA key material: #{e.class.name}"
  end
end
