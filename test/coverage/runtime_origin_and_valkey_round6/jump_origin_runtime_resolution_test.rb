# frozen_string_literal: true

require "test_helper"

class JumpOriginRuntimeResolutionTest < ActiveSupport::TestCase
  test "an explicitly supplied runtime origin source cannot silently use another identity" do
    [nil, "", " "].each do |value|
      error =
        assert_raises(JumpRtConfigurationError) do
          JumpRtSurface.issuer_origin("CORE_APP", env: { "PUBLIC_CORE_SERVICE_URL" => value })
        end
      assert_equal "PUBLIC_CORE_SERVICE_URL is required for Jump issuance", error.message
    end
    assert_equal "https://core.example.com",
                 JumpRtSurface.issuer_origin("CORE_APP", env: { "PUBLIC_CORE_SERVICE_URL" => "core.example.com" })
    assert_equal "https://core.example.com/.well-known/jwks.json",
                 JumpRtSurface.issuer_jwks_uri(
                   "CORE_APP",
                   env: { "PUBLIC_CORE_SERVICE_URL" => "https://core.example.com" },
                 )
  end

  test "the local RP uses its already installed origin when the runtime origin is absent" do
    environment = ENV.to_h
    expected_origin = Rails.configuration.x.boot_config.fetch(:hosts).core_service.to_s
    environment_reader =
      lambda do |key|
        (key == "PUBLIC_CORE_SERVICE_URL") ? nil : environment[key]
      end
    ENV.stub(:[], environment_reader) do
      assert_equal expected_origin, JumpRtSurface.issuer_origin("CORE_APP")
      assert_equal "#{expected_origin}/.well-known/jwks.json", JumpRtSurface.issuer_jwks_uri("CORE_APP")
    end
  end

  test "an external Base participant has no RP-local origin fallback" do
    environment = ENV.to_h
    environment_reader =
      lambda do |key|
        (key == "PUBLIC_BASE_SERVICE_URL") ? nil : environment[key]
      end
    ENV.stub(:[], environment_reader) do
      error = assert_raises(JumpRtConfigurationError) { JumpRtSurface.issuer_origin("BASE_APP") }
      assert_equal "PUBLIC_BASE_SERVICE_URL is required for Jump issuance", error.message
    end
  end
end
