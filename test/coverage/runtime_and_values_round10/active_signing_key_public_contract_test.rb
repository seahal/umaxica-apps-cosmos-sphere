# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_keyring"

class RuntimeAndValuesRound10ActiveSigningKeyPublicContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the active RP signing key matches the runtime public verification key" do
    issuer_id = "oidc_client:CORE_APP_JP"
    private_key = JitSecurityJwtKeyring.private_key_for_active(issuer_id)
    public_key = JitSecurityJwtKeyring.public_key_for_active(issuer_id)

    assert_instance_of OpenSSL::PKey::EC, private_key
    assert_predicate private_key, :private?
    assert_equal public_key.public_to_der, private_key.public_to_der
    token = JWT.encode({ "purpose" => "runtime-public-key-contract" }, private_key, "ES384")
    payload, = JWT.decode(token, public_key, true, algorithms: ["ES384"])

    assert_equal "runtime-public-key-contract", payload.fetch("purpose")
  end
end
