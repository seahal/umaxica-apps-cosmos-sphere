# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerRedirectPublicMethodsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "safe redirect methods refuse external targets and preserve explicit same-origin paths" do
    [
      ["/dashboard?ri=jp", "/dashboard?ri=jp"],
      ["https://untrusted.example/path", "/refused"],
      ["//untrusted.example/path", "/refused"],
      [nil, "/refused"],
      ["/sign?next=https://untrusted.example", "/refused"],
    ].each do |target, destination|
      controller = Core::App::ApplicationController.new
      request = ActionDispatch::TestRequest.create
      request.host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      request.set_header("HTTPS", "on")
      controller.set_request!(request)
      framework_response = ActionDispatch::TestResponse.new
      framework_response.request = request
      controller.set_response!(framework_response)
      controller.safe_redirect_to(target, fallback: "/refused")

      assert_equal destination, URI.parse(controller.response.location).request_uri
      assert_equal request.host, URI.parse(controller.response.location).host
    end
  end

  test "safe referer redirects and public internal-path resolution never follow foreign origins" do
    [nil, "https://untrusted.example/", "/accepted?ri=jp"].each do |referer|
      controller = Core::App::ApplicationController.new
      request = ActionDispatch::TestRequest.create
      request.host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      request.set_header("HTTP_REFERER", referer)
      controller.set_request!(request)
      framework_response = ActionDispatch::TestResponse.new
      framework_response.request = request
      controller.set_response!(framework_response)
      controller.safe_redirect_back_or_to("/fallback")

      assert_equal(
        (referer == "/accepted?ri=jp") ? referer : "/fallback",
        URI.parse(controller.response.location).request_uri,
      )
      assert_equal "/safe", controller.safe_internal_path("/safe")
      assert_nil controller.safe_internal_path("https://untrusted.example/")
    end
  end

  test "host normalization handles configured origins and malformed text without selecting authority" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
    assert_equal "example.org", CommonRedirect.normalize_host(" HTTPS://Example.Org/path ")
    assert_equal "example.org", CommonRedirect.normalize_host("Example.Org/path")
    assert_equal "[invalid", CommonRedirect.normalize_host("[invalid")
  end

  test "jump redirect refuses a target for which no signed token can be issued" do
    controller = Core::App::ApplicationController.new
    request = ActionDispatch::TestRequest.create
    request.host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    request.set_header("HTTPS", "on")
    controller.set_request!(request)
    framework_response = ActionDispatch::TestResponse.new
    framework_response.request = request
    controller.set_response!(framework_response)

    controller.redirect_to_jump_url("javascript:alert(1)")

    assert_equal 422, controller.response.status
    assert_equal I18n.t("errors.messages.invalid_request"), controller.response.body
    assert_nil controller.response.location
  end

  test "jump redirect refuses to redirect when the configured gateway URI is malformed" do
    controller = Core::App::ApplicationController.new
    request = ActionDispatch::TestRequest.create
    request.host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    request.set_header("HTTPS", "on")
    controller.set_request!(request)
    framework_response = ActionDispatch::TestResponse.new
    framework_response.request = request
    controller.set_response!(framework_response)
    config = Rails.configuration.x.boot_config
    boot_config = config.merge(jump: config.fetch(:jump).with(origin: "https://["))

    Rails.configuration.x.stub(:boot_config, boot_config) do
      controller.redirect_to_jump_url("https://target.example/path")
    end

    assert_equal 422, controller.response.status
    assert_equal I18n.t("errors.messages.invalid_request"), controller.response.body
    assert_nil controller.response.location
  end
end
