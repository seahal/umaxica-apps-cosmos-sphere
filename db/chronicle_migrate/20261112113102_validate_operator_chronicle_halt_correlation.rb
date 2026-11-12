# frozen_string_literal: true

class ValidateOperatorChronicleHaltCorrelation < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    # Retain the old guard until every existing row satisfies the stronger contract.
    validate_check_constraint(:operator_chronicles, name: "chk_operator_chronicles_halt_correlation")
    remove_check_constraint(:operator_chronicles, name: "chk_operator_chronicles_sign_flow_halted_keys")
  end

  def down
    add_check_constraint(
      :operator_chronicles,
      "event_id <> 18 OR (context ? 'transaction_public_id' AND context ? 'halt_generation')",
      name: "chk_operator_chronicles_sign_flow_halted_keys", validate: false,
    )
    validate_check_constraint(:operator_chronicles, name: "chk_operator_chronicles_sign_flow_halted_keys")
  end
end
