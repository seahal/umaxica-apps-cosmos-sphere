# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundFourCredentialFailureRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "RP logout refuses malformed browser credentials before any OP revocation" do
    host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    host!(host)
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed-access"
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "untrusted-local-session"
    OidcOpRevocationClient.stub(:revoke, ->(**) { flunk("invalid browser credentials must not revoke an OP token") }) do
      post "/sign/out", params: { ri: "jp" }, headers: {
        "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
      }
    end

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.login_required"), response.body
    assert_nil response.location
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
  end

  test "Palm private JSON admission rejects an invalid presented pair and deletes both browser credentials" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed-access"
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = "presented-local-session"
    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("a missing refresh cookie must not dispatch to Access") }) do
      get "/dashboard", params: { ri: "jp" }, headers: { "Accept" => "application/json" }
    end

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :blank?
    assert_predicate cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE], :blank?
    assert_nil response.location
  end

  test "a JWKS outage between initial admission and logout's own verification preserves local authority" do
    host = ENV.fetch("PUBLIC_WARP_STAFF_URL")
    host!(host)
    https!
    cell = RpCellBinding.fetch("rp_warp_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "second-verification-subject", sid: "second-verification-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::RSA.generate(3072)
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "second-verification-subject",
      "sid" => "second-verification-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "second-verification-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    access = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    lookups = 0
    jwks.stub(
      :lookup, ->(*) {
                 lookups += 1
                 raise OidcOpJwksClient::FetchError, "key source unavailable" if lookups > 1

                 lookup
               },
    ) do
      post "/sign/out", params: { ri: "jp" }, headers: {
        "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
      }
    end

    assert_response :service_unavailable
    assert_equal 2, lookups
    assert_nil response.location
    assert_nil enrollment.session.reload.revoked_at
    assert_equal access, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    page = JSON.parse(Nokogiri::HTML(response.body).at_css('script[data-page="app"]').text)

    assert_equal "warp/org/sign/outs/unavailable", page.fetch("component")
  end
end
