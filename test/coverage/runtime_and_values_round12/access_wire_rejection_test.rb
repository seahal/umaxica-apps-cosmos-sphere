# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound12AccessWireRejectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @key = OpenSSL::PKey::RSA.generate(3072)
    @issuer = "https://op.example.test"
    now = Time.current.to_i
    @payload = {
      "iss" => @issuer,
      "aud" => ["core-app-jp"],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now,
      "sub" => "subject",
      "sid" => "session",
      "client_id" => "core-app-jp",
      "jti" => "round12-reference",
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
  end

  test "absent blank and non-string key identifiers are refused without a JWKS lookup" do
    [nil, "", " ", 1, []].each do |kid|
      keys = Minitest::Mock.new
      token = JWT.encode(@payload, @key, "PS256", { "alg" => "PS256", "typ" => "at+jwt", "kid" => kid })
      result = OidcOpAccessTokenVerifier.new(
        access_token: token, client_id: "core-app-jp", realm: "app", issuer: @issuer,
        audience: "core-app-jp", jwks_client: keys,
      ).call

      assert_equal "invalid_header", result.error
      assert_nil result.payload
      keys.verify
    end
  end

  test "a signed token with an unknown nonblank authentication context is never authenticated" do
    token = JWT.encode(
      @payload.merge("authn_ctx" => "unregistered-round12"), @key, "PS256",
      { "alg" => "PS256", "typ" => "at+jwt", "kid" => "round12-key" },
    )
    keys = Minitest::Mock.new
    keys.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key: @key, reason: nil), ["round12-key"])
    result = OidcOpAccessTokenVerifier.new(
      access_token: token, client_id: "core-app-jp", realm: "app", issuer: @issuer,
      audience: "core-app-jp", jwks_client: keys,
    ).call

    assert_not_predicate result, :success?
    assert_equal "invalid_token", result.error
    assert_nil result.payload
    keys.verify
  end
end
