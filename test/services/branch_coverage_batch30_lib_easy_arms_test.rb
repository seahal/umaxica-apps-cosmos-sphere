# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJwk normalize_public and validate_public arms" do
    key = OpenSSL::PKey::RSA.generate(3072)
    valid = JitSecurityJwtJwk.export_public(key, kid: "arm-kid")
    ec_key = OpenSSL::PKey::EC.generate("secp384r1")
    ec_jwk = JWT::JWK.new(ec_key, kid: "ec-kid").export.stringify_keys.except(
      *JitSecurityJwtJwk::PRIVATE_FIELDS,
    ).merge("alg" => "PS256", "use" => "sig")

    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public(valid.merge("d" => "private")) }
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.validate_public!(valid.except("n")) }
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.validate_public!(valid.merge("alg" => "PS384")) }
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.validate_public!(valid.merge("use" => "enc")) }
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.validate_public!(ec_jwk) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(valid.merge("n" => Base64.urlsafe_encode64("\x00" * 384, padding: false)))
    end
  end
end
