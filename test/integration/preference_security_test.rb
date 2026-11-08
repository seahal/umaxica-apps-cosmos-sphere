# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSecurityTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "a validation refusal accepts only a safe internal Referer and otherwise returns to the same-host root" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    referers = [
      ["/preference/theme/edit?ri=jp", "/preference/theme/edit?ri=jp"],
      [nil, "/"],
      ["", "/"],
      ["https://foreign.example.test/private", "/"],
      ["https://#{host}/preference/theme/edit?ri=jp", "/"],
      ["//foreign.example.test/private", "/"],
      ["/%2f%2fforeign.example.test/private", "/"],
      ["/preference?next=https://foreign.example.test/private", "/"],
    ]

    referers.each do |referer, expected_path|
      headers = referer.nil? ? {} : { "Referer" => referer }
      assert_no_difference [-> { AppPreference.count }, -> { AppPreferenceCookie.count },
                            -> { AppPreferenceConsentReceipt.count },] do
        patch base_app_preference_cookie_path(ri: "jp"),
              params: { preference_cookie: { consented: "1" } }, headers: headers
      end

      assert_response :redirect
      destination = URI.parse(response.location)

      assert_equal "https", destination.scheme
      assert_equal host, destination.host
      assert_equal expected_path, destination.request_uri
      assert_not_includes response.location, "foreign.example.test"
    end
  end

  test "timezone update rejects unknown raw strings even with a slash" do
    get edit_base_app_preference_timezone_url(ri: "jp")

    assert_response :success
    existing_preferences = AppPreference.count

    patch base_app_preference_timezone_url(ri: "jp"),
          params: { preference_timezone: { option_id: "../etc/passwd" } }

    assert_redirected_to edit_base_app_preference_timezone_url(ri: "jp")
    assert_empty flash.to_hash
    assert_equal existing_preferences, AppPreference.count
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "theme update pt redirect refuses absolute URLs and protocol-relative paths" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    ["https://evil.example/pwn", "//evil.example/pwn", "/\\evil.example/pwn"].each do |hostile_pt|
      patch base_app_preference_theme_url(ri: "jp", pt: hostile_pt),
            params: { preference_theme: { option_id: "dr" } }

      assert_response :redirect,
                      "theme update should still redirect for pt=#{hostile_pt.inspect}"
      assert_no_match(/evil\.example/, response.headers["Location"].to_s)
    end
  end

  test "internal pt path is preserved when safe" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp", pt: "/preference?ri=jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect
    assert_includes response.headers["Location"], "/preference"
  end
end
