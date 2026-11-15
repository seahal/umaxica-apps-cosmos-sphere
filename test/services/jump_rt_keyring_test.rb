# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtKeyringTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::RSA.generate(3072)
  end

  test "delegates active kid and private key lookup to the registry" do
    issuer = Struct.new(:id, :current_kid).new("issuer-id", "kid-123")

    JitSecurityJwtRegistry.stub(:surface, issuer) do
      JitSecurityJwtRegistry.stub(:private_key_for, @private_key) do
        assert_equal "kid-123", JumpRtKeyring.active_kid("AUTH_APP")
        assert_equal @private_key, JumpRtKeyring.private_key("AUTH_APP")
      end
    end
  end

  test "decode_private_key accepts PEM and DER encoded RSA keys and rejects invalid input" do
    pem = @private_key.private_to_pem
    der = Base64.strict_encode64(@private_key.private_to_der)

    assert_instance_of OpenSSL::PKey::RSA, JumpRtKeyring.decode_private_key(pem)
    assert_instance_of OpenSSL::PKey::RSA, JumpRtKeyring.decode_private_key(der)
    assert_nil JumpRtKeyring.decode_private_key(nil)
    assert_nil JumpRtKeyring.decode_private_key("")
    assert_nil JumpRtKeyring.decode_private_key("not-a-key")
  end

  test "decode_private_key rejects EC and undersized RSA keys in PEM form" do
    ec_pem = OpenSSL::PKey::EC.generate("secp384r1").private_to_pem
    undersized_rsa_pem = OpenSSL::PKey::RSA.generate(2048).private_to_pem

    assert_nil JumpRtKeyring.decode_private_key(ec_pem)
    assert_nil JumpRtKeyring.decode_private_key(undersized_rsa_pem)
  end
end
