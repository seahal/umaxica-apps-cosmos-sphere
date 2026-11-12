# frozen_string_literal: true

require "test_helper"

class HttpAdapterContractsRound6PublicAddressAndContextTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public endpoint pinning refuses proxies before DNS resolution" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)
    error =
      assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
        adapter.net_http_connection(
          url: URI("https://rp.example/path"),
          request: { proxy: "http://proxy.example:8080" },
        )
      end

    assert_equal "public endpoint cannot use an HTTP proxy", error.message
  end

  test "public endpoint pinning rejects missing hosts userinfo and fragments" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)
    ["https:///path", "https://user:secret@rp.example/path", "https://rp.example/path#fragment"].each do |url|
      error =
        assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
          adapter.net_http_connection(url: URI(url), request: { proxy: nil })
        end

      assert_equal "registered public endpoint is malformed", error.message
    end
  end

  test "an expected authentication context cannot be substituted by another valid signed context" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    issuer = "https://op.example.test"
    now = Time.current.to_i
    payload = {
      "iss" => issuer,
      "aud" => ["core-app-jp"],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now,
      "sub" => "subject",
      "sid" => "session",
      "client_id" => "core-app-jp",
      "jti" => "context-binding",
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
    token = JWT.encode(payload, key, "ES384", { "kid" => "context-key", "typ" => "at+jwt" })
    %w(normal standby).each do |expected|
      keys = Minitest::Mock.new
      keys.expect(:lookup, OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil), ["context-key"])
      result = OidcOpAccessTokenVerifier.new(
        access_token: token, client_id: "core-app-jp", realm: "app", issuer:, audience: "core-app-jp",
        jwks_client: keys, expected_authentication_context: expected,
      ).call

      assert_equal expected == "normal", result.success?
      keys.verify
    end
  end
end
