# frozen_string_literal: true

require "test_helper"

class ValkeyUrlResponsibilityContractTest < ActiveSupport::TestCase
  test "a runtime auth-state URL is required and resolves to its declared responsibility" do
    missing =
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::ResponsibilityUrls.require_url(
          :auth_state, "RUNTIME_STATE_URL", environment: {},
                                            env: "production",
        )
      end
    assert_kind_of KeyError, missing.cause
    assert_equal "RUNTIME_STATE_URL is required", missing.message
    [nil, "", " "].each do |value|
      error =
        assert_raises(Umaxica::Valkey::ConfigurationError) do
          Umaxica::Valkey::ResponsibilityUrls.require_url(
            :auth_state, "RUNTIME_STATE_URL",
            environment: { "RUNTIME_STATE_URL" => value }, env: "production",
          )
        end
      assert_equal "RUNTIME_STATE_URL is required", error.message
    end
    parsed = Umaxica::Valkey::ResponsibilityUrls.require_url(
      :auth_state, "RUNTIME_STATE_URL",
      environment: { "RUNTIME_STATE_URL" => "rediss://state.example.com:6380/7" }, env: "production",
    )

    assert_equal :auth_state, parsed.responsibility
    assert_equal "state.example.com", parsed.host
    assert_equal 6380, parsed.port
    assert_equal 7, parsed.db
    assert_predicate parsed, :redis_scheme?
  end

  test "runtime production URLs cannot downgrade the auth-state transport" do
    error =
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::ResponsibilityUrls.require_url(
          :auth_state, "RUNTIME_STATE_URL",
          environment: { "RUNTIME_STATE_URL" => "redis://state.example.com/7" }, env: "production",
        )
      end
    assert_equal "RUNTIME_STATE_URL must use rediss:// in production", error.message
  end

  test "test runtime URLs cannot select the adjacent responsibility databases" do
    expected_db = Umaxica::Valkey::ResponsibilityUrls.expected_db(:auth_state, env: "test")
    [expected_db - 1, expected_db, expected_db + 1].each do |db|
      url = "redis://state.example.com/#{db}"
      if db == expected_db
        parsed = Umaxica::Valkey::ResponsibilityUrls.require_url(
          :auth_state, "RUNTIME_STATE_URL",
          environment: { "RUNTIME_STATE_URL" => url }, env: "test",
        )

        assert_equal expected_db, parsed.db
      else
        error =
          assert_raises(Umaxica::Valkey::ConfigurationError) do
            Umaxica::Valkey::ResponsibilityUrls.require_url(
              :auth_state, "RUNTIME_STATE_URL",
              environment: { "RUNTIME_STATE_URL" => url }, env: "test",
            )
          end
        assert_equal "auth_state Valkey URL DB is #{db}, expected #{expected_db} in test", error.message
      end
    end
  end
end
