# frozen_string_literal: true

require "test_helper"
require "database_consistency"

# Runs the released database_consistency checkers against the real OperatorChronicle declaration
# and its partial JSONB expression unique index.
class DatabaseConsistencyJsonbUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @validator = OperatorChronicle.validators.find { |candidate| candidate.is_a?(JsonbKeysUniquenessValidator) }
    @index =
      OperatorChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:operator_chronicles).find { |candidate|
          candidate.name == "uniq_operator_chronicles_sign_flow_halted"
        }
      end
  end

  test "both checkers match the JSONB tuple validator and the partial unique index" do
    assert @validator
    assert @index
    assert_equal :ok, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, @index).report.status

    @validator.attributes.each do |attribute|
      report = DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(
        OperatorChronicle, attribute, @validator,
      ).report

      assert report
      assert_equal :ok, report.status
    end
  end

  test "the expression index fails when its model has no matching validator" do
    validators = OperatorChronicle.validators.reject { |candidate| candidate.equal?(@validator) }

    OperatorChronicle.stub(:validators, validators) do
      assert_equal :fail, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, @index).report.status
    end
  end

  test "a different partial predicate does not match the validator" do
    index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
      "operator_chronicles", "test_jsonb_tuple", true, @index.columns, where: "(event_id = 17)",
    )

    assert_equal :fail, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status
  end
end
