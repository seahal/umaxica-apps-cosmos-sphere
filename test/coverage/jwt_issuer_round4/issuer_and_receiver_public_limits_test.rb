# frozen_string_literal: true

require "test_helper"

class IssuerAndReceiverPublicLimitsTest < ActiveSupport::TestCase
  test "invalid URL partitions fail before a signing key is requested" do
    invalid_encoding = "https://target.example/".b + "\xFF".b
    invalid_encoding.force_encoding(Encoding::UTF_8)
    urls = [nil, "", " ", invalid_encoding, "https://target.example/\u007F", "https:///path",
            "https://%65xample.com/", "https://user:secret@target.example/", "https://target.example/#fragment",
            "https://target.example/a b",]

    urls.each do |url|
      assert_nil JumpRtIssuer.call(namespace: "CORE_APP", url: url, dst: "internal")
    end
  end

  test "real signed token serialization honors the nearest reachable byte lengths around 4096" do
    key = OpenSSL::PKey::RSA.generate(3072)
    origin = "https://#{["a" * 63, "b" * 63, "c" * 63, "d" * 57, "com"].join(".")}"

    assert_equal origin, ConfigValues.public_https_origin(origin)
    kid = '"' * 128
    jti = '"' * 128
    now = Time.current.change(usec: 0)
    config = Rails.configuration.x.boot_config
    jump_config = config.merge(jump: config.fetch(:jump).with(origin: origin))
    # For this fixed PS256 header and claim set, the 384-byte RSA signature moves the URL boundary
    # 288 bytes earlier. Unpadded base64url advances 4096 directly to 4098 bytes; 4097 is
    # unreachable by increasing the ASCII URL one byte at a time.
    [[1463, 4095], [1464, 4096], [1465, 4098]].each do |url_length, token_length|
      prefix = "https://target.example/"
      url = prefix + ("u" * (url_length - prefix.length))
      payload = SecurityJwtJumpRtTokenCodec.build_issue_payload(
        issuer: origin, normalized_url: url,
        dst: "internal", ttl: 30, now: now, jti: jti, audience: origin,
      )
      candidate = SecurityJwtJumpRtTokenCodec.encode(payload, private_key: key, kid: kid)

      assert_equal token_length, candidate.bytesize
      Rails.configuration.x.stub(:boot_config, jump_config) do
        JumpRtSurface.stub(:issuer_origin, origin) do
          JumpRtKeyring.stub(:active_kid, kid) do
            JumpRtKeyring.stub(:private_key, key) do
              token = JumpRtIssuer.call(namespace: "CORE_APP", url: url, dst: "internal", ttl: 30, now: now, jti: jti)
              if token_length <= 4096
                assert_equal token_length, token.bytesize
                decoded, = JWT.decode(token, key, true, algorithms: ["PS256"])

                assert_equal url, decoded.fetch("url")
              else
                assert_nil token
              end
            end
          end
        end
      end
    end
  end

  test "a valid JWT array audience is still outside the narrower Jump return contract" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "round4-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256", "use" => "sig",
    )
    now = Time.current.change(usec: 0)
    payload = { schema: 1,
                iss: "https://jump.umaxica.net",
                aud: ["https://www.umaxica.app"],
                sub: "jump-redirect",
                iat: now.to_i,
                nbf: now.to_i,
                exp: now.to_i + 30,
                jti: "round4",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    token = JWT.encode(payload, key, "PS256", { typ: "JWT", kid: "round4-key" })
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        fetcher: -> { { "keys" => [jwk] } }, now: now,
      )

      assert_not result.success?
      assert_equal "invalid_claim", result.error
    end
  end

  test "a false JWKS entry alongside a real key invalidates the whole publication" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "round4-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256", "use" => "sig",
    )
    token = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "round4-key" })
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        fetcher: -> { { "keys" => [jwk, nil] } },
      )

      assert_not result.success?
      assert_equal "jwks_unavailable", result.error
    end
  end
end
