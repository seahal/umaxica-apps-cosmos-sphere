# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound11OidcSignedClaimRejectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "state verification rejects an unknown kid without trusting the signing claim" do
    client_id = "core-app-jp"
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    issuer_id = "oidc_client:#{namespace}"
    state, = OidcStateJwt.issue(client_id:, target_link_uri: "/dashboard")
    payload, = JWT.decode(state, nil, false)
    private_key = JitSecurityJwtKeyring.private_key_for_active(issuer_id)
    unknown = JWT.encode(
      payload, private_key, "ES384",
      { "kid" => "never-registered-round11", "typ" => OidcStateJwt::TOKEN_TYPE },
    )
    result = OidcStateJwt.verify(client_id:, token: unknown)

    assert_not_predicate result, :valid?
    assert_equal "unknown_key", result.reason
    assert_nil result.jti
    assert_nil result.target_link_uri
  end

  test "a correctly signed state cannot opt into an unsupported schema version" do
    client_id = "core-app-jp"
    issuer_id = "oidc_client:#{OidcClientRegistry.jwt_namespace_for(client_id)}"
    state, = OidcStateJwt.issue(client_id:, target_link_uri: "/dashboard")
    payload, = JWT.decode(state, nil, false)
    version_two = JitSecurityJwtKeyring.encode(
      payload.merge("v" => 2), typ: OidcStateJwt::TOKEN_TYPE, issuer_id:,
    )
    result = OidcStateJwt.verify(client_id:, token: version_two)

    assert_not_predicate result, :valid?
    assert_equal "unsupported_version", result.reason
    assert_nil result.jti
    assert_nil result.target_link_uri
  end

  test "logout expiry encoded as a numeric string cannot bypass the local numeric claim contract" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    issuer = "https://op.example.test"
    now = Time.current.to_i
    payload = {
      "iss" => issuer,
      "aud" => ["core-app-jp"],
      "iat" => now,
      "exp" => (now + 300).to_s,
      "jti" => "logout-round11",
      "sid" => "session-round11",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    header = { "kid" => "round11-key", "typ" => "logout+jwt", "alg" => "ES384" }
    segments = [header, payload].map { |value| Base64.urlsafe_encode64(JSON.generate(value), padding: false) }
    signing_input = segments.join(".")
    signature = JWT::JWA::Ecdsa.new("ES384", "SHA384").sign(data: signing_input, signing_key: key)
    token = "#{signing_input}.#{Base64.urlsafe_encode64(signature, padding: false)}"
    keys = Minitest::Mock.new
    keys.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil), ["round11-key"])
    result = OidcOpLogoutTokenVerifier.new(
      logout_token: token, client_id: "core-app-jp", issuer:,
      jwks_client: keys,
    ).call

    assert_not_predicate result, :success?
    assert_equal "invalid_token", result.error
    assert_nil result.payload
    keys.verify
  end
end
