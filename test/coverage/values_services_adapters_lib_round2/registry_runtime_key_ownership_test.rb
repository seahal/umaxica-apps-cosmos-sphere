# frozen_string_literal: true

require "test_helper"

class RegistryRuntimeKeyOwnershipTest < ActiveSupport::TestCase
  test "public verification keys remain usable without sibling RP private signing authority" do
    RuntimeRole.stub(:current, "rp-core-app-jp") do
      %w(auth preference_app preference_org surface:WARP_APP oidc_client:WARP_APP_JP).each do |id|
        record = JitSecurityJwtRegistry.issuer(id)
        public_only = record.with(keys: record.keys.transform_values { |key| key.with(private_key: nil) })
        assert_nothing_raised { JitSecurityJwtRegistry.validate_record!(public_only) }
        assert_not_nil public_only.public_key_for(public_only.current_kid)
      end
      %w(surface:CORE_APP oidc_client:CORE_APP_JP).each do |id|
        record = JitSecurityJwtRegistry.issuer(id)
        public_only = record.with(keys: record.keys.transform_values { |key| key.with(private_key: nil) })
        error =
          assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
            JitSecurityJwtRegistry.validate_record!(public_only)
          end
        assert_includes error.message, "active private key is missing"
      end
      record = JitSecurityJwtRegistry.auth
      invalid = record.with(id: "unsupported", keys: record.keys.transform_values { |key| key.with(private_key: nil) })
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(invalid) }
    end
  end

  test "active signer presence revocation publication and valid state are independently enforced" do
    record = JitSecurityJwtRegistry.auth
    active = record.keys.fetch(record.current_kid)
    invalid_jwk = active.with(public_jwk: active.public_jwk.merge("alg" => "RS256"))
    cases = [
      [record.with(keys: record.keys.except(record.current_kid)), "active key"],
      [record.with(revoked_kids: Set[record.current_kid]), "is revoked"],
      [record.with(keys: record.keys.merge(record.current_kid => active.with(state: "retired"))), "missing from JWKS"],
      [
        record.with(keys: record.keys.merge(record.current_kid => invalid_jwk)),
        "public JWK alg",
      ],
      [
        record.with(
          keys: record.keys.merge(
            "unknown-state-key" => active.with(
              kid: "unknown-state-key",
              state: "unknown",
            ),
          ),
        ), "invalid key state",
      ],
    ]
    cases.each do |candidate, reason|
      error =
        assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
          JitSecurityJwtRegistry.validate_record!(candidate)
        end
      assert_includes error.message, reason
    end
  end

  test "public-only active keys require private material in a shared signing process" do
    record = JitSecurityJwtRegistry.auth
    candidate = record.with(keys: record.keys.transform_values { |key| key.with(private_key: nil) })
    RuntimeRole.stub(:current, "shared") do
      error =
        assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
          JitSecurityJwtRegistry.validate_record!(candidate)
        end
      assert_includes error.message, "active private key is missing"
    end
  end

  test "published Jump key identifiers enforce UTF16 length and control character partitions" do
    records = JitSecurityJwtRegistry.issuers
    original = records.fetch("surface:CORE_APP")
    active = original.keys.fetch(original.current_kid)
    [127, 128, 129].each do |length|
      kid = "q" * length
      replacement = active.with(kid: kid, public_jwk: active.public_jwk.merge("kid" => kid))
      candidate = original.with(current_kid: kid, keys: { kid => replacement })
      if length <= 128
        assert JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
      else
        error =
          assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
            JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
          end
        assert_includes error.message, "at most 128 UTF-16 units"
      end
    end
    ["unsafe\nkey", "unsafe\u007Fkey"].each do |kid|
      replacement = active.with(kid: kid, public_jwk: active.public_jwk.merge("kid" => kid))
      candidate = original.with(current_kid: kid, keys: { kid => replacement })
      error =
        assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
          JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
        end
      assert_includes error.message, "safe string"
    end
  end

  test "Jump published key counts preserve the upper rotation boundary" do
    records = JitSecurityJwtRegistry.issuers
    original = records.fetch("surface:CORE_APP")
    active = original.keys.fetch(original.current_kid)
    [3, 4, 5].each do |count|
      keys = (1...count).to_h do |index|
        kid = "rotation-#{index}"
        [kid, active.with(kid: kid, state: "grace", public_jwk: active.public_jwk.merge("kid" => kid))]
      end.merge(original.current_kid => active)
      candidate = original.with(keys: keys)
      if count <= 4
        assert JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
      else
        error =
          assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
            JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
          end
        assert_includes error.message, "1..4 keys"
      end
    end
  end
  test "APP and ORG preference issuers cannot share the same signing key material" do
    records = JitSecurityJwtRegistry.issuers
    app = records.fetch("preference_app")
    org = records.fetch("preference_org")
    app_key = app.keys.fetch(app.current_kid)
    org_key = org.keys.fetch(org.current_kid)
    shared = org_key.with(
      private_key: app_key.private_key, public_key: app_key.public_key,
      public_jwk: app_key.public_jwk.merge("kid" => org.current_kid),
    )
    candidate = org.with(keys: { org.current_kid => shared })

    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.validate!(records.merge(org.id => candidate))
      end
    assert_includes error.message, "key material is shared"
  end

  test "Jump issuer records with no published key are rejected" do
    records = JitSecurityJwtRegistry.issuers
    original = records.fetch("surface:CORE_APP")
    candidate = original.with(current_kid: "", keys: {})

    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.validate!(records.merge(original.id => candidate))
      end
    assert_includes error.message, "1..4 keys"
  end

  test "public issuer builders reject malformed serialized signing and verification material" do
    source = JitSecurityJwtKeySource.new(
      env: { "PRIVATE" => "not-json", "PUBLIC" => "not-json" },
      credentials: Minitest::Mock.new,
    )
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
      JitSecurityJwtRegistry.build_keyset_issuer(
        source: source, id: "isolated", private_keyset_name: "PRIVATE",
        public_keyset_name: "PUBLIC", active_kid: "isolated",
        issuer: "https://issuer.example", audiences: ["audience"],
        revoked_kids: [],
      )
    end
    source = JitSecurityJwtKeySource.new(env: { "JWT_CORE_APP_PUBLIC_KEYSET" => "{" }, credentials: Minitest::Mock.new)
    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.build_surface_issuer("CORE_APP", source: source)
      end
    assert_includes error.message, "invalid JSON"
  end
end
