# frozen_string_literal: true

require "test_helper"

class OperatorChronicleCorrelationConstraintTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    OperatorChronicleEvent.insert_all(
      [{ id: OperatorChronicleEvent::SIGN_FLOW_HALTED }, { id: OperatorChronicleEvent::LOGGED_IN }],
      unique_by: :id,
    )
    OperatorChronicleLevel.insert_all([{ id: OperatorChronicleLevel::NOTHING }], unique_by: :id)
    @attributes = {
      actor_type: "Operator",
      actor_id: 1,
      subject_type: "OrgNormalSignInTransaction",
      subject_id: 1,
      event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED,
      level_id: OperatorChronicleLevel::NOTHING,
      occurred_at: Time.utc(2026, 11, 12),
    }
  end

  test "halt correlations reject missing null empty whitespace and non-string keys through direct insertion" do
    invalid_values = [nil, "", " \t\r\n", 0, 1, false, true, [], {}]
    %w(transaction_public_id halt_generation).each do |key|
      context = { "transaction_public_id" => "txn-correlation", "halt_generation" => "1" }
      invalid_contexts = [context.except(key)] + invalid_values.map { |value| context.merge(key => value) }

      invalid_contexts.each do |invalid_context|
        error =
          assert_raises(ActiveRecord::StatementInvalid, "key=#{key}, context=#{invalid_context.inspect}") do
            OperatorChronicle.transaction(requires_new: true) do
              OperatorChronicle.insert_all!([@attributes.merge(context: invalid_context)])
            end
          end
        assert_kind_of PG::CheckViolation, error.cause
      end
    end
  end

  test "halt correlation context must be an object rather than a scalar array or null" do
    [nil, "correlation", 0, false, ["transaction_public_id", "halt_generation"]].each do |context|
      assert_raises(ActiveRecord::StatementInvalid, context.inspect) do
        OperatorChronicle.transaction(requires_new: true) do
          OperatorChronicle.insert_all!([@attributes.merge(context: context)])
        end
      end
    end
  end

  test "one-character and nonblank string correlations preserve independent transactions and generations" do
    contexts = [
      { transaction_public_id: "a", halt_generation: "0" },
      { transaction_public_id: "a", halt_generation: "1" },
      { transaction_public_id: "b", halt_generation: "0" },
      { transaction_public_id: " txn-correlation ", halt_generation: " 2 " },
    ]
    result = OperatorChronicle.insert_all!(contexts.map { |context| @attributes.merge(context: context) })

    assert_equal 4, result.rows.size
    assert_equal contexts.map(&:stringify_keys),
                 OperatorChronicle.where(id: result.rows.flatten).order(:id).pluck(:context)
  end

  test "identical halt correlations remain unique when model validations are bypassed" do
    attributes = @attributes.merge(context: { transaction_public_id: "txn-duplicate", halt_generation: "1" })
    OperatorChronicle.insert_all!([attributes])

    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorChronicle.transaction(requires_new: true) { OperatorChronicle.insert_all!([attributes]) }
    end
  end

  test "direct updates cannot erase an existing halt correlation" do
    attributes = @attributes.merge(context: { transaction_public_id: "txn-update", halt_generation: "1" })
    result = OperatorChronicle.insert_all!([attributes])
    record = OperatorChronicle.where(id: result.rows.flatten)

    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorChronicle.transaction(requires_new: true) do
        record.update_all(context: { transaction_public_id: "txn-update", halt_generation: nil })
      end
    end
    assert_equal attributes.fetch(:context).stringify_keys, record.pick(:context)
  end

  test "other audit events retain unrestricted context and may repeat correlations" do
    contexts = [{}, { transaction_public_id: nil, halt_generation: "" }, ["transaction_public_id", "halt_generation"]]
    attributes = @attributes.merge(event_id: OperatorChronicleEvent::LOGGED_IN)
    rows = contexts.flat_map { |context| [attributes.merge(context: context)] * 2 }

    assert_equal 6, OperatorChronicle.insert_all!(rows).rows.size
  end
end
