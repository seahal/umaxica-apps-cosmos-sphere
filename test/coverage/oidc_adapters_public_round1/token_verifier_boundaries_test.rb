# frozen_string_literal: true

require "test_helper"

class OidcAdaptersPublicTokenVerifierBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @issuer = "https://op.example.test"
    @now = Time.current.to_i
    @id_arguments = {
      id_token: nil,
      client_id: "core-app-jp",
      realm: "app",
      issuer: @issuer,
      expected_nonce: "expected-nonce",
      jwks_client: Minitest::Mock.new,
    }
    @access_arguments = {
      access_token: nil,
      client_id: "core-app-jp",
      realm: "app",
      issuer: @issuer,
      audience: "core-api",
      jwks_client: Minitest::Mock.new,
    }
    @payload = {
      "iss" => @issuer,
      "aud" => ["core-app-jp"],
      "exp" => @now + 300,
      "nbf" => @now - 1,
      "iat" => @now,
      "sub" => "subject",
      "nonce" => "expected-nonce",
      "jti" => "token-reference",
      "sid" => "session-reference",
      "typ" => "id-token+jwt",
      "act" => "client",
    }
  end

  test "configuration rejects missing identifiers unsupported realms and cross-realm cells" do
    [nil, "", " ", 1].each do |value|
      %i(client_id issuer).each do |field|
        assert_raises(ArgumentError) { OidcOpIdTokenVerifier.new(**@id_arguments.merge(field => value)) }
        assert_raises(ArgumentError) { OidcOpAccessTokenVerifier.new(**@access_arguments.merge(field => value)) }
      end
      assert_raises(ArgumentError) { OidcOpAccessTokenVerifier.new(**@access_arguments.merge(audience: value)) }
    end
    [nil, "", "com", "unknown"].each do |realm|
      assert_raises(ArgumentError) { OidcOpIdTokenVerifier.new(**@id_arguments.merge(realm:)) }
      assert_raises(ArgumentError) { OidcOpAccessTokenVerifier.new(**@access_arguments.merge(realm:)) }
    end
    assert_raises(ArgumentError) {
      OidcOpIdTokenVerifier.new(**@id_arguments.merge(expected_resource_type: "operator"))
    }
    assert_raises(ArgumentError) { OidcOpIdTokenVerifier.new(**@id_arguments.merge(client_id: "core-org-jp")) }
    assert_raises(ArgumentError) { OidcOpAccessTokenVerifier.new(**@access_arguments.merge(client_id: "core-org-jp")) }
    [-1, "-1", "bad", 1.5, Object.new].each do |expected_max_age|
      assert_raises(ArgumentError) { OidcOpIdTokenVerifier.new(**@id_arguments.merge(expected_max_age:)) }
    end
  end

  test "missing tokens fail before any JWKS lookup" do
    assert_equal "missing_id_token", OidcOpIdTokenVerifier.new(**@id_arguments).call.error
    assert_equal "missing_token", OidcOpAccessTokenVerifier.new(**@access_arguments).call.error
    @id_arguments.fetch(:jwks_client).verify
    @access_arguments.fetch(:jwks_client).verify
  end

  test "ID headers reject empty key identifiers and token-directed trust material before lookup" do
    [{ "kid" => nil }, { "kid" => "" }, { "jku" => "https://attacker.example/jwks" },
     { "alg" => "none" },].each do |extra|
      header = { "kid" => "known", "typ" => "id-token+jwt" }.merge(extra)
      token = JWT.encode(@payload, @key, "ES384", header)
      result = OidcOpIdTokenVerifier.new(**@id_arguments.merge(id_token: token)).call

      assert_equal "invalid_header", result.error
      assert_nil result.payload
    end
    @id_arguments.fetch(:jwks_client).verify
  end

  test "ID key lookup preserves unavailable versus unknown classification" do
    token = JWT.encode(@payload, @key, "ES384", { "kid" => "known", "typ" => "id-token+jwt" })
    { unavailable: ["key_unavailable", "jwks_unavailable"],
      invalid: ["invalid_id_token", "kid_not_found"], }.each do |status, expected|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status:, key: nil, reason: "fixture"), ["known"])
      result = OidcOpIdTokenVerifier.new(**@id_arguments.merge(id_token: token, jwks_client: jwks)).call

      assert_equal expected, [result.error, result.detail]
      assert_nil result.payload
      jwks.verify
    end
  end

  test "ID claim types exact audience and authentication freshness remain enforced after signature verification" do
    cases = [
      [@payload.merge("sub" => ""), "string_claims"],
      [@payload.merge("iat" => @now.to_f), "time_claims"],
      [@payload.merge("aud" => "core-app-jp"), "aud"],
      [@payload.merge("typ" => "at+jwt"), "typ"],
      [@payload.merge("nonce" => "short"), "nonce"],
      [@payload.merge("auth_time" => "recent"), "auth_time"],
      [@payload.merge("auth_time" => @now + 31), "auth_time"],
    ]
    cases.each do |payload, detail|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["known"])
      token = JWT.encode(payload, @key, "ES384", { "kid" => "known", "typ" => "id-token+jwt" })
      result = OidcOpIdTokenVerifier.new(**@id_arguments.merge(id_token: token, jwks_client: jwks)).call

      assert_equal detail, result.detail
      assert_not_predicate result, :success?
      assert_nil result.payload
      jwks.verify
    end
  end

  test "ID freshness accepts the leeway boundary and rejects the nearest stale second" do
    travel_to(Time.zone.at(@now)) do
      { 89 => true, 90 => true, 91 => false }.each do |age, expected|
        jwks = Minitest::Mock.new
        jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["known"])
        token = JWT.encode(
          @payload.merge("auth_time" => @now - age), @key, "ES384",
          { "kid" => "known", "typ" => "id-token+jwt" },
        )
        result = OidcOpIdTokenVerifier.new(
          **@id_arguments.merge(id_token: token, jwks_client: jwks, expected_max_age: "60"),
        ).call

        assert_equal expected, result.success?, "authentication age #{age} seconds"
        jwks.verify
      end
    end
  end

  test "access profile refuses scalar audiences forbidden aliases blank claims and fractional times" do
    payload = @payload.except("typ", "act", "nonce").merge(
      "aud" => ["core-api"], "client_id" => "core-app-jp", "scope" => "openid", "authn_ctx" => "normal",
    )
    [payload.merge("aud" => "core-api"), payload.merge("scp" => "openid"),
     payload.merge("sub" => ""), payload.merge("iat" => @now.to_f),].each do |claims|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["known"])
      token = JWT.encode(claims, @key, "ES384", { "kid" => "known", "typ" => "at+jwt" })
      result = OidcOpAccessTokenVerifier.new(**@access_arguments.merge(access_token: token, jwks_client: jwks)).call

      assert_equal "invalid_token", result.error
      assert_nil result.payload
      jwks.verify
    end
  end
end
