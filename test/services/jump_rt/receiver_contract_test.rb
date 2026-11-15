# frozen_string_literal: true

require "test_helper"

# Runs the preserved receiver fixtures against the real JumpRtReturnVerifier. Each url_case's
# literal rt value "returned" is replaced with a PS256 Jump-signed token whose url claim is the
# case's signed_url, so the signature, claim, and URL checks all run. The fixtures' upstream
# algorithm metadata remains pinned as historical source material; the current local codec is
# asserted separately below.
class JumpRtReceiverContractTest < ActiveSupport::TestCase
  CONTRACTS = {
    "0.3.0 existing fixture" => JSON.parse(
      Rails.root.join("test/fixtures/files/jump_receiver_contract.json").read,
    ).freeze,
    "0.4.0 pinned candidate" => JSON.parse(
      Rails.root.join("test/fixtures/files/jump_receiver_contract_0_4_0.json").read,
    ).freeze,
  }.freeze

  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::RSA.generate(3072)
    @public_jwk = JWT::JWK.new(@private_key, kid: "jump-test").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  CONTRACTS.each do |contract_name, contract|
    contract.fetch("url_cases").each do |url_case|
      accepted = url_case.fetch("accepted") ? "accepted" : "rejected"
      test "#{contract_name} url case #{url_case.fetch("name")} is #{accepted}" do
        iat = @now.to_i
        payload = {
          schema: 1,
          iss: "https://jump.umaxica.net",
          aud: "https://www.umaxica.app",
          sub: "jump-redirect",
          iat: iat,
          nbf: iat,
          exp: iat + contract.fetch("ttl_seconds"),
          jti: "jump-contract-jti",
          src: "https://visa.umaxica.app",
          dst: "internal",
          rpl: "reuse",
          url: url_case.fetch("signed_url"),
        }
        token = JWT.encode(payload, @private_key, "PS256", { typ: "JWT", kid: "jump-test" })

        result = JumpRtReturnVerifier.call(
          token: token,
          request_url: url_case.fetch("request_url").gsub("returned", token),
          request_base_url: "https://www.umaxica.app",
          fetcher: -> { { "keys" => [@public_jwk] } },
          now: @now,
        )

        assert_equal url_case.fetch("accepted"), result.success?, result.error
        assert_equal "invalid_url", result.error unless url_case.fetch("accepted")
      end
    end
  end

  test "contract time and size limits match the receiver" do
    candidate = CONTRACTS.fetch("0.4.0 pinned candidate")

    assert_equal candidate.fetch("inbound_max_ttl_seconds"), JumpRtReturnVerifier::MAX_RETURN_TTL
    assert_equal candidate.fetch("clock_tolerance_seconds"), JumpRtReturnVerifier::LEEWAY
    assert_equal candidate.fetch("max_token_characters"), JumpRtReturnVerifier::MAX_TOKEN_LENGTH
  end

  test "local contract claim and header algorithm match the receiver codec" do
    candidate = CONTRACTS.fetch("0.4.0 pinned candidate")

    assert_equal candidate.fetch("schema"), SecurityJwtJumpRtTokenCodec::SCHEMA
    assert_equal candidate.fetch("rpl"), SecurityJwtJumpRtTokenCodec::REPLAY_POLICY
    assert_equal candidate.fetch("sub"), SecurityJwtJumpRtTokenCodec::TOKEN_SUBJECT
    assert_equal candidate.dig("header", "typ"), SecurityJwtJumpRtTokenCodec::TOKEN_TYPE
    assert_equal "PS256", SecurityJwtJumpRtTokenCodec::ALGORITHM
  end

  test "vendored receiver and upstream graph fixtures retain their pinned source hashes" do
    files = {
      "jump_receiver_contract_0_4_0.json" =>
        "0db02b9412487931465a81e5e292e7bc6f0ca3eb06a1296e558348772cdadb9a",
      "jump_production_graph_0_4_0.json" =>
        "44d798435a4669c8d89fa039fc3084f1277f272f2efaab217c6966b66cde1262",
      "jump_receiver_contract.json" =>
        "7f884dcc348ff61cd94643b4dfbc0c5e27caa21fbf570abed81084b59471339e",
    }

    files.each do |filename, expected_sha256|
      path = Rails.root.join("test/fixtures/files", filename)

      assert_equal expected_sha256, Digest::SHA256.file(path).hexdigest, filename
    end
  end
end
