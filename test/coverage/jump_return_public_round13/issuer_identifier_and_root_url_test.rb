# frozen_string_literal: true

require "test_helper"

class JumpReturnPublicRoundThirteenIssuerIdentifierAndRootUrlTest < ActiveSupport::TestCase
  test "invalid public return identifiers are rejected before signing" do
    [nil, "", "bad\nidentifier", "j" * (JumpRtIssuer::MAX_JTI_LENGTH + 1), 7].each do |jti|
      assert_nil JumpRtIssuer.call(
        namespace: "BASE_APP",
        url: "https://target.example/path",
        dst: "internal",
        ttl: 30,
        jti:,
      ), jti.inspect
    end
  end

  test "an HTTPS origin without a path is signed with the canonical root path" do
    key = OpenSSL::PKey::RSA.generate(3072)
    now = Time.zone.at(1_800_000_000)
    token = nil

    JumpRtKeyring.stub(:active_kid, "coverage-root-url") do
      JumpRtKeyring.stub(:private_key, key) do
        token = JumpRtIssuer.call(
          namespace: "BASE_APP",
          url: "https://target.example",
          dst: "internal",
          ttl: 30,
          now:,
          jti: "coverage-root-url-jti",
        )
      end
    end

    payload, = JWT.decode(token, nil, false)

    assert_equal "https://target.example/", payload.fetch("url")
    assert_equal now.to_i, payload.fetch("iat")
    assert_equal now.to_i + 30, payload.fetch("exp")
  end
end
