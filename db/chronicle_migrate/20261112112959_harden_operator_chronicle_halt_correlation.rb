# frozen_string_literal: true

class HardenOperatorChronicleHaltCorrelation < ActiveRecord::Migration[8.2]
  def change
    # JSON null and arrays can satisfy key presence without producing a unique correlation.
    # IS TRUE rejects SQL UNKNOWN from missing keys; validation fails on existing invalid rows.
    add_check_constraint(
      :operator_chronicles,
      "event_id <> 18 OR ((" \
      "jsonb_typeof(context) = 'object' AND " \
      "jsonb_typeof(context->'transaction_public_id') = 'string' AND " \
      "(context->>'transaction_public_id') ~ '[^[:space:]]' AND " \
      "jsonb_typeof(context->'halt_generation') = 'string' AND " \
      "(context->>'halt_generation') ~ '[^[:space:]]'" \
      ") IS TRUE)",
      name: "chk_operator_chronicles_halt_correlation", validate: false,
    )
  end
end
