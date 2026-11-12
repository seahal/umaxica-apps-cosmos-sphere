# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::App::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    get core_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (APP)"
    assert_equal "core/app/roots/index", inertia_component
    assert_nil inertia_props.fetch("title")
    assert_equal "Core App", inertia_props.fetch("heading")
    assert_equal I18n.t("landing.thin_endpoint"), inertia_props.fetch("description")
  end

  test "root does not issue retired preference credentials" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    get core_app_root_url(ri: "jp")

    assert_response :success
    assert_nil cookies["preference_jwt"]
    assert_nil cookies["preference_refresh"]
  end
end
