# frozen_string_literal: true

class ValidateRpWarpOrgCallbackDigestLengths < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Rollback retains validation until the preceding migration removes the new checks.
    reversible do |direction|
      direction.up do
        validate_check_constraint(:rp_callback_states, name: "chk_rp_callback_states_state_digest_bytes")
        validate_check_constraint(:rp_callback_states, name: "chk_rp_callback_states_browser_binding_digest_bytes")
        validate_check_constraint(:rp_callback_states, name: "chk_rp_callback_states_nonce_digest_bytes")
      end
    end
  end
end
