# frozen_string_literal: true

require "test_helper"

class OidcAdaptersPublicJwksAndRevocationBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @now = Time.current
    @clock = -> { @now }
    @uri = "https://op-boundary.example.test/.well-known/jwks.json"
    @key = OpenSSL::PKey::RSA.generate(3072)
    @jwk = JitSecurityJwtJwk.export_public(@key, kid: "known")
  end

  test "JWKS configuration rejects malformed URLs and nonfixed trust destinations" do
    ["http://op.example/jwks", "https://user:pass@op.example/jwks", "https://op.example/jwks?q=1",
     "https://op.example/jwks#fragment", "https://op.example", "https://[bad",].each do |jwks_uri|
      assert_raises(ArgumentError) { OidcOpJwksClient.new(jwks_uri:) }
    end
  end

  test "malformed key identifiers never fetch attacker selected material" do
    fetches = []
    fetcher = -> { fetches << true }
    client = OidcOpJwksClient.new(jwks_uri: @uri, fetcher:)
    [nil, 1, "", " ", "x" * 129, "kid\n", "kid\u007f"].each do |kid|
      lookup = client.lookup(kid)

      assert_predicate lookup, :invalid?
      assert_equal "malformed_kid", lookup.reason
    end
    assert_empty fetches
  end

  test "key identifiers at and just below the byte limit remain usable" do
    [127, 128].each do |length|
      kid = "x" * length
      document = { "keys" => [@jwk.merge("kid" => kid)] }
      limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: @clock)
      lookup = OidcOpJwksClient.new(
        jwks_uri: @uri, fetcher: -> { document }, clock: @clock, limiter:,
      ).lookup(kid)

      assert_predicate lookup, :found?
      assert_equal @key.public_to_der, lookup.key.public_to_der
    end
  end

  test "malformed JWKS documents remain unavailable instead of becoming trusted empty key sets" do
    documents = [nil, [], {}, { "keys" => nil }, { "keys" => [] }, { "keys" => [nil] },
                 { "keys" => [{ "kid" => "" }] }, { "keys" => [@jwk.merge("d" => "private")] },
                 { "keys" => [@jwk, @jwk] }, { "keys" => [@jwk.merge("n" => "broken")] },]
    documents.each do |document|
      limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: @clock)
      client = OidcOpJwksClient.new(jwks_uri: @uri, fetcher: -> { document }, clock: @clock, limiter:)
      lookup = client.lookup("known")

      assert_predicate lookup, :unavailable?
      assert_equal "fetch_failed", lookup.reason
      assert_nil lookup.key
    end
  end

  test "network JWKS response body is bounded before JSON parsing and public key import" do
    body = JSON.generate("keys" => [@jwk])
    [body.ljust(OidcOpJwksClient::MAXIMUM_RESPONSE_BYTES - 1, " "),
     body.ljust(OidcOpJwksClient::MAXIMUM_RESPONSE_BYTES, " "),].each do |raw|
      response = Faraday::Response.new(status: 200, body: raw)
      connection = Minitest::Mock.new
      connection.expect(:get, response, [@uri])
      limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: @clock)
      lookup =
        OutboundHttp::Connection.stub(:build, connection) do
          OidcOpJwksClient.new(jwks_uri: @uri, clock: @clock, limiter:).lookup("known")
        end

      assert_predicate lookup, :found?
      assert_equal @key.public_to_der, lookup.key.public_to_der
      connection.verify
    end
    connection = Minitest::Mock.new
    connection.expect(:get, Faraday::Response.new(status: 200, body: " " * 65_537), [@uri])
    limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: @clock)
    lookup =
      OutboundHttp::Connection.stub(:build, connection) do
        OidcOpJwksClient.new(jwks_uri: @uri, clock: @clock, limiter:).lookup("known")
      end

    assert_predicate lookup, :unavailable?
    assert_equal "fetch_failed", lookup.reason
    connection.verify
  end

  test "network failures expose unavailable JWKS without propagating credentials or transport errors" do
    connection = Faraday.new
    requests = []
    request =
      lambda do |url|
        requests << url
        raise Faraday::ConnectionFailed, "network unavailable"
      end
    limiter = OidcJwksRefetchLimiter::LocalWindow.new(clock: @clock)
    lookup =
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, request) do
          OidcOpJwksClient.new(jwks_uri: @uri, clock: @clock, limiter:).lookup("known")
        end
      end

    assert_predicate lookup, :unavailable?
    assert_equal "fetch_failed", lookup.reason
    assert_equal [@uri], requests
  end

  test "revocation rejects missing tokens unknown clients and cross-realm clients before network access" do
    assert_equal :missing_token,
                 OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: nil).outcome
    assert_equal :client_unavailable,
                 OidcOpRevocationClient.revoke(
                   client_id: "unknown-rp", resource_type: "client",
                   token: "opaque",
                 ).outcome
    assert_equal :resource_mismatch,
                 OidcOpRevocationClient.revoke(
                   client_id: "core-app-jp", resource_type: "operator",
                   token: "opaque",
                 ).outcome
  end

  test "revocation returns an explicit endpoint failure for an invalid registered endpoint" do
    result =
      OidcIssuer.stub(:revocation_endpoint, "https://[bad") do
        OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque")
      end

    assert_equal :endpoint_unavailable, result.outcome
    assert_not_predicate result, :success?
  end

  test "revocation refuses unsupported client authentication instead of sending an unauthenticated token" do
    client = OidcClientRegistry.find!("core-app-jp").with(registered_token_endpoint_auth_method: "none")

    OidcClientRegistry.stub(:find, client) do
      assert_raises(ArgumentError) do
        OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque")
      end
    end
  end

  test "revocation cannot send a token when its client assertion cannot be issued" do
    result =
      OidcClientAssertionJwt.stub(:issue, nil) do
        OidcOpRevocationClient.revoke(client_id: "core-app-jp", resource_type: "client", token: "opaque")
      end

    assert_equal :client_authentication_unavailable, result.outcome
  end
end
