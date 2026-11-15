# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_key_material"

class RuntimeAndValuesRound9PrivateKeyMaterialParserTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "blank optional key material has an explicit empty parser result without constructing a key" do
    [nil, "", " "].each do |raw|
      assert_empty JitSecurityJwtKeyMaterial.parse_private_keyset(raw)
      assert_nil JitSecurityJwtKeyMaterial.decode_private_key(raw)
    end
  end

  test "a 2048-bit RSA PEM is rejected below the PS256 signing-key minimum" do
    rsa = OpenSSL::PKey::RSA.generate(2048)
    pem = rsa.private_to_pem
    error =
      assert_raises(JitSecurityJwtKeyMaterial::Error) do
        JitSecurityJwtKeyMaterial.decode_private_key(pem)
      end

    assert_equal "must be an RSA private key with at least 3072 bits", error.message
    assert_not_includes error.message, pem
  end
end
