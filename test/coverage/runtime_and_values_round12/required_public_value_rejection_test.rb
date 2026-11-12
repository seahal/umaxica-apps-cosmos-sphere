# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_keyring"

class RuntimeAndValuesRound12RequiredPublicValueRejectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an origin with an HTTPS scheme but no host is rejected by the public parsers" do
    assert_raises(ArgumentError) { ConfigValues.build("https://") }
    assert_raises(ArgumentError) { ConfigValues.public_https_origin("https://") }
    assert_raises(ArgumentError) { Oidc::AcmeServiceOrigin.from("https://", default_scheme: "https") }
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://")
  end

  test "JWT publication requires the caller to name its JOSE token family" do
    [nil, "", " "].each do |typ|
      error =
        assert_raises(ArgumentError) do
          JitSecurityJwtKeyring.encode({ "sub" => "public-reference" }, typ:, issuer_id: "oidc_client:CORE_APP_JP")
        end

      assert_equal "JOSE typ is required", error.message
    end
  end

  test "the runtime store cannot be initialized with an absent namespace even with an injected client" do
    [nil, "", " "].each do |namespace|
      error =
        assert_raises(Umaxica::Valkey::ConfigurationError) do
          Umaxica::Valkey::Connection.new(url: "redis://unconnected.example/3", namespace:, client: Object.new)
        end

      assert_equal "Valkey namespace is required", error.message
    end
  end
end
