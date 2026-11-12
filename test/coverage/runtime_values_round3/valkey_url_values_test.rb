# frozen_string_literal: true

require "test_helper"
require "umaxica/valkey/settings"

class RuntimeValuesRound3ValkeyUrlValuesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Redis URL values retain responsibility explicit database endpoint and namespace independence" do
    parsed = Umaxica::Valkey::ResponsibilityUrls.parse("rediss://cache.example:6380/12", responsibility: "cache")

    assert_equal :cache, parsed.responsibility
    assert_equal "rediss://cache.example:6380/12", parsed.url
    assert_equal "cache.example", parsed.host
    assert_equal 6380, parsed.port
    assert_equal 12, parsed.db
    assert_predicate parsed, :redis_scheme?
    implicit = Umaxica::Valkey::ResponsibilityUrls.parse("redis://cache.example", responsibility: :rate_limit)

    assert_equal 0, implicit.db
    assert_equal 6379, implicit.port
  end

  test "malformed runtime URLs reject unsupported responsibilities missing host and invalid database paths" do
    [nil, "", "https://cache.example/0", "redis:///0", "redis://[bad",
     "redis://cache.example/not-a-number",].each do |url|
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::ResponsibilityUrls.parse(url, responsibility: :cache)
      end
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.parse("redis://cache.example/0", responsibility: :unknown)
    end
  end

  test "production transport validation refuses plaintext while allowing configured TLS URLs" do
    plaintext = Umaxica::Valkey::ResponsibilityUrls.parse("redis://cache.example/0", responsibility: :cache)
    tls = Umaxica::Valkey::ResponsibilityUrls.parse("rediss://cache.example/0", responsibility: :cache)
    error =
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::ResponsibilityUrls.assert_production_tls!(plaintext, env: "production")
      end

    assert_equal "cache Valkey URL must use rediss:// in production", error.message
    assert_nil Umaxica::Valkey::ResponsibilityUrls.assert_production_tls!(tls, env: "production")
    assert_nil Umaxica::Valkey::ResponsibilityUrls.assert_production_tls!(plaintext, env: "development")
  end

  test "resolved store value retains namespace without connecting to a backend" do
    memory = Umaxica::Valkey::Settings::Resolved.new(
      responsibility: :cache, url: nil, db: 2, host: nil, port: nil, store: :memory, namespace: "cache-space",
    )
    redis = Umaxica::Valkey::Settings::Resolved.new(
      responsibility: :auth_state, url: "redis://state.example/3", db: 3, host: "state.example", port: 6379,
      store: :redis, namespace: "state-space",
    )

    assert_predicate memory, :memory?
    assert_not_predicate redis, :memory?
    assert_equal "cache-space", memory.namespace
    assert_equal "state-space", redis.namespace
    assert_equal 2, memory.db
    assert_equal :auth_state, redis.responsibility
  end
end
