# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_keyring"

class RuntimeAndValuesRound10ActiveSigningKeyPublicContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the active RP signing key matches the runtime public verification key" do
    issuer_id = "oidc_client:CORE_APP_JP"
    private_key = JitSecurityJwtKeyring.private_key_for_active(issuer_id)
    public_key = JitSecurityJwtKeyring.public_key_for_active(issuer_id)

    assert_instance_of OpenSSL::PKey::RSA, private_key
    assert_equal 3072, private_key.n.num_bits
    assert_predicate private_key, :private?
    assert_equal public_key.public_to_der, private_key.public_to_der
    token = JWT.encode({ "purpose" => "runtime-public-key-contract" }, private_key, "PS256")
    payload, = JWT.decode(token, public_key, true, algorithms: ["PS256"])

    assert_equal "runtime-public-key-contract", payload.fetch("purpose")
  end
end
