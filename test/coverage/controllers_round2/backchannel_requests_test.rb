# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTwoBackchannelRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "each retained callback receiver commits a signed logout and accepts its replay without a second receipt" do
    [
      ["rp_core_app", "PUBLIC_CORE_SERVICE_URL", "client", RpCoreAppSession],
      ["rp_core_org", "PUBLIC_CORE_STAFF_URL", "operator", RpCoreOrgSession],
      ["rp_warp_app", "PUBLIC_WARP_SERVICE_URL", "client", RpWarpAppSession],
      ["rp_warp_org", "PUBLIC_WARP_STAFF_URL", "operator", RpWarpOrgSession],
      ["rp_palm_app", "PUBLIC_PALM_SERVICE_URL", "client", RpPalmAppSession],
    ].each do |connection, host_setting, resource_type, session_class|
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "backchannel-subject", sid: "logout-#{connection}",
        absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::RSA.generate(3072)
      payload = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "iat" => Time.current.to_i,
        "exp" => 2.minutes.from_now.to_i,
        "sid" => "logout-#{connection}",
        "jti" => "logout-notice-#{connection}",
        "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
      }
      token = JWT.encode(payload, key, "PS256", { kid: "external-op", typ: "logout+jwt" })
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      jwks.stub(:lookup, lookup) do
        2.times do
          browser.post("/oidc/closures", params: { logout_token: token })

          assert_equal 200, browser.response.status
          assert_equal "no-store", browser.response.headers["Cache-Control"]
          assert_empty browser.response.body
        end
      end
      local_session = session_class.includes(op_session_binding: :event_receipts).find(enrollment.session.id)
      anchor = local_session.op_session_binding

      assert_predicate local_session.revoked_at, :present?
      assert_predicate anchor.revoked_at, :present?
      assert_equal 1, anchor.event_receipts.count
      assert_equal Digest::SHA256.digest(payload.fetch("jti")), anchor.event_receipts.first.jti_digest
    end
  end

  test "invalid signatures claims and missing credentials do not revoke local sessions" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "refused-logout", sid: "refused-sid", absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::RSA.generate(3072)
    claims = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "iat" => Time.current.to_i,
      "exp" => 2.minutes.from_now.to_i,
      "sid" => "refused-sid",
      "jti" => "refused-jti",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    [nil, "", "malformed", JWT.encode(
      claims.merge("aud" => ["palm-app-jp"]), key, "PS256",
      { kid: "external-op", typ: "logout+jwt" },
    ),
     JWT.encode(
       claims.merge("nonce" => "id-token-replay"), key, "PS256",
       { kid: "external-op", typ: "logout+jwt" },
     ),].each do |token|
      jwks.stub(:lookup, lookup) { post "/oidc/closures", params: { logout_token: token } }

      assert_response :bad_request
      assert_nil enrollment.session.reload.revoked_at
      assert_equal 0, enrollment.session.op_session_binding.event_receipts.count
    end
  end

  test "unavailable signing keys and a failed commit are retryable without reporting success" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL")
    https!
    issuer = OidcIssuer.for_resource_type("operator")
    key = OpenSSL::PKey::RSA.generate(3072)
    claims = {
      "iss" => issuer,
      "aud" => ["core-org-jp"],
      "iat" => Time.current.to_i,
      "exp" => 2.minutes.from_now.to_i,
      "sid" => "unknown-sid",
      "jti" => "retry-jti",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    token = JWT.encode(claims, key, "PS256", { kid: "external-op", typ: "logout+jwt" })
    jwks = OidcOpJwksClient.for_resource_type("operator")
    unavailable = OidcOpJwksClient::Lookup.new(status: :unavailable, key: nil, reason: "transport")
    jwks.stub(:lookup, unavailable) { post "/oidc/closures", params: { logout_token: token } }

    assert_response :service_unavailable
    found = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    jwks.stub(:lookup, found) do
      RpCoreOrgRecord.stub(:transaction, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
        post "/oidc/closures", params: { logout_token: token }
      end
    end

    assert_response :service_unavailable
    assert_equal 0, RpCoreOrgEventReceipt.count
  end
end
