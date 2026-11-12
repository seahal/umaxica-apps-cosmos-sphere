# frozen_string_literal: true

require "test_helper"

class ResolversAndAuthValuesRound5RpAnchorIssuerBindingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a verified token cannot authenticate a stored OP anchor belonging to another issuer" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = "https://op.example.test"
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "round5-subject", sid: "round5-session", absolute_expires_at: 1.hour.from_now,
    )
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    payload = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now,
      "sub" => "round5-subject",
      "sid" => "round5-session",
      "client_id" => cell.client_id,
      "jti" => "round5-reference",
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
    access_token = JWT.encode(payload, key, "ES384", { "kid" => "round5-key", "typ" => "at+jwt" })
    limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: -> { Time.current })
    keys = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "round5-key")] } }, limiter:,
    )
    valid = RpRequestAuthenticator.call(
      cell:, access_token:, local_session_id: enrollment.session.public_id, issuer:, jwks_client: keys,
    )

    assert_predicate valid, :authenticated?
    RpCoreAppOpSessionBinding.find(enrollment.session.op_session_binding_id)
      .update_columns(issuer: "https://different-op.example.test")
    rejected = RpRequestAuthenticator.call(
      cell:, access_token:, local_session_id: enrollment.session.public_id, issuer:, jwks_client: keys,
    )

    assert_equal :invalid, rejected.status
    assert_nil rejected.principal
    assert_nil rejected.session
    assert_nil rejected.payload
  end
end
