# typed: false
# frozen_string_literal: true

require "test_helper"

class Warp::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous root is rendered without shared caching" do
    host! ENV.fetch("PUBLIC_WARP_SERVICE_URL")
    https!
    get warp_app_root_path(ri: "jp")

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_includes response.body, "warp/app/roots/index"
  end

  test "an invalid RP access token does not manufacture a signed-in actor" do
    host! ENV.fetch("PUBLIC_WARP_SERVICE_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "invalid-access-token"
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "missing-local-session"
    get warp_app_root_path(ri: "jp")

    assert_response :success
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
    deletions = Array(response.headers["Set-Cookie"]).join("\n")

    assert_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::ACCESS_COOKIE)}=;/, deletions)
    assert_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::SESSION_COOKIE)}=;/, deletions)
  end
end
