# frozen_string_literal: true

require "test_helper"

class AuthorizationHeaderAndStoreFailuresTest < ActiveSupport::TestCase
  test "authorization extracts the declared token transport case insensitively" do
    bearer = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => "bearer   signed-token")

    assert_equal "signed-token", AuthAuthorizationHeader.bearer_token(bearer)
    assert_equal "signed-token", AuthAuthorizationHeader.access_token(bearer)
    assert AuthAuthorizationHeader.scheme?(bearer, "BEARER")
    assert_equal "bearer   signed-token", AuthAuthorizationHeader.value(bearer)
    assert_equal "signed-token", AuthAuthorizationHeader.token_and_options(bearer).first
    dpop = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => "DPoP proof-bound")

    assert_equal "proof-bound", AuthAuthorizationHeader.access_token(dpop)
    assert_nil AuthAuthorizationHeader.bearer_token(dpop)
    request = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => "Basic encoded")

    assert_nil AuthAuthorizationHeader.access_token(request)
    assert_nil AuthAuthorizationHeader.token_and_options(ActionDispatch::TestRequest.create)
    assert_nil AuthAuthorizationHeader.value(Object.new)
    request = Struct.new(:headers).new({ "Authorization" => "Bearer header-only" })

    assert_equal "header-only", AuthAuthorizationHeader.access_token(request)
  end

  test "notice transport failures preserve the unavailable error boundary for every public operation" do
    connection = Minitest::Mock.new
    connection.expect(:key, "notice:key", [String])
    connection.expect(:call, nil) { |*| raise IOError, "connection closed" }
    error =
      assert_raises(Umaxica::Valkey::Unavailable) do
        Valkey::AuthState::SignOutNoticeStore.new(connection: connection).issue!(payload: {})
      end
    assert_kind_of IOError, error.cause
    connection.verify
    [:read, :consume].each do |operation|
      connection = Minitest::Mock.new
      connection.expect(:key, "notice:key", [String])
      connection.expect(:call, nil) { |*| raise IOError, "connection closed" }
      store = Valkey::AuthState::SignOutNoticeStore.new(connection: connection)
      error =
        assert_raises(Umaxica::Valkey::Unavailable) do
          (operation == :read) ? store.read(raw_id: "opaque") : store.consume(raw_id: "opaque")
        end
      assert_kind_of IOError, error.cause
      connection.verify
    end
  end

  test "notice consume rejects corrupt atomically removed data and issue honors an explicit expiry" do
    connection = Minitest::Mock.new
    connection.expect(:key, "notice:key", [String])
    connection.expect(:call, "{", ["EVAL", Valkey::AuthState::SignOutNoticeStore::GETDEL_SCRIPT, 1, "notice:key"])
    assert_raises(Umaxica::Valkey::SerializationError) do
      Valkey::AuthState::SignOutNoticeStore.new(connection: connection).consume(raw_id: "opaque")
    end
    connection.verify
    connection = Minitest::Mock.new
    connection.expect(:key, "notice:key", [String])
    connection.expect(:call, "OK") do |command, key, body, nx, ex, ttl|
      payload = JSON.parse(body)
      expected = { "version" => 1, "expires_at" => "2030-01-01T00:00:00Z" }
      command == "SET" && key == "notice:key" && payload == expected && nx == "NX" && ex == "EX" && ttl == 2
    end

    assert_predicate Valkey::AuthState::SignOutNoticeStore.new(connection: connection).issue!(
      payload: { expires_at: "2030-01-01T00:00:00Z" },
      ttl: 2.seconds,
    ),
                     :present?
    connection.verify
  end
end
