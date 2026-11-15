# typed: false
# frozen_string_literal: true

require "test_helper"

class RpAuthenticationPublicRoundFourteenForeignIssuerAnchorRejectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an RP session anchored to another issuer cannot authenticate with the active issuer token" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    subject = "foreign-issuer-anchor-subject"
    sid = "foreign-issuer-anchor-session"
    enrollment = RpCallbackCommitter.call(
      cell:, issuer: "https://retired-issuer.example", subject:, sid:,
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?

    key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.current.to_i
    access_token = JWT.encode(
      {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => subject,
        "sid" => sid,
        "client_id" => cell.client_id,
        "jti" => "foreign-issuer-anchor-token",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      },
      key,
      "PS256",
      { "kid" => "foreign-issuer-anchor-key", "alg" => "PS256", "typ" => "at+jwt" },
    )
    jwks_client = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "foreign-issuer-anchor-key")] } },
    )

    result = RpRequestAuthenticator.call(
      cell:, access_token:, local_session_id: enrollment.session.public_id, issuer:, jwks_client:,
    )

    assert_equal :invalid, result.status
    assert_nil result.principal
    assert_nil result.session
    assert_nil result.payload
  end
end
