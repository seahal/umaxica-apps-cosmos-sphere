# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundTwoCallbackRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "real browser code flows distinguish OP refusal dependency malformed tokens and verified identities" do
    [
      [:refused, 303], [:dependency, 503], [:incomplete, 303], [:invalid_id_token, 303],
      [:missing_auth_time, 303], [:future_auth_time, 303], [:malformed_auth_time, 303],
      [:invalid_expiry, 303], [:storage_unavailable, 503], [:issuer_mismatch, 303],
      [:logged_out_sid, 303], [:already_enrolled, 303],
      [:success, 302], [:login_required, 303], [:access_denied, 303], [:missing_code, 303],
    ].each do |outcome, expected_status|
      browser = open_session
      host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      browser.host!(host)
      browser.https!
      browser.get("/sign", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      browser.post(
        "/sign", params: { ri: "jp", target_link_uri: "/" }, headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 303, browser.response.status
      redirect = URI.parse(browser.response.location)
      authorization = Rack::Utils.parse_nested_query(redirect.query)
      if authorization.key?("rt")
        jump_payload, = JWT.decode(authorization.fetch("rt"), nil, false)
        authorization = Rack::Utils.parse_nested_query(URI.parse(jump_payload.fetch("url")).query)
      end
      state = authorization.fetch("state")
      issuer = OidcIssuer.for_resource_type("client")
      key = OpenSSL::PKey::RSA.generate(3072)
      identity = {
        "iss" => issuer,
        "aud" => ["core-app-jp"],
        "sub" => "callback-#{outcome}",
        "sid" => "callback-sid-#{outcome}",
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "nonce" => authorization.fetch("nonce"),
        "jti" => "identity-#{outcome}",
        "typ" => "id-token+jwt",
        "act" => "client",
        "auth_time" => 1.minute.ago.to_i,
      }
      if outcome == :logged_out_sid
        RpCoreAppOpSessionBinding.create!(
          issuer:, realm: "app", client_id: "core-app-jp", sid: identity.fetch("sid"), revoked_at: Time.current,
        )
      elsif outcome == :already_enrolled
        enrollment = RpCallbackCommitter.call(
          cell: RpCellBinding.fetch("rp_core_app"), issuer:, subject: identity.fetch("sub"),
          sid: identity.fetch("sid"), absolute_expires_at: 10.minutes.from_now,
        )

        assert_predicate enrollment, :success?
      end
      identity.delete("auth_time") if outcome == :missing_auth_time
      identity["auth_time"] = 10.minutes.from_now.to_i if outcome == :future_auth_time
      identity["auth_time"] = "not-a-time" if outcome == :malformed_auth_time
      id_token = JWT.encode(identity, key, "PS256", { kid: "external-op", typ: "id-token+jwt" })
      access_claims = identity.except("nonce", "typ", "act").merge(
        "client_id" => "core-app-jp", "scope" => "openid profile", "authn_ctx" => "normal",
      )
      access = JWT.encode(access_claims, key, "PS256", { kid: "external-op", typ: "at+jwt" })
      tokens = {
        id_token:,
        access_token: access,
        refresh_token: "callback-sid-#{outcome}.opaque",
        token_type: "Bearer",
        expires_in: 300,
        refresh_token_expires_in: 600,
      }
      tokens[:refresh_token_expires_in] = "invalid" if outcome == :invalid_expiry
      tokens.delete(:id_token) if outcome == :incomplete
      tokens[:id_token] = "malformed" if outcome == :invalid_id_token
      remote_outcome = %i(refused dependency).include?(outcome) ? outcome : :success
      result = OidcOpTokenClient::Result.new(
        outcome: remote_outcome,
        token_response: (remote_outcome == :success) ? tokens : nil,
        error: (remote_outcome == :success) ? nil : "invalid_grant",
      )
      query = { state:, iss: issuer, code: "external-authorization-code", ri: "jp" }
      query[:error] = outcome.to_s if %i(login_required access_denied).include?(outcome)
      query.delete(:code) if outcome == :missing_code
      query[:iss] = "https://#{"x" * (issuer.bytesize - "https://".bytesize)}" if outcome == :issuer_mismatch
      jwks = OidcOpJwksClient.for_resource_type("client")
      lookup = OidcOpJwksClient::Lookup.new(status: :found, key:, reason: nil)
      exchanges = 0
      OidcOpTokenClient.stub(
        :authorization_code, ->(**arguments) {
                               exchanges += 1

                               assert_equal "external-authorization-code", arguments.fetch(:code)
                               verifier_digest = Digest::SHA256.digest(arguments.fetch(:code_verifier))
                               challenge = Base64.urlsafe_encode64(verifier_digest, padding: false)

                               assert_equal authorization.fetch("code_challenge"), challenge
                               result
                             },
      ) do
        if outcome == :storage_unavailable
          RpCoreAppRecord.stub(:transaction, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished }) do
            jwks.stub(:lookup, lookup) { browser.get("/oidc/callback", params: query) }
          end
        else
          jwks.stub(:lookup, lookup) { browser.get("/oidc/callback", params: query) }
        end
      end

      assert_equal(%i(login_required access_denied missing_code issuer_mismatch).include?(outcome) ? 0 : 1, exchanges)
      assert_equal expected_status, browser.response.status, outcome
      assert_equal "no-store", browser.response.headers["Cache-Control"]
      if outcome == :success
        assert_equal "/", URI.parse(browser.response.location).path
        session_id = browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
        local_session = RpCoreAppSession.includes(op_session_binding: :identity_binding).find_by!(public_id: session_id)

        assert_equal identity.fetch("sid"), local_session.op_session_binding.sid
        assert_equal identity.fetch("sub"), local_session.op_session_binding.identity_binding.subject
        assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
        assert_equal tokens.fetch(:refresh_token), browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      elsif %i(dependency storage_unavailable).include?(outcome)
        assert_nil browser.response.location
        assert_equal "text/plain", browser.response.media_type
      else
        expected_path = (outcome == :login_required) ? "/sign" : "/sign/interruption"

        assert_equal expected_path, URI.parse(browser.response.location).path
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      end
      if outcome == :logged_out_sid
        anchor = RpCoreAppOpSessionBinding.find_by!(sid: identity.fetch("sid"))

        assert_predicate anchor, :revoked?
        assert_nil anchor.identity_binding_id
        assert_empty anchor.sessions
      elsif outcome == :already_enrolled
        anchor = RpCoreAppOpSessionBinding.find_by!(sid: identity.fetch("sid"))

        assert_not_predicate anchor, :revoked?
        assert_equal 1, anchor.sessions.count
      end
      next if %i(dependency storage_unavailable).include?(outcome)

      jwks.stub(:lookup, lookup) { browser.get("/oidc/callback", params: query) }

      assert_equal 303, browser.response.status
      assert_equal "/sign/interruption", URI.parse(browser.response.location).path
    end
  end

  test "an expired RP pending flow is consumed and fails closed before code exchange" do
    browser = open_session
    host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    browser.host!(host)
    browser.https!
    browser.post(
      "/sign", params: { ri: "jp" }, headers: {
        "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, browser.response.status
    authorization = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query)
    if authorization.key?("rt")
      handoff, = JWT.decode(authorization.fetch("rt"), nil, false)
      authorization = Rack::Utils.parse_nested_query(URI.parse(handoff.fetch("url")).query)
    end
    jti = JWT.decode(authorization.fetch("state"), nil, false).first.fetch("jti")
    verification = OidcStateJwt::Verification.new(
      valid: true,
      jti:,
      target_link_uri: nil,
      reason: nil,
    )

    travel_to(Time.current + OidcCallback::OIDC_PENDING_FLOW_TTL + 1.minute) do
      OidcStateJwt.stub(:verify, verification) do
        browser.get(
          "/oidc/callback", params: {
            state: authorization.fetch("state"),
            iss: OidcIssuer.for_resource_type("client"),
            code: "expired-flow-code",
          },
        )
      end
    end

    assert_equal 303, browser.response.status
    assert_equal "/sign/interruption", URI.parse(browser.response.location).path
    assert_nil browser.cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
  end
end
