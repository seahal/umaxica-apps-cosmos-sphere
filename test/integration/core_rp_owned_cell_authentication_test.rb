# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpOwnedCellAuthenticationTest < ActionDispatch::IntegrationTest
  CELLS = [
    ["rp_core_app", "PUBLIC_CORE_SERVICE_URL", "client", "/"],
    ["rp_core_org", "PUBLIC_CORE_STAFF_URL", "operator", "/"],
    ["rp_warp_app", "PUBLIC_WARP_SERVICE_URL", "client", "/dashboard"],
    ["rp_warp_org", "PUBLIC_WARP_STAFF_URL", "operator", "/dashboard"],
    ["rp_palm_app", "PUBLIC_PALM_SERVICE_URL", "client", "/dashboard"],
  ].freeze

  test "each retained surface authenticates a signed Access token only with its own live local session" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    CELLS.each do |connection, host_setting, resource_type, path|
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      enrollment = RpCallbackCommitter.call(
        cell:, issuer:, subject: "retained-rp-subject", sid: "owned-#{connection}",
        absolute_expires_at: 10.minutes.from_now,
      )

      assert_predicate enrollment, :success?
      key = OpenSSL::PKey::EC.generate("secp384r1")
      payload = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "client_id" => cell.client_id,
        "sub" => "retained-rp-subject",
        "sid" => "owned-#{connection}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => "owned-access-#{connection}",
        "scope" => "openid profile",
        "authn_ctx" => "normal",
      }
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        JWT.encode(payload, key, "ES384", { kid: "external-op", typ: "at+jwt" })
      browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)

      jwks.stub(:lookup, lookup) do
        browser.get(path, params: { ri: "jp" })

        assert_equal 200, browser.response.status, connection
        assert_includes browser.response.headers.fetch("Cache-Control"), "no-store"

        browser.get("/sign", params: { ri: "jp" })

        assert_equal 403, browser.response.status, connection

        browser.cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
        browser.get("/sign", params: { ri: "jp" })

        assert_equal 200, browser.response.status, connection
        assert_includes browser.response.body, 'name="authenticity_token"'
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end

  test "each retained callback rejects missing state before any remote token exchange" do
    CELLS.each do |_connection, host_setting, _resource_type, _path|
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("missing state must not reach Access") }) do
        browser.get("/oidc/callback", params: { code: "untrusted-code" })
      end

      assert_equal 303, browser.response.status
      assert_equal "/sign/interruption", URI.parse(browser.response.location).path
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
      assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    end
  end

  test "Core app session refuses to replace unavailable Governance display names with local identifiers" do
    previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host!(ENV.fetch("PUBLIC_CORE_SERVICE_URL"))
    https!
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = OidcIssuer.for_resource_type("client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "profile-contract-subject", sid: "profile-contract-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "profile-contract-subject",
      "sid" => "profile-contract-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "profile-contract-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      JWT.encode(payload, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("client")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)

    jwks.stub(:lookup, lookup) do
      get("/api/v0/session", headers: { "Accept" => "application/json" })
    end

    assert_response :service_unavailable
    assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_not response.parsed_body.key?("actor")
    assert_not_includes response.body, enrollment.principal.public_id
  ensure
    previous_flag.nil? ? ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED") : ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] =
                                                                           previous_flag
  end
  test "a policy denial cannot fabricate the Governance identity required by the audit contract" do
    host! ENV.fetch("PUBLIC_WARP_STAFF_URL")
    https!
    cell = RpCellBinding.fetch("rp_warp_org")
    issuer = OidcIssuer.for_resource_type("operator")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject: "audit-contract-subject", sid: "audit-contract-sid",
      absolute_expires_at: 10.minutes.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = {
      "iss" => issuer,
      "aud" => [cell.client_id],
      "client_id" => cell.client_id,
      "sub" => "audit-contract-subject",
      "sid" => "audit-contract-sid",
      "iat" => Time.current.to_i,
      "nbf" => Time.current.to_i,
      "exp" => 5.minutes.from_now.to_i,
      "jti" => "audit-contract-access",
      "scope" => "openid profile",
      "authn_ctx" => "normal",
    }
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      JWT.encode(payload, key, "ES384", { kid: "external-op", typ: "at+jwt" })
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    jwks = OidcOpJwksClient.for_resource_type("operator")
    lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
    # An actual denying policy is the authorization collaborator. The request exercises the
    # production failure handler; the unavailable audit identity is never mocked or fabricated.
    denying_policy = RpPrincipalPolicy.new(Object.new, user: enrollment.principal)

    assert_not denying_policy.apply(:show?)
    jwks.stub(:lookup, lookup) do
      RpPrincipalPolicy.stub(:new, denying_policy) do
        get "/dashboard", params: { ri: "jp" }
      end
    end

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.location
    assert_equal I18n.t("errors.messages.temporarily_unavailable"), response.body
  end
  test "each cell completes a browser-bound OIDC callback and rejects state replay without another exchange" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sessions = {
      "rp_core_app" => RpCoreAppSession,
      "rp_core_org" => RpCoreOrgSession,
      "rp_warp_app" => RpWarpAppSession,
      "rp_warp_org" => RpWarpOrgSession,
      "rp_palm_app" => RpPalmAppSession,
    }
    CELLS.each do |connection, host_setting, resource_type, _path|
      browser = open_session
      browser.host!(ENV.fetch(host_setting))
      browser.https!
      cell = RpCellBinding.fetch(connection)
      issuer = OidcIssuer.for_resource_type(resource_type)
      browser.get("/sign", params: { ri: "jp" })
      csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/sign", params: { ri: "jp", target_link_uri: "/dashboard", authenticity_token: csrf },
                 headers: { "Origin" => "https://#{ENV.fetch(host_setting)}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, browser.response.status, connection
      jump = Rack::Utils.parse_query(URI.parse(browser.response.location).query)
      handoff, = JWT.decode(jump.fetch("rt"), nil, false)
      authorization = Rack::Utils.parse_query(URI.parse(handoff.fetch("url")).query)
      now = Time.current.to_i
      key = OpenSSL::PKey::EC.generate("secp384r1")
      identity = {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => "callback-#{connection}",
        "sid" => "callback-sid-#{connection}",
        "nonce" => authorization.fetch("nonce"),
        "iat" => now,
        "nbf" => now,
        "exp" => now + 300,
        "auth_time" => now,
        "jti" => "callback-id-#{connection}",
        "typ" => "id-token+jwt",
        "act" => resource_type,
      }
      access = identity.except("nonce", "typ", "act", "auth_time").merge(
        "client_id" => cell.client_id, "jti" => "callback-access-#{connection}",
        "scope" => "openid profile", "authn_ctx" => "normal",
      )
      response = {
        id_token: JWT.encode(identity, key, "ES384", { kid: "external-op", typ: "id-token+jwt" }),
        access_token: JWT.encode(access, key, "ES384", { kid: "external-op", typ: "at+jwt" }),
        refresh_token: "opaque-remote-refresh-#{connection}",
        expires_in: 300,
        refresh_token_expires_in: 600,
      }
      exchanges = 0
      exchange =
        lambda do |**arguments|
          exchanges += 1

          assert_equal cell.client_id, arguments.fetch(:client_id)
          assert_equal "single-use-code", arguments.fetch(:code)
          assert_equal authorization.fetch("redirect_uri"), arguments.fetch(:redirect_uri)
          assert_equal authorization.fetch("code_challenge"),
                       Base64.urlsafe_encode64(
                         Digest::SHA256.digest(arguments.fetch(:code_verifier)),
                         padding: false,
                       )

          OidcOpTokenClient::Result.new(outcome: :success, token_response: response, error: nil)
        end
      jwks = OidcOpJwksClient.for_resource_type(resource_type)
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      session_class = sessions.fetch(connection)
      previous_count = session_class.count
      OidcOpTokenClient.stub(:authorization_code, exchange) do
        jwks.stub(:lookup, lookup) do
          browser.get(
            "/oidc/callback",
            params: { ri: "jp", code: "single-use-code", iss: issuer, state: authorization.fetch("state") },
          )

          assert_equal 302, browser.response.status, connection
          assert_equal "/dashboard", URI.parse(browser.response.location).path
          assert_equal previous_count + 1, session_class.count
          local = session_class.includes(op_session_binding: :identity_binding)
            .find_by!(public_id: browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE])

          assert_equal "callback-sid-#{connection}", local.op_session_binding.sid
          assert_equal cell.client_id, local.op_session_binding.client_id
          assert_equal "callback-#{connection}", local.op_session_binding.identity_binding.subject
          assert_equal response.fetch(:access_token), browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
          assert_equal response.fetch(:refresh_token), browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]

          browser.get(
            "/oidc/callback",
            params: { ri: "jp", code: "single-use-code", iss: issuer, state: authorization.fetch("state") },
          )

          assert_equal 303, browser.response.status
          assert_equal "/sign/interruption", URI.parse(browser.response.location).path
          assert_equal previous_count + 1, session_class.count
          assert_equal 1, exchanges
        end
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery
  end
end
