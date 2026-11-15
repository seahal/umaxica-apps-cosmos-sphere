# frozen_string_literal: true

require "test_helper"

class JsonbKeysUniquenessValidatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  METADATA = {
    attributes: ["((context ->> transaction_public_id))"],
    scope: "((context ->> halt_generation))",
    conditions: -> { where(event_id: 18) },
    source_attribute: :context,
  }.freeze
  VALID = {
    **METADATA,
    keys: %w(transaction_public_id halt_generation),
    predicate: { event_id: 18 },
    writer: ChronicleRecord,
  }.freeze

  test "empty duplicate malformed and executable-looking JSON keys are rejected at declaration" do
    [nil, [], "key", ["key", "key"], [""], ["Upper"], [:key], ["a,b"], ["key') OR true --"]].each do |keys|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          **METADATA, keys: keys, predicate: { event_id: 18 }, writer: ChronicleRecord,
        )
      end
    end
  end

  test "predicate declarations require explicit scalar equality conditions" do
    [nil, {}, [], { "event_id" => 18 }, { event_id: [] }, { event_id: 18.5 },
     { event_id: Object.new },].each do |predicate|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          **METADATA, keys: %w(transaction_public_id halt_generation),
                      predicate: predicate, writer: ChronicleRecord,
        )
      end
    end
  end

  test "the configured writer must be an explicit abstract Active Record connection owner" do
    [nil, Object, Object.new, OperatorChronicle].each do |writer|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          **METADATA, keys: %w(transaction_public_id halt_generation),
                      predicate: { event_id: 18 }, writer: writer,
        )
      end
    end
  end

  test "uniqueness metadata for the released checker is required at declaration" do
    [VALID.except(:source_attribute), VALID.merge(source_attribute: "context"), VALID.except(:scope),
     VALID.merge(scope: :halt_generation), VALID.except(:conditions), VALID.merge(conditions: "event_id = 18"),]
      .each do |invalid|
        assert_raises(ArgumentError) { JsonbKeysUniquenessValidator.new(invalid) }
      end

    assert_equal :uniqueness, JsonbKeysUniquenessValidator.new(VALID.dup).kind
  end
end
