# frozen_string_literal: true

require "test_helper"

class OidcAdaptersPublicLogoutTokenBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @issuer = "https://op.example.test"
    @now = Time.current.to_i
    @payload = {
      "iss" => @issuer,
      "aud" => ["core-app-jp"],
      "iat" => @now,
      "exp" => @now + 300,
      "jti" => "logout-reference",
      "sid" => "session-reference",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
  end

  test "an unknown key and an unavailable key remain distinguishable public results" do
    token = JWT.encode(@payload, @key, "ES384", { "kid" => "known", "typ" => "logout+jwt" })
    { invalid: "invalid_token", unavailable: "key_unavailable" }.each do |status, error|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status:, key: nil, reason: "fixture"), ["known"])
      result = OidcOpLogoutTokenVerifier.new(
        logout_token: token, client_id: "core-app-jp", issuer: @issuer,
        jwks_client: jwks,
      ).call

      assert_equal error, result.error
      assert_equal(status == :unavailable, result.key_unavailable?)
      assert_nil result.payload
      jwks.verify
    end
  end

  test "signed logout rejects multiple audiences malformed event markers empty bindings and excessive lifetime" do
    claims = [@payload.merge("aud" => ["core-app-jp", "another-rp"]),
              @payload.merge("events" => []), @payload.merge("events" => { OidcOpLogoutTokenVerifier::EVENT => true }),
              @payload.merge("sid" => ""), @payload.merge("sid" => 1), @payload.merge("jti" => ""),
              @payload.merge("exp" => @now), @payload.merge("exp" => @now + 301),]
    claims.each do |payload|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["known"])
      token = JWT.encode(payload, @key, "ES384", { "kid" => "known", "typ" => "logout+jwt" })
      result = OidcOpLogoutTokenVerifier.new(
        logout_token: token, client_id: "core-app-jp", issuer: @issuer,
        jwks_client: jwks,
      ).call

      assert_not_predicate result, :success?
      assert_equal "invalid_token", result.error
      assert_nil result.payload
      jwks.verify
    end
  end

  test "logout lifetime accepts the nearest valid boundary values" do
    [299, 300].each do |lifetime|
      jwks = Minitest::Mock.new
      jwks.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["known"])
      token = JWT.encode(
        @payload.merge("exp" => @now + lifetime), @key, "ES384",
        { "kid" => "known", "typ" => "logout+jwt" },
      )
      result = OidcOpLogoutTokenVerifier.new(
        logout_token: token, client_id: "core-app-jp", issuer: @issuer,
        jwks_client: jwks,
      ).call

      assert_predicate result, :success?
      assert_nil result.error
      assert_not_predicate result, :key_unavailable?
      jwks.verify
    end
  end
end
