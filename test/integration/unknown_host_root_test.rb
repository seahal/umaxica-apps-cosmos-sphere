# typed: false
# frozen_string_literal: true

require "test_helper"

# Requests that do not match one of the retained operator-tool hosts must reach the explicit
# unknown-host response instead of Rails' development welcome page.
class UnknownHostRootTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  UNSERVED_HOST = "unclaimed.invalid"

  test "a host no surface claims does not answer 200 on root" do
    host! UNSERVED_HOST

    get "/"

    assert_response :not_found
    assert_equal "unknown_host", response.parsed_body["error"]
  end

  test "the framework welcome page is unreachable" do
    recognized = Rails.application.routes.recognize_path("http://#{UNSERVED_HOST}/", method: :get)

    assert_equal "unknown_hosts", recognized[:controller]
    assert_not_equal "rails/welcome", recognized[:controller]
  end

  # Host Authorization is not enabled in the test environment, so this reaches routing and lands
  # on the same fallback. In development and production the same request is refused earlier, with
  # 403, because the hostname is not in `config.hosts` at all. Either way it is not a 200.
  test "an arbitrary host reaches no surface" do
    host! "nonsense.invalid"

    get "/"

    assert_response :not_found
    assert_equal "unknown_host", response.parsed_body["error"]
  end
end
