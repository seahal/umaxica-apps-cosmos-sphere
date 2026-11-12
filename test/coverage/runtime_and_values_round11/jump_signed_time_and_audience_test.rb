# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound11JumpSignedTimeAndAudienceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "signed claims must satisfy local audience and timestamp ordering even inside JWT leeway" do
    now = Time.current.change(usec: 0)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "round11-#{SecureRandom.hex(8)}"
    jwk = JitSecurityJwtJwk.export_public(key, kid:)
    base = JumpRtSurface.issuer_origin("BASE_APP")
    source = JumpRtSurface.issuer_origin("VISA_APP")
    target = "#{base}/dashboard"
    payload = {
      "schema" => 1,
      "iss" => Rails.configuration.x.boot_config.fetch(:jump).origin,
      "aud" => base,
      "sub" => "jump-redirect",
      "iat" => now.to_i - 30,
      "nbf" => now.to_i - 30,
      "exp" => now.to_i - 1,
      "jti" => "jump-round11",
      "src" => source,
      "dst" => "internal",
      "rpl" => "reuse",
      "url" => target,
    }
    cases = [
      [payload, [true, nil]],
      [payload.merge("aud" => [base]), [false, "invalid_claim"]],
      [payload.merge("nbf" => now.to_i), [false, "invalid_claim"]],
    ]
    travel_to(now) do
      cases.each do |claims, expected|
        token = JWT.encode(claims, key, "ES384", { "kid" => kid, "typ" => "JWT" })
        result = JumpRtReturnVerifier.call(
          token:, request_url: "#{target}?rt=#{token}", request_base_url: base,
          fetcher: -> { { "keys" => [jwk] } }, now:,
        )

        assert_equal expected, [result.success?, result.error]
      end
    end
  end
end
