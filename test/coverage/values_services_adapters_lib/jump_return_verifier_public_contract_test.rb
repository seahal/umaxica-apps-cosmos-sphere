# frozen_string_literal: true

require "test_helper"

class JumpReturnVerifierPublicContractTest < ActiveSupport::TestCase
  test "malformed JWKS documents never authorize a signed return" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, kid: "coverage-jump").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "coverage-jump" })
    documents = [nil, {}, { "keys" => [] }, { "keys" => Array.new(11, jwk) }, { "keys" => [nil] },
                 { "keys" => [jwk, jwk] }, { "keys" => [jwk.merge("kid" => "")] },
                 { "keys" => [jwk.merge("key_ops" => ["sign"])] }, { "keys" => [jwk.merge("d" => "private")] },
                 { "keys" => [jwk.merge("x" => "bad")] },]
    documents.each do |document|
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          fetcher: -> {
            document
          },
        )

        assert_not result.success?
        assert_equal "jwks_unavailable", result.error
        assert_nil result.payload
      end
    end
  end

  test "unknown signing keys refresh once then negative cache the miss" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, kid: "different-key").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig", "key_ops" => ["verify"],
    )
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "unknown-coverage-key" })
    calls = 0
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      2.times do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          fetcher: -> {
            calls += 1
            { "keys" => [jwk] }
          },
        )

        assert_equal "unknown_kid", result.error
      end
    end

    assert_equal 2, calls
  end

  test "JWKS transport errors fail closed" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "coverage-jump" })
    [SocketError, Net::ReadTimeout, JSON::ParserError, JWT::DecodeError].each do |error|
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          fetcher: -> {
            raise error
          },
        )

        assert_equal "jwks_unavailable", result.error
      end
    end
  end

  test "signed issuer audience and time errors retain distinct failure contracts" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, kid: "coverage-jump").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
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
                jti: "coverage",
                src: "https://visa.umaxica.app",
                dst: "internal",
                rpl: "reuse",
                url: "https://www.umaxica.app/", }
    [[{ iss: "https://wrong.example" }, "issuer_mismatch"], [{ aud: "https://wrong.example" }, "audience_mismatch"],
     [{ exp: now.to_i - 6 }, "invalid_claim"], [{ nbf: now.to_i + 60 }, "invalid_claim"],
     [{ exp: now.to_i + 31 }, "invalid_claim"],
     [{ jti: "bad\n" }, "invalid_claim"], [{ src: "https://unknown.example" },
                                           "invalid_claim",],].each do |changes, expected|
      token = JWT.encode(payload.merge(changes), key, "ES384", { typ: "JWT", kid: "coverage-jump" })
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        result = JumpRtReturnVerifier.call(
          token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
          request_base_url: "https://www.umaxica.app",
          fetcher: -> {
            { "keys" => [jwk] }
          }, now: now,
        )

        assert_not result.success?
        assert_equal expected, result.error
      end
    end
    other_key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode(payload, other_key, "ES384", { typ: "JWT", kid: "coverage-jump" })
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      result = JumpRtReturnVerifier.call(
        token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        fetcher: -> {
          { "keys" => [jwk] }
        }, now: now,
      )

      assert_equal "invalid_signature", result.error
    end
  end
  test "streamed JWKS enforces its byte ceiling through the real fetch boundary" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, kid: "coverage-jump").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "coverage-jump" })
    [-1, 0, 1].each do |offset|
      size = JumpRtReturnVerifier::MAX_JWKS_BYTES + offset
      body = { "keys" => [jwk] }.to_json
      body += " " * (size - body.bytesize)
      transport = Faraday.new
      get =
        lambda do |_uri, &block|
          request = Struct.new(:options).new(Faraday::RequestOptions.new)
          block.call(request)
          request.options.on_data.call(body, body.bytesize, nil)
          Faraday::Response.new(status: 200)
        end
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        OutboundHttp::Connection.stub(:build, transport) do
          transport.stub(:get, get) do
            result = JumpRtReturnVerifier.call(
              token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
              request_base_url: "https://www.umaxica.app",
            )

            assert_equal offset.positive? ? "jwks_unavailable" : "issuer_mismatch", result.error
          end
        end
      end
    end
  end

  test "HTTP status malformed JSON and network failures cannot become valid JWKS" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode({}, key, "ES384", { typ: "JWT", kid: "coverage-jump" })
    [500, 200, :network].each do |status|
      transport = Faraday.new
      get =
        lambda do |_uri, &block|
          raise Faraday::ConnectionFailed, "upstream offline" if status == :network

          request = Struct.new(:options).new(Faraday::RequestOptions.new)
          block.call(request)
          request.options.on_data.call("{", 1, nil)
          Faraday::Response.new(status: status)
        end
      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        OutboundHttp::Connection.stub(:build, transport) do
          transport.stub(:get, get) do
            result = JumpRtReturnVerifier.call(
              token: token, request_url: "https://www.umaxica.app/?rt=#{token}",
              request_base_url: "https://www.umaxica.app",
            )

            assert_equal "jwks_unavailable", result.error
          end
        end
      end
    end
  end
end
