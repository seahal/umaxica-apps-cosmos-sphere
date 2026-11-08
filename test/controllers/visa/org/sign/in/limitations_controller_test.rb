# frozen_string_literal: true

require "test_helper"

class Visa::Org::Sign::In::LimitationsControllerTest < ActionController::TestCase
  tests Visa::Org::Sign::In::LimitationsController
  self.fixture_table_names = []

  setup do
    reference_now = OperatorSignInFlow.database_now
    OperatorSessionLimitResolutionState::DEFAULTS.each do |id|
      OperatorSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = reference_now
        state.updated_at = reference_now
      end
    end
    @request.host = Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host
    @actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @existing = OperatorToken.create!(authentication_epoch: 0, staff: @actor)
    @flow = OperatorSignInFlow.create!(
      principal_id: @actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: reference_now,
      expires_at: reference_now + 5.minutes,
      authentication_method: "passkey",
      authentication_event_at: reference_now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    @binding = SecureRandom.urlsafe_base64(32)
    @issuance = OperatorSessionLimitResolutionTransaction.issue!(
      actor: @actor,
      sign_in_flow: @flow,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    @resolution = @issuance.transaction
    @gate = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => Time.current.to_i,
      "pt" => "/sign/in",
      "flow" => @flow.public_id,
      "resolution_challenge" => @issuance.challenge,
      "resolution_binding" => @binding,
      "actor_type" => "Operator",
    }
  end

  test "the browser holding the pending operator flow sees its sessions" do
    @existing.update!(last_used_at: OperatorSignInFlow.database_now)
    get :show, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    props = page.fetch("props")
    session = props.fetch("sessions").sole

    assert_equal "visa/org/sign/in/limitations/show", page.fetch("component")
    assert_equal "resolution_challenge", props.fetch("resolution").fetch("field")
    assert_equal @issuance.challenge, props.fetch("resolution").fetch("value")
    assert_not props.fetch("can_continue")
    assert_equal @existing.id, SessionLimitResolutionTokenRef.find_operator_token(
      session.fetch("session_ref"),
    ).id
    assert_match(/Last used /, session.fetch("last_used_label"))
  end

  test "without a browser locator the page refuses" do
    get :show, params: { ri: "jp" }

    assert_response :gone
    assert_predicate @resolution.reload, :pending?
  end

  test "a requested challenge that differs from the browser gate is refused" do
    get :show, params: { ri: "jp", resolution_challenge: "another-challenge" },
               session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :gone
    assert_predicate @resolution.reload, :pending?
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
  end

  test "a browser binding that differs from the issued resolution is refused" do
    get :show, params: { ri: "jp" },
               session: { SessionLimitGate::GATE_SESSION_KEY => @gate.merge("resolution_binding" => "wrong") }

    assert_response :gone
    assert_predicate @resolution.reload, :pending?
  end

  test "an expired sign-in flow cannot use its pending resolution" do
    expired_at = OperatorSignInFlow.database_now - 1.second
    @flow.update!(issued_at: expired_at - 5.minutes, expires_at: expired_at)

    get :show, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :gone
    assert_predicate @existing.reload, :active_status?
    assert_predicate @resolution.reload, :pending?
  end

  test "the page allows continuation after another session frees capacity" do
    @existing.revoke!
    get :show, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    props = page.fetch("props")

    assert props.fetch("can_continue")
    assert_empty props.fetch("sessions")
  end

  test "a session belonging to another operator cannot be selected" do
    other = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    foreign_token = OperatorToken.create!(authentication_epoch: 0, staff: other)
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    patch :update, params: { ri: "jp", session_ref: SessionLimitResolutionTokenRef.issue(foreign_token) },
                   session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :unprocessable_content
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)

    assert_equal I18n.t("session_limit.invalid_session"), page.dig("props", "error")
    assert_predicate foreign_token.reload, :active_status?
    assert_predicate @resolution.reload, :pending?
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
  end

  test "replacing the selected operator session completes the pending sign-in" do
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    patch :update, params: { ri: "jp", session_ref: SessionLimitResolutionTokenRef.issue(@existing) },
                   session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :see_other
    assert_predicate @existing.reload, :revoked?
    assert_predicate @flow.reload, :sign_in_completed?
    assert_predicate @resolution.reload, :resolved?
    issued = OperatorToken.where(staff_id: @actor.id).order(:id).last

    assert_equal issued.id, @flow.token_id
    assert_not_nil issued.root_login_established_at
  end

  test "explicit continuation completes without revoking when capacity becomes free" do
    @existing.revoke!
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    post :update, params: { ri: "jp", continue: "1" },
                  session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :see_other
    assert_predicate @flow.reload, :sign_in_completed?
    assert_predicate @resolution.reload, :resolved?
    assert_predicate @existing.reload, :revoked?
    assert_equal OperatorToken::MAX_SESSIONS_PER_STAFF,
                 OperatorToken.active_status.where(staff_id: @actor.id).count
  end

  test "all active operator sessions remain visible when capacity is full" do
    other = OperatorToken.create!(authentication_epoch: 0, staff: @actor)
    get :show, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    props = page.fetch("props")

    assert_not props.fetch("can_continue")
    session_ids =
      props.fetch("sessions").map do |entry|
        SessionLimitResolutionTokenRef.find_operator_token(entry.fetch("session_ref")).id
      end

    assert_equal [@existing.id, other.id].sort, session_ids.sort
  end

  test "OIDC resolution finalizes authorization after replacing the operator session" do
    @resolution.cancel!(
      actor: @actor,
      challenge: @issuance.challenge,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    @flow.cancel_sign_in!
    now = OperatorSignInFlow.database_now
    flow = OperatorSignInFlow.create!(
      principal_id: @actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
      authentication_method: "passkey",
      authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    client_id = "core-org-jp"
    state = SecureRandom.hex(16)
    client = OidcClientRegistry.find!(client_id)
    oidc_issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: client.redirect_uris.first,
        scope: "openid profile",
        state: state,
        nonce: SecureRandom.hex(16),
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
      },
    )
    oidc_transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "org", login_challenge: oidc_issuance.transaction.login_challenge,
      actor: @actor, session_ref: nil, auth_method: "passkey", authentication_event_at: now,
    ).transaction
    binding = SecureRandom.urlsafe_base64(32)
    issuance = OperatorSessionLimitResolutionTransaction.issue!(
      actor: @actor,
      sign_in_flow: flow,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(binding),
      oidc_authorization_transaction: oidc_transaction,
    )
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    patch :update, params: { ri: "jp", session_ref: SessionLimitResolutionTokenRef.issue(@existing) },
                   session: {
                     SessionLimitGate::GATE_SESSION_KEY => @gate.merge(
                       "flow" => flow.public_id,
                       "resolution_challenge" => issuance.challenge,
                       "resolution_binding" => binding,
                     ),
                   }

    assert_response :found
    assert_predicate @existing.reload, :revoked?
    assert_predicate flow.reload, :sign_in_completed?
    assert_predicate issuance.transaction.reload, :resolved?
    assert_predicate oidc_transaction.reload, :base_finalized?
    jump_token = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("rt")
    jump_payload, = JWT.decode(jump_token, nil, false)
    callback_params = URI.decode_www_form(URI.parse(jump_payload.fetch("url")).query).to_h

    assert_predicate callback_params.fetch("code"), :present?
    assert_equal state, callback_params.fetch("state")
  end

  test "cancelling ends the pending operator flow without revoking its session" do
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    delete :destroy, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_redirected_to base_org_sign_show_path(ri: "jp")
    assert_predicate @flow.reload, :sign_in_cancelled?
    assert_predicate @resolution.reload, :cancelled?
    assert_predicate @existing.reload, :active_status?
    assert_nil session[:org_sign_in_flow_locator]
    assert session[:inertia_clear_history]
  end

  test "cancelling an OIDC resolution returns to the protocol cancellation page" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    now = OperatorSignInFlow.database_now
    flow = OperatorSignInFlow.create!(
      principal_id: actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
      authentication_method: "passkey",
      authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    client_id = "core-org-jp"
    oidc_issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
      },
    )
    oidc_transaction = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "org", login_challenge: oidc_issuance.transaction.login_challenge,
      actor: actor, session_ref: nil, auth_method: "passkey", authentication_event_at: now,
    ).transaction
    binding = SecureRandom.urlsafe_base64(32)
    issuance = OperatorSessionLimitResolutionTransaction.issue!(
      actor: actor,
      sign_in_flow: flow,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(binding),
      oidc_authorization_transaction: oidc_transaction,
    )
    @request.headers["Origin"] = "http://#{@request.host}"
    @request.headers["Sec-Fetch-Site"] = "same-origin"

    delete :destroy, params: { ri: "jp" }, session: {
      SessionLimitGate::GATE_SESSION_KEY => @gate.merge(
        "flow" => flow.public_id,
        "resolution_challenge" => issuance.challenge,
        "resolution_binding" => binding,
      ),
    }

    assert_response :see_other
    assert_match %r{/oidc/cancellation\?}, response.location
    assert_includes response.location, "ri=jp"
    assert_predicate oidc_transaction.reload, :canceled?
    assert_predicate issuance.transaction.reload, :cancelled?
    assert_predicate flow.reload, :sign_in_cancelled?
  end
end
