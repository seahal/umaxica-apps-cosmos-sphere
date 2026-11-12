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

  test "a syntactically valid RSA PEM cannot be substituted for an EC signing key" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    pem = rsa.to_pem
    error =
      assert_raises(JitSecurityJwtKeyMaterial::Error) do
        JitSecurityJwtKeyMaterial.decode_private_key(pem)
      end

    assert_equal "must be an EC private key", error.message
    assert_not_includes error.message, pem
  end
end
