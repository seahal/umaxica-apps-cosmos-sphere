# frozen_string_literal: true

require "test_helper"

class JsonbKeysUniquenessValidatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "empty duplicate malformed and executable-looking JSON keys are rejected at declaration" do
    [nil, [], "key", ["key", "key"], [""], ["Upper"], [:key], ["a,b"], ["key') OR true --"]].each do |keys|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          attributes: [:context], keys: keys, predicate: { event_id: 18 }, writer: ChronicleRecord,
        )
      end
    end
  end

  test "predicate declarations require explicit scalar equality conditions" do
    [nil, {}, [], { "event_id" => 18 }, { event_id: [] }, { event_id: 18.5 },
     { event_id: Object.new },].each do |predicate|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          attributes: [:context], keys: %w(transaction_public_id halt_generation),
          predicate: predicate, writer: ChronicleRecord,
        )
      end
    end
  end

  test "the configured writer must be an explicit abstract Active Record connection owner" do
    [nil, Object, Object.new, OperatorChronicle].each do |writer|
      assert_raises(ArgumentError) do
        JsonbKeysUniquenessValidator.new(
          attributes: [:context], keys: %w(transaction_public_id halt_generation),
          predicate: { event_id: 18 }, writer: writer,
        )
      end
    end
  end
end
