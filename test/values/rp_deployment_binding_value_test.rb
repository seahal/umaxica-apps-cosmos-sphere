# frozen_string_literal: true

require "test_helper"

class RpDeploymentBindingValueTest < ActiveSupport::TestCase
  test "the deployment catalog separates declared regional clients from active clients" do
    region = RpDeploymentBindingValue.region
    other_region = { "jp" => "us", "us" => "jp" }.fetch(region)
    catalog = RpDeploymentBindingValue.catalog
    active = RpDeploymentBindingValue.active_client_ids

    assert_equal 14, catalog.length
    assert_equal catalog.uniq, catalog
    assert_includes catalog, "core-app-jp"
    assert_includes catalog, "core-app-us"
    assert_includes active, "core-app-#{region}"
    assert_not_includes active, "core-app-#{other_region}"
    assert_includes active, "base-app-ww"
    assert_equal "core-app-#{region}", RpDeploymentBindingValue.client_id("core-app")
    assert_equal "base-app-ww", RpDeploymentBindingValue.client_id("base-app")
    assert_raises(RpDeploymentBindingValue::UnknownRp) do
      RpDeploymentBindingValue.client_id("unknown-app")
    end
  end
end
