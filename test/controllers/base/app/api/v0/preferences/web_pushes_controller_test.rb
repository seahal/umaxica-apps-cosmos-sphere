# frozen_string_literal: true

require "test_helper"

class Base::App::Api::V0::Preferences::WebPushesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @headers = {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-origin",
    }
  end

  test "anonymous GET reports disabled without creating preference or browser state" do
    assert_no_difference [-> { AppPreference.count }, -> { AppPreferenceBrowserBinding.count },
                          -> { AppPreferenceWebPush.count },] do
      get base_app_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal({ "web_push" => "disabled" }, response.parsed_body)
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil cookies[PreferenceBrowserBinding::COOKIE_NAME]
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "both accepted options persist behind the browser binding and GET never rotates their issuance" do
    %w(enabled disabled).each do |option|
      patch base_app_api_v0_preferences_web_push_path,
            params: { web_push: option }.to_json, headers: @headers

      assert_response :ok
      assert_equal "application/json", response.media_type
      assert_equal({ "web_push" => option }, response.parsed_body)
      claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
      preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
      binding = AppPreferenceBrowserBinding.find_by!(preference_id: preference.id)
      stored = AppPreferenceWebPush.find_by!(preference_id: preference.id)
      expected_id = (option == "enabled") ? AppPreferenceWebPushOption::ENABLED : AppPreferenceWebPushOption::DISABLED

      assert_equal expected_id, stored.option_id
      assert PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)
      issuance = preference.attributes
      jwt = cookies[PreferenceCookieName.anonymous_jwt]

      assert_no_difference -> { AppPreference.count } do
        get base_app_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
      end

      assert_response :ok
      assert_equal({ "web_push" => option }, response.parsed_body)
      assert_equal issuance, preference.reload.attributes
      assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    end
  end

  test "missing empty unsupported and non-string options return field errors without persistence" do
    submissions = [{}, { web_push: nil }, { web_push: "" }, { web_push: "ENABLED" },
                   { web_push: "unknown" }, { web_push: true }, { web_push: 0 },
                   { web_push: [] }, { web_push: {} },]

    submissions.each do |submission|
      assert_no_difference [-> { AppPreference.count }, -> { AppPreferenceBrowserBinding.count },
                            -> { AppPreferenceWebPush.count },] do
        patch base_app_api_v0_preferences_web_push_path, params: submission.to_json, headers: @headers
      end

      assert_response :unprocessable_content
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:validation-failed", response.parsed_body.fetch("type")
      assert_equal ["/web_push"], response.parsed_body.fetch("errors").pluck("pointer")
      assert_nil cookies[PreferenceBrowserBinding::COOKIE_NAME]
      assert_nil cookies[PreferenceCookieName.anonymous_jwt]
    end
  end

  test "a foreign browser binding cannot read enabled state or change the original preference" do
    patch base_app_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: @headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
    generation = preference.jti
    binding = AppPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value

    get base_app_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "web_push" => "disabled" }, response.parsed_body)

    assert_no_difference -> { AppPreference.count } do
      patch base_app_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: @headers
    end

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:authorization-denied", response.parsed_body.fetch("type")
    assert_equal generation, preference.reload.jti
    assert_equal binding, AppPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    assert_equal AppPreferenceWebPushOption::ENABLED,
                 AppPreferenceWebPush.find_by!(preference_id: preference.id).option_id
  end

  test "a web push storage dependency failure returns a problem without rotating browser credentials" do
    patch base_app_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: @headers

    assert_response :ok
    jwt = cookies[PreferenceCookieName.anonymous_jwt]
    raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims = PreferenceToken.decode(jwt, host: @host)
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
    generation = preference.jti

    unavailable = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "storage unavailable" }

    AppPreferenceWebPush.stub(:find_by, unavailable) do
      assert_no_difference -> { AppPreference.count } do
        get base_app_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
      end
    end

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
    assert_equal generation, preference.reload.jti
    assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal raw_binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    assert_equal AppPreferenceWebPushOption::DISABLED,
                 AppPreferenceWebPush.find_by!(preference_id: preference.id).option_id
  end

  test "a write without the session CSRF token is refused before creating preference state" do
    prior_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference [-> { AppPreference.count }, -> { AppPreferenceWebPush.count }] do
      patch(base_app_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: @headers)
    end

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
  ensure
    ActionController::Base.allow_forgery_protection = prior_forgery_protection
  end
end
