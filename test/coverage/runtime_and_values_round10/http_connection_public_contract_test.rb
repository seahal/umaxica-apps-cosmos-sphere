# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound10HttpConnectionPublicContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a request requiring public DNS pinning selects the guarded transport without opening a socket" do
    connection = OutboundHttp::Connection.build(
      url: "https://provider.example/keys", open_timeout: 1, read_timeout: 2,
      require_https: true, require_public_address: true,
    )

    assert_equal OutboundHttp::ConnectionAdapterPort, connection.builder.adapter.klass
    assert_equal "provider.example", connection.url_prefix.host
    assert_equal "/keys", connection.url_prefix.path
    assert_equal 1, connection.options.open_timeout
    assert_equal 2, connection.options.timeout
  end

  test "malformed URI and non-HTTPS schemes are rejected before building a request transport" do
    assert_raises(URI::InvalidURIError) do
      OutboundHttp::Connection.build(
        url: "https://[bad", open_timeout: 1, read_timeout: 2, require_https: true,
      )
    end
    %w(http://provider.example/token file:///tmp/key-material ftp://provider.example/token).each do |url|
      error =
        assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
          OutboundHttp::Connection.build(url:, open_timeout: 1, read_timeout: 2, require_https: true)
        end

      assert_equal "outbound HTTP endpoint must be HTTPS", error.message
    end
  end

  test "the public adapter opt-out delegates ordinary trusted transport setup without resolving DNS" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: false)
    connection = adapter.net_http_connection(url: URI("https://provider.example/path"), request: { proxy: nil })

    assert_instance_of Net::HTTP, connection
    assert_equal "provider.example", connection.address
    assert_equal 443, connection.port
    assert_not_predicate connection, :started?
  end

  test "an unparsable local back-channel URL still requires HTTPS" do
    assert OutboundHttp::LocalBackChannel.require_https?("https://[bad")
  end
end
