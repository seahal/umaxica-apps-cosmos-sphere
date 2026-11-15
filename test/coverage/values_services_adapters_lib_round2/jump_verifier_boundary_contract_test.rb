# frozen_string_literal: true

require "test_helper"

class JumpVerifierBoundaryContractTest < ActiveSupport::TestCase
  test "ES384 signed return tokens are refused before fetching the JWKS" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "legacy-jump-key" })
    fetcher = -> { flunk("legacy algorithm reached JWKS lookup") }

    result = JumpRtReturnVerifier.call(
      token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
      request_base_url: "https://www.umaxica.app", fetcher:,
    )

    assert_equal "invalid_header", result.error
    assert_not_predicate result, :success?
  end

  test "RS256 PS384 and mismatched PS256 headers are refused before fetching the JWKS" do
    key = OpenSSL::PKey::RSA.generate(3072)
    ["RS256", "PS384"].each do |algorithm|
      token = JWT.encode({}, key, algorithm, { typ: "JWT", kid: "unsupported-#{algorithm.downcase}" })
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app", fetcher: -> { flunk("#{algorithm} reached JWKS lookup") },
      )

      assert_equal "invalid_header", result.error, algorithm
    end

    [["HS256", "untrusted-key"], ["none", nil]].each do |algorithm, secret|
      token = JWT.encode({}, secret, algorithm, { typ: "JWT", kid: "unsupported-#{algorithm.downcase}" })
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app", fetcher: -> { flunk("#{algorithm} reached JWKS lookup") },
      )

      expected_error = (algorithm == "none") ? "malformed" : "invalid_header"

      assert_equal expected_error, result.error, algorithm
    end

    signed = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "mismatched-algorithm" })
    segments = signed.split(".")
    header = JSON.parse(Base64.urlsafe_decode64(segments.fetch(0)))
    header["alg"] = "RS256"
    segments[0] = Base64.urlsafe_encode64(JSON.generate(header), padding: false)
    mismatched = segments.join(".")
    result = JumpRtReturnVerifier.call(
      token: mismatched, request_url: "https://www.umaxica.app/?rt=#{mismatched}",
      request_base_url: "https://www.umaxica.app", fetcher: -> { flunk("mismatched header reached JWKS lookup") },
    )

    assert_equal "invalid_header", result.error
  end

  test "an undersized RSA JWKS key is rejected even when its PS256 signature is valid" do
    key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(key, kid: "undersized-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    token = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "undersized-key" })
    result = JumpRtReturnVerifier.call(
      token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
      request_base_url: "https://www.umaxica.app", fetcher: -> { { "keys" => [jwk] } },
    )

    assert_equal "jwks_unavailable", result.error
    assert_not_predicate result, :success?
  end

  test "return token input size and header failures reject before any JWKS lookup" do
    [[nil, "missing_token"], [" ", "missing_token"], ["a.b", "malformed"]].each do |token, expected|
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/",
        request_base_url: "https://www.umaxica.app", fetcher: Minitest::Mock.new,
      )

      assert_equal expected, result.error
    end
    [8191, 8192, 8193].each do |size|
      token = ("a" * (size - 4)) + ".b.c"
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/",
        request_base_url: "https://www.umaxica.app", fetcher: Minitest::Mock.new,
      )

      assert_equal (size > 8192) ? "malformed" : "invalid_signature", result.error
    end
    key = OpenSSL::PKey::RSA.generate(3072)
    token = JWT.encode({}, key, "PS256", { typ: "unexpected", kid: "boundary-key" })
    result = JumpRtReturnVerifier.call(
      token: token, request_url: "https://www.umaxica.app/",
      request_base_url: "https://www.umaxica.app", fetcher: Minitest::Mock.new,
    )

    assert_equal "invalid_header", result.error
    config = Rails.configuration.x.boot_config
    revoked_config = config.merge(jump: config.fetch(:jump).with(revoked_kids: ["boundary-key"]))
    token = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "boundary-key" })
    Rails.configuration.x.stub(:boot_config, revoked_config) do
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/",
        request_base_url: "https://www.umaxica.app", fetcher: Minitest::Mock.new,
      )

      assert_equal "revoked_kid", result.error
    end
  end

  test "signed navigation claims enforce text identifier and URL boundaries" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "boundary-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    now = Time.current.change(usec: 0)
    payload = { schema: 1,
                iss: "https://jump.umaxica.net",
                aud: "https://www.umaxica.app",
                sub: "jump-redirect",
                iat: now.to_i,
                nbf: now.to_i,
                exp: now.to_i + 30,
                jti: "boundary",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    cases = [
      [{ schema: 2 }, false], [{ extra: "unsupported" }, false], [{ sub: "wrong" }, false],
      [{ dst: "external" }, false], [{ jti: 1 }, false], [{ jti: "" }, false],
      [{ src: 1 }, false], [{ src: "" }, false], [{ url: 1 }, false], [{ url: "" }, false], [{ rpl: "once" }, false],
    ]
    [127, 128, 129].each { |length| cases << [{ jti: "j" * length }, length <= 128] }
    [2047, 2048, 2049].each do |length|
      prefix = "https://www.umaxica.app/"
      cases << [{ url: prefix + ("u" * (length - prefix.length)) }, length <= 2048]
    end
    cases.each do |changes, accepted|
      token = JWT.encode(payload.merge(changes), key, "PS256", { typ: "JWT", kid: "boundary-key" })
      request_url = "#{payload.merge(changes).fetch(:url)}?rt=#{token}"
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: request_url, request_base_url: "https://www.umaxica.app", fetcher: -> {
            { "keys" => [jwk] }
          }, now: now,
        )

        assert_equal accepted, result.success?, changes.inspect
        assert_equal "invalid_claim", result.error unless accepted
      end
    end
  end

  test "signed validity windows reject inconsistent and out of range time values" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "boundary-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    now = Time.current.change(usec: 0)
    payload = { schema: 1,
                iss: "https://jump.umaxica.net",
                aud: "https://www.umaxica.app",
                sub: "jump-redirect",
                iat: now.to_i,
                nbf: now.to_i,
                exp: now.to_i + 30,
                jti: "boundary",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    cases = [[{ iat: 0 }, false], [{ exp: now.to_i, nbf: now.to_i }, false],
             [{ exp: now.to_i + 1, nbf: now.to_i + 2 }, false],]
    [29, 30, 31].each { |ttl| cases << [{ exp: now.to_i + ttl }, ttl <= 30] }
    cases.each do |changes, accepted|
      token = JWT.encode(payload.merge(changes), key, "PS256", { typ: "JWT", kid: "boundary-key" })
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          fetcher: -> {
            { "keys" => [jwk] }
          }, now: now,
        )

        assert_equal accepted, result.success?, changes.inspect
        assert_equal "invalid_claim", result.error unless accepted
      end
    end
  end
  test "a cached signing key avoids refetching while a newly rotated key refreshes exactly once" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "boundary-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    now = Time.current.change(usec: 0)
    payload = { schema: 1,
                iss: "https://jump.umaxica.net",
                aud: "https://www.umaxica.app",
                sub: "jump-redirect",
                iat: now.to_i,
                nbf: now.to_i,
                exp: now.to_i + 30,
                jti: "boundary",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    token = JWT.encode(payload, key, "PS256", { typ: "JWT", kid: "boundary-key" })
    fetches = 0
    fetcher =
      lambda do
        fetches += 1
        { "keys" => [(fetches == 1) ? jwk.merge("kid" => "previous-key") : jwk] }
      end
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      2.times do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app", fetcher: fetcher, now: now,
        )

        assert_predicate result, :success?, result.error
      end
    end

    assert_equal 2, fetches
  end

  test "a non-positive RSA modulus cannot become valid verification material" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "boundary-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256", "use" => "sig", "n" => Base64.urlsafe_encode64("\x00" * 384, padding: false),
    )
    token = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "boundary-key" })
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app", fetcher: -> {
          { "keys" => [jwk] }
        },
      )

      assert_equal "jwks_unavailable", result.error
    end
  end

  test "a non-HTTPS JWKS URL fails closed before attempting an outbound request" do
    key = OpenSSL::PKey::RSA.generate(3072)
    token = JWT.encode({}, key, "PS256", { typ: "JWT", kid: "insecure-jwks-origin" })
    config = Rails.configuration.x.boot_config
    unsafe_jump_config = config.fetch(:jump).with(origin: "http://jump.example.test")

    OutboundHttp::Connection.stub(:build, ->(**_options) { flunk("HTTP JWKS must not open a connection") }) do
      Rails.configuration.x.stub(:boot_config, config.merge(jump: unsafe_jump_config)) do
        result = JumpRtReturnVerifier.call(
          token: token,
          request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
        )

        assert_equal "jwks_unavailable", result.error
        assert_not_predicate result, :success?
      end
    end
  end

  test "a signed URL cannot contain a return token and the request must carry the exact signed token" do
    key = OpenSSL::PKey::RSA.generate(3072)
    jwk = JWT::JWK.new(key, kid: "boundary-key").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    now = Time.current.change(usec: 0)
    payload = { schema: 1,
                iss: "https://jump.umaxica.net",
                aud: "https://www.umaxica.app",
                sub: "jump-redirect",
                iat: now.to_i,
                nbf: now.to_i,
                exp: now.to_i + 30,
                jti: "boundary",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    ["https://www.umaxica.app/?rt=embedded", "https://www.umaxica.app/"].each do |signed_url|
      token = JWT.encode(payload.merge(url: signed_url), key, "PS256", { typ: "JWT", kid: "boundary-key" })
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=another-token",
          request_base_url: "https://www.umaxica.app", fetcher: -> {
            { "keys" => [jwk] }
          }, now: now,
        )

        assert_equal "invalid_url", result.error
      end
    end
  end
end
