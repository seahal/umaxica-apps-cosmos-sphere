# frozen_string_literal: true

class AddRpCoreOrgCallbackDigestLengths < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :rp_callback_states, "octet_length(state_digest) = 32",
      name: "chk_rp_callback_states_state_digest_bytes", validate: false,
    )
    add_check_constraint(
      :rp_callback_states, "octet_length(browser_binding_digest) = 32",
      name: "chk_rp_callback_states_browser_binding_digest_bytes", validate: false,
    )
    add_check_constraint(
      :rp_callback_states, "octet_length(nonce_digest) = 32",
      name: "chk_rp_callback_states_nonce_digest_bytes", validate: false,
    )
  end
end
