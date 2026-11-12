# frozen_string_literal: true

require "test_helper"

class RuntimePrimitivesRound4ValkeyCommandBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "namespaced runtime keys reject blank suffixes and literal separators" do
    connection = Umaxica::Valkey::Connection.new(
      url: "redis://unconnected.example/3", namespace: "rp:cell",
      client: Object.new,
    )

    assert_equal "rp:cell:session:123", connection.key("session:123")
    [nil, "", " ", "two words"].each do |suffix|
      assert_raises(Umaxica::Valkey::ConfigurationError) { connection.key(suffix) }
    end
    assert_not_predicate connection, :hiredis_driver?
    assert_nil connection.close
  end

  test "command failures are normalized without exposing command arguments" do
    requests = []
    client = Object.new
    client.define_singleton_method(:call) do |*arguments|
      requests << arguments
      raise IOError, "transport failed"
    end
    connection = Umaxica::Valkey::Connection.new(url: "redis://unconnected.example/3", namespace: "rp:cell", client:)
    error = assert_raises(Umaxica::Valkey::Unavailable) { connection.call("GET", "rp:cell:opaque") }

    assert_equal "Valkey operation unavailable", error.message
    assert_instance_of IOError, error.cause
    assert_equal [["GET", "rp:cell:opaque"]], requests
  end

  test "case insensitive flush protection rejects destructive commands before the client boundary" do
    client = Minitest::Mock.new
    connection = Umaxica::Valkey::Connection.new(url: "redis://unconnected.example/3", namespace: "rp:cell", client:)

    %w(flushall FlUsHdB).each do |command|
      assert_raises(Umaxica::Valkey::OperationError) { connection.call(command) }
    end
    client.verify
  end

  test "close suppresses transport teardown failure" do
    closes = []
    client = Object.new
    client.define_singleton_method(:close) do
      closes << true
      raise IOError, "already disconnected"
    end
    connection = Umaxica::Valkey::Connection.new(url: "redis://unconnected.example/3", namespace: "rp:cell", client:)

    assert_nil connection.close
    assert_equal [true], closes
  end
end
