# frozen_string_literal: true

require "test_helper"

class OperatorChronicleExpressionUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    OperatorChronicleEvent.insert_all(
      [{ id: OperatorChronicleEvent::SIGN_FLOW_HALTED }, { id: OperatorChronicleEvent::LOGGED_IN }], unique_by: :id,
    )
    OperatorChronicleLevel.insert_all([{ id: OperatorChronicleLevel::NOTHING }], unique_by: :id)
    level = OperatorChronicleLevel.find(OperatorChronicleLevel::NOTHING)
    @attributes = {
      actor_id: 123_456_789,
      actor_type: "Operator",
      staff_chronicle_event: OperatorChronicleEvent.find(OperatorChronicleEvent::SIGN_FLOW_HALTED),
      staff_chronicle_level: level,
      subject_type: "OrgNormalSignInTransaction",
      subject_id: 1,
      occurred_at: Time.utc(2026, 11, 12),
      context: { "transaction_public_id" => "expression-transaction", "halt_generation" => "1" },
    }
  end

  test "duplicate validation raises the existing uniqueness exception before an insertion" do
    OperatorChronicle.create!(@attributes)
    duplicate = OperatorChronicle.new(@attributes)

    error = assert_raises(ActiveRecord::RecordNotUnique) { duplicate.valid? }

    assert_nil error.cause
    assert_predicate duplicate, :new_record?
  end

  test "unrelated JSON fields cannot hide an existing correlation during create" do
    OperatorChronicle.create!(@attributes)
    attributes = @attributes.merge(context: @attributes.fetch(:context).merge("reason_code" => "another-reason"))

    assert_raises(ActiveRecord::RecordNotUnique) { OperatorChronicle.create!(attributes) }
  end

  test "different transactions and generations remain independent" do
    contexts = [
      { transaction_public_id: "a", halt_generation: "1" },
      { transaction_public_id: "a", halt_generation: "2" },
      { transaction_public_id: "b", halt_generation: "1" },
      { transaction_public_id: "quote'parameter", halt_generation: "1" },
    ]

    contexts.each do |context|
      assert_predicate OperatorChronicle.create!(@attributes.merge(context: context)), :persisted?
    end
  end

  test "other audit event correlations can repeat and do not conflict with a halt" do
    OperatorChronicle.create!(@attributes)
    attributes = @attributes.merge(staff_chronicle_event: OperatorChronicleEvent.find(OperatorChronicleEvent::LOGGED_IN))

    2.times { assert_predicate OperatorChronicle.create!(attributes), :persisted? }
  end

  test "updates exclude the same persisted row but reject adopting another halt correlation" do
    original = OperatorChronicle.create!(@attributes)
    original.update!(context: @attributes.fetch(:context).merge("reason_code" => "updated-reason"))
    other = OperatorChronicle.create!(
      @attributes.merge(context: { transaction_public_id: "other-transaction", halt_generation: "1" }),
    )
    other.context = @attributes.fetch(:context)

    assert_predicate original, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { other.valid? }
  end

  test "duplicate validation queries the writer even when the caller selects the reading role" do
    context = { "transaction_public_id" => "writer-only-correlation", "halt_generation" => "1" }
    attributes = @attributes.merge(context: context)
    OperatorChronicle.create!(attributes)
    duplicate = OperatorChronicle.new(attributes)
    query_roles = []
    subscription =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        sql = event.payload.fetch(:sql)
        query_roles << ChronicleRecord.current_role if sql.include?("operator_chronicles") && sql.include?("->>")
      end
    begin
      ChronicleRecord.connected_to(role: :reading) do
        assert_raises(ActiveRecord::RecordNotUnique) { duplicate.valid? }
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    assert_equal [:writing], query_roles
  end

  test "direct inserts retain the native PostgreSQL unique violation for the same correlation" do
    original = OperatorChronicle.create!(@attributes)
    attributes = original.attributes.except("id")

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        OperatorChronicle.transaction(requires_new: true) { OperatorChronicle.insert_all!([attributes]) }
      end
    assert_kind_of PG::UniqueViolation, error.cause
  end

  test "malformed correlations still reach their owning database constraint" do
    contexts = [
      {}, ["transaction_public_id", "halt_generation"],
      { transaction_public_id: nil, halt_generation: "1" },
      { transaction_public_id: 1, halt_generation: "1" },
    ]

    contexts.each do |context|
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          OperatorChronicle.transaction(requires_new: true) do
            OperatorChronicle.create!(@attributes.merge(context: context))
          end
        end
      assert_kind_of PG::CheckViolation, error.cause
    end
  end

  test "projected halt and other audit records can update unrelated fields without loading context" do
    events = [
      OperatorChronicleEvent::SIGN_FLOW_HALTED,
      OperatorChronicleEvent::LOGGED_IN,
    ]
    events.each do |event_id|
      original = OperatorChronicle.create!(
        @attributes.merge(staff_chronicle_event: OperatorChronicleEvent.find(event_id)),
      )
      projected = OperatorChronicle.select(OperatorChronicle.column_names - ["context"]).find(original.id)

      assert_not projected.has_attribute?(:context)
      assert_predicate projected, :valid?
      projected.update!(current_value: "unrelated update")

      assert_equal "unrelated update", original.reload.current_value
      assert_equal @attributes.fetch(:context), original.context
      assert_not projected.has_attribute?(:context)
    end
  end

  test "validator configuration rejects absent keys invalid predicates and unrelated writer ownership" do
    options = {
      attributes: ["((context ->> transaction_public_id))"],
      scope: "((context ->> halt_generation))",
      conditions: -> { where(event_id: 18) },
      source_attribute: :context,
      keys: %w(transaction_public_id halt_generation),
      predicate: { event_id: 18 },
      writer: ChronicleRecord,
      strict: ActiveRecord::RecordNotUnique,
    }

    [options.merge(keys: []), options.merge(keys: ["unsafe'key"]), options.merge(predicate: {}),
     options.merge(predicate: { event_id: [18] }), options.merge(writer: OperatorChronicle),].each do |invalid|
      assert_raises(ArgumentError) { JsonbKeysUniquenessValidator.new(invalid) }
    end

    validator = JsonbKeysUniquenessValidator.new(options)

    assert_raises(ArgumentError) { validator.validate(RpCoreAppCallbackState.new) }
  end

  test "predicate configuration rejects a value whose Ruby type differs from its database column" do
    validator = JsonbKeysUniquenessValidator.new(
      attributes: ["((context ->> transaction_public_id))"], scope: "((context ->> halt_generation))",
      conditions: -> { where(event_id: 18) }, source_attribute: :context,
      keys: %w(transaction_public_id halt_generation),
      predicate: { event_id: "18" }, writer: ChronicleRecord,
    )

    assert_raises(ArgumentError) { validator.validate(OperatorChronicle.new(@attributes)) }
  end

  test "predicate configuration rejects a missing database column instead of treating it as nil" do
    validator = JsonbKeysUniquenessValidator.new(
      attributes: ["((context ->> transaction_public_id))"], scope: "((context ->> halt_generation))",
      conditions: -> { where(event_id: 18) }, source_attribute: :context,
      keys: %w(transaction_public_id halt_generation),
      predicate: { nonexistent_event_column: nil }, writer: ChronicleRecord,
    )

    assert_raises(ArgumentError) { validator.validate(OperatorChronicle.new(@attributes)) }
  end
end
