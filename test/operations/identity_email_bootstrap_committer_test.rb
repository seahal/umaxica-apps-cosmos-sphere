# frozen_string_literal: true

require "test_helper"

class IdentityEmailBootstrapCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @actor = clients(:one)
    @credential = @actor.client_emails.create!(
      address: "bootstrap-#{SecureRandom.hex(8)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @credential.finalize_binding!
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    @transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "none",
      purpose: "bootstrap",
      step_up_required: false,
      allowed_methods: [IdentityEmailBootstrapCommitter::METHOD],
      audience: "step_up:app",
      token_binding: @token.public_id,
    )
    @session = ClientStepUpSession.create!(
      user_token: @token,
      step_up_ceremony_transaction_ref: @transaction.transaction_id,
      scope: @transaction.required_scope,
      return_to: "/identity/emails",
      status: "PENDING",
      discard_at: @transaction.expires_at,
    )
  end

  test "consumes a pending Email bootstrap without recording Step-Up freshness" do
    result = IdentityEmailBootstrapCommitter.call!(
      actor: @actor, token: @token, transaction: @transaction, credential: @credential,
    )

    assert_same @transaction, result
    assert_predicate @transaction.reload, :consumed?
    assert_equal "email_otp", @transaction.method
    assert_equal @credential.public_id, @transaction.verified_credential_ref
    assert_nil @token.reload.last_step_up_at
  end

  test "dispatches a valid org bootstrap through Operator-owned session records" do
    operator = Operator.create!(
      security_mode_id: OperatorSecurityMode::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
    )
    credential = operator.staff_emails.create!(
      address: "org-bootstrap-#{SecureRandom.hex(8)}@example.test",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    transaction = OperatorStepUpCeremonyTransaction.create_transaction!(
      actor_ref: operator.public_id,
      session_ref: token.public_id,
      required_scope: "settings_email",
      required_aal: "none",
      purpose: "bootstrap",
      step_up_required: false,
      allowed_methods: [IdentityEmailBootstrapCommitter::METHOD],
      audience: "step_up:org",
      token_binding: token.public_id,
    )
    OperatorStepUpSession.create!(
      staff_token: token,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope,
      return_to: "/identity/emails",
      status: "PENDING",
      discard_at: transaction.expires_at,
    )

    result = IdentityEmailBootstrapCommitter.call!(
      actor: operator, token: token, transaction: transaction, credential: credential,
    )

    assert_same transaction, result
    assert_predicate transaction.reload, :consumed?
    assert_equal "email_otp", transaction.method
    assert_equal credential.public_id, transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "refuses an Email credential owned by another Client before changing the transaction" do
    foreign_credential = clients(:two).client_emails.create!(
      address: "foreign-bootstrap-#{SecureRandom.hex(8)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    foreign_credential.finalize_binding!

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, credential: foreign_credential,
        )
      end

    assert_equal "session_binding_mismatch", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_PENDING, @transaction.reload.status
  end

  test "refuses a ticket whose session binding differs from the locked token" do
    mismatched_transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id,
      session_ref: SecureRandom.base58(21),
      required_scope: "settings_email",
      required_aal: "none",
      purpose: "bootstrap",
      step_up_required: false,
      allowed_methods: [IdentityEmailBootstrapCommitter::METHOD],
      audience: "step_up:app",
      token_binding: @token.public_id,
    )
    @session.update!(step_up_ceremony_transaction_ref: mismatched_transaction.transaction_id)

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: @token, transaction: mismatched_transaction, credential: @credential,
        )
      end

    assert_equal "session_binding_mismatch", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_PENDING, mismatched_transaction.reload.status
  end

  test "maps a missing bootstrap session to a binding refusal" do
    @session.destroy!

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, credential: @credential,
        )
      end

    assert_equal "session_binding_mismatch", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_PENDING, @transaction.reload.status
  end

  test "refuses an expired bootstrap transaction" do
    @transaction.update!(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, credential: @credential,
        )
      end

    assert_equal "transaction_expired", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_PENDING, @transaction.reload.status
  end

  test "refuses a revoked token before consuming a bootstrap" do
    token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id,
      session_ref: token.public_id,
      required_scope: "settings_email",
      required_aal: "none",
      purpose: "bootstrap",
      step_up_required: false,
      allowed_methods: [IdentityEmailBootstrapCommitter::METHOD],
      audience: "step_up:app",
      token_binding: token.public_id,
    )
    token.revoke!
    ClientStepUpSession.create!(
      user_token: token,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope,
      return_to: "/identity/emails",
      status: "PENDING",
      discard_at: transaction.expires_at,
    )

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: token, transaction: transaction, credential: @credential,
        )
      end

    assert_equal "session_expired", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_REVOKED, transaction.reload.status
  end

  test "refuses a bootstrap that does not authorize Email OTP" do
    @transaction.update!(allowed_methods: "totp")

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: @actor, token: @token, transaction: @transaction, credential: @credential,
        )
      end

    assert_equal "unsupported_method", error.code
    assert_equal StepUpCeremonyTransactionable::STATUS_PENDING, @transaction.reload.status
  end

  test "refuses a non-authenticatable actor before looking up a bootstrap session" do
    actor = clients(:reserved_user)
    token = ClientToken.new(user_id: actor.id, public_id: "reserved-bootstrap-token")
    transaction = ClientStepUpCeremonyTransaction.new
    credential = ClientEmail.new(user_id: actor.id, user_email_status_id: ClientEmailStatus::VERIFIED)

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: actor, token: token, transaction: transaction,
          credential: credential,
        )
      end

    assert_equal "authorization_denied", error.code
  end

  test "refuses unsupported actor classes at the public operation boundary" do
    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityEmailBootstrapCommitter.call!(
          actor: Object.new, token: Object.new, transaction: Object.new, credential: Object.new,
        )
      end

    assert_equal "session_binding_mismatch", error.code
  end
end
