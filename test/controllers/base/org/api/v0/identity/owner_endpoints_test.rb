# frozen_string_literal: true

require "test_helper"

class BaseOrgIdentityOwnerEndpointsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    now = OpBaseOrgRecord.database_now
    @root = OperatorToken.create!(
      authentication_epoch: @operator.authentication_epoch, staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB, staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: now + 1.hour, root_login_established_at: now, established_authentication_method: "passkey",
    )
    @root.rotate_refresh_token!(now:)
    @root.device_session_record!
    @client = OidcClientRegistry.find!("base-org-ww")
    @grant = OpOrgGrant.create!(
      authentication_epoch: @root.authentication_epoch, operator_token: @root,
      oidc_client_id: @client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      refresh_token_expires_at: now + 1.hour,
    )
    @grant.issue_refresh_token!(now:)
    @access_token = AuthenticationTokenService.encode(
      @operator,
      host: @host, resource_type: "operator", session_public_id: @root.public_id,
      base_session_public_id: @root.public_id, oidc_sid: @grant.public_id, oidc_jti: @grant.oidc_jti,
      expires_at: now + 4.minutes, scopes: %w(openid profile), amr: ["passkey"],
      auth_time: @grant.oidc_auth_time,
      issuer: OidcIssuer.for_client(@client), audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
      subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: @client.client_id,
      authentication_context: @root.strict_authentication_context_value.to_s,
    )
  end

  test "an unselected ORG root reports an empty tuple without creating selection state" do
    path = base_org_api_v0_identity_selection_path
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: "https://#{@host}#{path}")
    before = @root.reload.attributes.slice(
      "selected_account_public_id", "selected_collective_public_id", "selected_collective_unit_public_id",
      "selected_avatar_public_id", "selected_at",
    )

    get path, headers: { "Authorization" => "Bearer #{@access_token}", "X-Client-Assertion" => assertion }

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal(
      { "account_public_id" => nil,
        "collective_public_id" => nil,
        "collective_unit_public_id" => nil,
        "avatar_public_id" => nil,
        "selected_at" => nil, },
      response.parsed_body,
    )
    assert_equal before, @root.reload.attributes.slice(*before.keys)
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "selection returns only the authenticated ORG root tuple and does not change its timestamp" do
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @root)
    @root.reload
    expected = {
      "account_public_id" => @root.selected_account_public_id,
      "collective_public_id" => @root.selected_collective_public_id,
      "collective_unit_public_id" => @root.selected_collective_unit_public_id,
      "avatar_public_id" => @root.selected_avatar_public_id,
      "selected_at" => @root.selected_at.iso8601(6),
    }
    path = base_org_api_v0_identity_selection_path
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: "https://#{@host}#{path}")

    get path, params: { account_public_id: "foreign-account", actor_ref: "foreign-operator" },
              headers: { "Authorization" => "Bearer #{@access_token}", "X-Client-Assertion" => assertion }

    assert_response :ok
    assert_equal expected, response.parsed_body
    assert_equal expected.fetch("selected_at"), @root.reload.selected_at.iso8601(6)
    assert_not_includes response.body, "foreign-account"
    assert_not_includes response.body, "foreign-operator"
  end

  test "standing returns a good account page scoped to the verified operator" do
    path = base_org_api_v0_identity_standing_path
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: "https://#{@host}#{path}")

    get path, params: { ri: "jp" },
              headers: { "Authorization" => "Bearer #{@access_token}",
                         "X-Client-Assertion" => assertion,
                         "X-Browser-Format" => "html",
                         "X-Browser-Url-Options" => '{"ri":"jp"}', }

    assert_response :ok
    assert_equal "application/json", response.media_type
    props = response.parsed_body.fetch("props")

    assert_equal "Account Standing", props.fetch("title")
    assert_equal "Current status: Good", props.fetch("status_label")
    assert_equal [], props.fetch("decisions")
    assert_equal base_org_identity_path(ri: "jp"), props.fetch("up_link").fetch("href")
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal :unauthenticated, Actor.current.actor_type
  end

  test "standing serializes visible timed and indefinite decisions but excludes another operator's decisions" do
    now = Time.current
    administrator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    timed = OrgEnforcementCase.create!(
      kind: "cooldown", state: "active", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: now - 1.minute, expires_at: now + 1.hour, reason_code: "abuse",
      principal_public_id: @operator.public_id, applied_by_operator_public_id: administrator.public_id,
    )
    indefinite = OrgEnforcementCase.create!(
      kind: "method_protection", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "operator", effective_at: now - 1.minute, reason_code: "security_incident",
      principal_public_id: @operator.public_id, applied_by_operator_public_id: administrator.public_id,
    )
    foreign_operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    foreign = OrgEnforcementCase.create!(
      kind: "method_protection", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "operator",
      effective_at: now - 1.minute, reason_code: "abuse", principal_public_id: foreign_operator.public_id,
      applied_by_operator_public_id: administrator.public_id,
    )
    path = base_org_api_v0_identity_standing_path
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: "https://#{@host}#{path}")

    get path, params: { principal_public_id: foreign_operator.public_id },
              headers: { "Authorization" => "Bearer #{@access_token}", "X-Client-Assertion" => assertion }

    assert_response :ok
    props = response.parsed_body.fetch("props")
    decisions = props.fetch("decisions").index_by { |decision| decision.fetch("public_id") }

    assert_equal "Current status: Notice", props.fetch("status_label")
    assert_equal [timed.public_id, indefinite.public_id].sort, decisions.keys.sort
    assert_equal "Cooldown", decisions.fetch(timed.public_id).fetch("kind")
    assert_equal "Abuse", decisions.fetch(timed.public_id).fetch("reason")
    assert_match(/\AEnds: /, decisions.fetch(timed.public_id).fetch("ends_at"))
    assert_nil decisions.fetch(indefinite.public_id).fetch("ends_at")
    assert_not_includes response.body, foreign.public_id
  end

  test "both owner endpoints reject absent client assertions and invalid bearer credentials" do
    [base_org_api_v0_identity_selection_path, base_org_api_v0_identity_standing_path].each do |path|
      get path, headers: { "Authorization" => "Bearer #{@access_token}" }

      assert_response :unauthorized
      assert_equal({ "error" => "invalid_client" }, response.parsed_body)
      assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: "https://#{@host}#{path}")

      get path, headers: { "Authorization" => "Bearer invalid-token", "X-Client-Assertion" => assertion }

      assert_response :unauthorized
      assert_equal({ "error" => "invalid_token" }, response.parsed_body)
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end

  test "client assertions cannot be reused or moved to another owner endpoint" do
    selection_path = base_org_api_v0_identity_selection_path
    standing_path = base_org_api_v0_identity_standing_path
    assertion = OidcClientAssertionJwt.issue(
      client_id: @client.client_id, token_url: "https://#{@host}#{selection_path}",
    )
    headers = { "Authorization" => "Bearer #{@access_token}", "X-Client-Assertion" => assertion }

    get(standing_path, headers:)

    assert_response :unauthorized
    assert_equal({ "error" => "invalid_client" }, response.parsed_body)

    get(selection_path, headers:)

    assert_response :ok

    get(selection_path, headers:)

    assert_response :unauthorized
    assert_equal({ "error" => "invalid_client" }, response.parsed_body)
  end
end
