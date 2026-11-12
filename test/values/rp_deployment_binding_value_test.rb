# typed: false
# frozen_string_literal: true

require "test_helper"

class RpDeploymentBindingValueTest < ActiveSupport::TestCase
  test "resolves every retained Sphere RP family and realm to its deployment client" do
    region = ENV.fetch("UMAXICA_DEPLOYMENT_REGION")

    %w(core-app core-org warp-app warp-org palm-app).each do |family_realm|
      assert_equal "#{family_realm}-#{region}", RpDeploymentBindingValue.client_id(family_realm)
    end
  end

  test "accepts the other registered region and rejects an unsupported deployment region" do
    previous_region = ENV["UMAXICA_DEPLOYMENT_REGION"]
    ENV["UMAXICA_DEPLOYMENT_REGION"] = "us"

    assert_equal "core-app-us", RpDeploymentBindingValue.client_id("core-app")

    ENV["UMAXICA_DEPLOYMENT_REGION"] = "eu"
    assert_raises(RpDeploymentBindingValue::UnknownRegion) do
      RpDeploymentBindingValue.client_id("core-app")
    end
  ensure
    if previous_region.nil?
      ENV.delete("UMAXICA_DEPLOYMENT_REGION")
    else
      ENV["UMAXICA_DEPLOYMENT_REGION"] = previous_region
    end
  end

  test "rejects foreign, unsupported, empty, and missing RP family and realm values" do
    %w(base-app base-org edit-org tech-org visa-app auth-app).each do |family_realm|
      assert_raises(RpDeploymentBindingValue::UnknownRp) do
        RpDeploymentBindingValue.client_id(family_realm)
      end
    end

    [nil, "", "unknown-app"].each do |family_realm|
      assert_raises(RpDeploymentBindingValue::UnknownRp) do
        RpDeploymentBindingValue.client_id(family_realm)
      end
    end
  end
end
