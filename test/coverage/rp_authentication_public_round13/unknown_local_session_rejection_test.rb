# frozen_string_literal: true

require "test_helper"

class RpAuthenticationPublicRoundThirteenUnknownLocalSessionRejectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a valid Access JWT cannot authenticate without a matching RP local session" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = "https://www.umaxica.app"
    key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    token = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => "unknown-session-subject",
        "sid" => "unknown-session-sid",
        "client_id" => cell.client_id,
        "jti" => "unknown-session-token",
        "scope" => "openid",
        "authn_ctx" => "normal",
      },
      key,
      "PS256",
      { "kid" => "unknown-session-key", "alg" => "PS256", "typ" => "at+jwt" },
    )
    jwks_client = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "unknown-session-key")] } },
      limiter: OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current }),
    )

    result = RpRequestAuthenticator.call(
      cell:,
      access_token: token,
      local_session_id: "missing-local-session",
      issuer:,
      jwks_client:,
    )

    assert_equal :invalid, result.status
    assert_nil result.principal
    assert_nil result.session
    assert_nil result.payload
  end
end
