# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCorruptCookieTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  end

  test "a malformed anonymous JWT is detached on GET without creating a preference" do
    cookies[PreferenceCookieName.anonymous_jwt] = "not.a.jwt"
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
    cookies[PreferenceCookieName.anonymous_experience] = "{\"theme\":\"dark\"}"

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end

    assert_response :success
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_shared_cookie_expired(name)
    end
  end

  test "an explicit write after a malformed JWT creates a fresh row and issues the three shared cookies" do
    cookies[PreferenceCookieName.anonymous_jwt] = "not.a.jwt"
    before = AppPreference.count

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :redirect
    assert_equal before + 1, AppPreference.count
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_predicate cookies[name], :present?, "#{name} should be issued after the explicit write"
    end
  end

  test "a theme storage dependency failure preserves the current preference and its browser cookies" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :redirect
    jwt = cookies[PreferenceCookieName.anonymous_jwt]
    claims = PreferenceToken.decode(jwt, host:)
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
    issuance = preference.attributes
    theme = AppPreferenceTheme.find_by!(preference_id: preference.id)
    unavailable = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "preference storage unavailable" }

    AppPreference.stub(:transaction, unavailable) do
      assert_no_difference -> { AppPreference.count } do
        patch base_app_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: AppPreferenceThemeOption::LIGHT.to_s } }
      end
    end

    assert_response :service_unavailable
    assert_empty response.body
    assert_equal issuance, preference.reload.attributes
    assert_equal AppPreferenceThemeOption::DARK, theme.reload.option_id
    assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a signing key lookup failure rolls back a theme change and preserves the previous issuance" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!
    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }

    assert_response :redirect
    jwt = cookies[PreferenceCookieName.anonymous_jwt]
    claims = PreferenceToken.decode(jwt, host:)
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))
    issuance = preference.attributes
    theme = AppPreferenceTheme.find_by!(preference_id: preference.id)
    unavailable = ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "preference signing key unavailable" }

    PreferenceJwtConfiguration.stub(:private_key_for_active, unavailable) do
      assert_no_difference -> { AppPreference.count } do
        patch base_app_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: AppPreferenceThemeOption::LIGHT.to_s } }
      end
    end

    assert_response :service_unavailable
    assert_empty response.body
    assert_equal issuance, preference.reload.attributes
    assert_equal AppPreferenceThemeOption::DARK, theme.reload.option_id
    assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a signing key lookup failure on the first theme write leaves no preference or issued cookies" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    unavailable = ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "preference signing key unavailable" }

    PreferenceJwtConfiguration.stub(:private_key_for_active, unavailable) do
      assert_no_difference [-> { AppPreference.count }, -> { AppPreferenceTheme.count }] do
        patch base_app_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: AppPreferenceThemeOption::DARK.to_s } }
      end
    end

    assert_response :service_unavailable
    assert_empty response.body
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_nil cookies[name]
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  private

  def assert_shared_cookie_expired(name)
    entry = set_cookie_entries(name).sole

    assert_equal "", entry[:value]
    assert(entry[:"max-age"] == "0" || (entry[:expires] && Time.httpdate(entry[:expires]) < Time.current))
  end
end
