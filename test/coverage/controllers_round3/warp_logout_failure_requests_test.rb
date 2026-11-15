# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundThreeWarpLogoutFailureRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "an explicitly routed private Warp alias cannot invent a registered logout return URI" do
    [
      ["rp_warp_app", "warp.app.localhost", "client", "warp/app"],
      ["rp_warp_org", "warp.org.localhost", "operator", "warp/org"],
    ].each do |connection, host, resource_type, namespace|
      browser = open_session
      browser.host!(host)
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "alias-logout-subject", sid: "alias-logout-#{connection}",
        absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::RSA.generate(3072)
      claims = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "alias-logout-subject",
        "sid" => "alias-logout-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "alias-logout-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      access = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        OidcOpRevocationClient.stub(
          :revoke, ->(**) {
                     flunk("a missing return registration cannot authorize a handoff")
                   },
        ) do
          browser.post(
            "/sign/out", params: { ri: "jp" }, headers: {
              "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end

      assert_equal 422, browser.response.status
      assert_nil browser.response.location
      assert_nil enrollment.session.reload.revoked_at
      assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      assert_equal enrollment.session.public_id, browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css('script[data-page="app"]').text)

      assert_equal "#{namespace}/sign/outs/unavailable", page.fetch("component")
      assert_equal "/sign/out?ri=jp", page.fetch("props").fetch("retry").fetch("action")
    end
  end

  test "a writer update failure keeps the authenticated Warp session and refuses completion" do
    host = ENV.fetch("PUBLIC_WARP_STAFF_URL")
    host!(host)
    https!
    cell = RpCellBinding.fetch("rp_warp_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "writer-failure-subject", sid: "writer-failure-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::RSA.generate(3072)
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "writer-failure-subject",
      "sid" => "writer-failure-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "writer-failure-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    access = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    refused_writes = 0
    database_failure =
      ->(*, **) {
        refused_writes += 1
        raise ActiveRecord::ConnectionNotEstablished
      }
    jwks.stub(:lookup, lookup) do
      RpWarpOrgRecord.connected_to(role: :writing) do
        RpWarpOrgRecord.connection_pool.with_connection do |database|
          # Rails 9 UPDATE uses QueryIntent through these adapter APIs, not exec_update.
          database.stub(:update, database_failure) do
            database.stub(:update_with_result, database_failure) do
              post "/sign/out", params: { ri: "jp" }, headers: {
                "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
              }
            end
          end
        end
      end
    end

    assert_equal 1, refused_writes
    assert_response :service_unavailable
    assert_nil response.location
    assert_nil enrollment.session.reload.revoked_at
    assert_equal access, cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    page = JSON.parse(Nokogiri::HTML(response.body).at_css('script[data-page="app"]').text)

    assert_equal "warp/org/sign/outs/unavailable", page.fetch("component")
  end
end
