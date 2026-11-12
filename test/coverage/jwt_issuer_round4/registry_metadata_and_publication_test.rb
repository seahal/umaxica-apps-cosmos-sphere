# frozen_string_literal: true

require "test_helper"

class RegistryMetadataAndPublicationTest < ActiveSupport::TestCase
  test "a signer with keys but no active identifier is rejected before key selection" do
    record = JitSecurityJwtRegistry.auth.with(current_kid: "")
    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.validate_record!(record)
      end
    assert_includes error.message, "active kid is missing"
  end

  test "a deployable active signer cannot publish a fixture key as a grace verifier" do
    original = JitSecurityJwtRegistry.auth
    active = original.keys.fetch(original.current_kid)
    deployed = active.with(kid: "deployed-active", public_jwk: active.public_jwk.merge("kid" => "deployed-active"))
    fixture = active.with(
      kid: "fixture-grace", state: "grace",
      public_jwk: active.public_jwk.merge("kid" => "fixture-grace"),
    )
    candidate = original.with(
      current_kid: "deployed-active",
      keys: { "deployed-active" => deployed,
              "fixture-grace" => fixture, },
    )
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
      error =
        assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
          JitSecurityJwtRegistry.validate_record!(candidate)
        end
      assert_includes error.message, "must not contain reserved environment markers"
    end
  end

  test "published Jump keys cannot give distinct real key material the same public identifier" do
    records = JitSecurityJwtRegistry.issuers
    original = records.fetch("surface:CORE_APP")
    current = original.keys.fetch(original.current_kid)
    other_key = OpenSSL::PKey::EC.generate("secp384r1")
    other_jwk = JitSecurityJwtJwk.export_public(other_key, kid: original.current_kid)
    other = KeyRecord.new(
      kid: "grace-key", private_key: nil, public_key: OpenSSL::PKey.read(other_key.public_to_pem),
      public_jwk: other_jwk, state: "grace",
    )
    candidate = original.with(keys: { original.current_kid => current, "grace-key" => other })
    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
      end
    assert_includes error.message, "published Jump JWKS contains duplicate kid values"
  end

  test "a private issuer key can derive its public JWKS when no separate publication is supplied" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    credentials = Minitest::Mock.new
    credentials.expect(:option, nil, ["JWT_CORE_APP_PUBLIC_KEYSET"])
    source = JitSecurityJwtKeySource.new(
      env: { "JWT_CORE_APP_ACTIVE_KID" => "round4-derived",
             "JWT_CORE_APP_PRIVATE_KEY" => Base64.strict_encode64(key.to_der), }, credentials: credentials,
    )
    issuer = JitSecurityJwtRegistry.build_surface_issuer("CORE_APP", source: source)

    assert_equal "round4-derived", issuer.current_kid
    assert_equal ["round4-derived"], issuer.jwks.fetch(:keys).pluck("kid")
    assert_equal key.public_to_der, issuer.current_key.public_key.public_to_der
    credentials.verify
  end

  test "a serialized JWKS scalar is rejected instead of becoming a verification publication" do
    source = JitSecurityJwtKeySource.new(
      env: { "JWT_CORE_APP_PUBLIC_KEYSET" => "1",
             "JWT_CORE_APP_ACTIVE_KID" => "round4-scalar",
             "JWT_CORE_APP_PRIVATE_KEY" => "invalid-key", },
      credentials: Minitest::Mock.new,
    )
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
      JitSecurityJwtRegistry.build_surface_issuer("CORE_APP", source: source)
    end
  end
end
