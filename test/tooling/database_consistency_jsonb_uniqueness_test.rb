# frozen_string_literal: true

require "test_helper"
require "database_consistency"

class DatabaseConsistencyJsonbUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "both checkers match the actual JSONB tuple validator and partial unique index" do
    validator = OperatorChronicle.validators.find { |candidate| candidate.kind == :jsonb_keys_uniqueness }
    index =
      OperatorChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:operator_chronicles).find { |candidate|
          candidate.name == "uniq_operator_chronicles_sign_flow_halted"
        }
      end

    assert validator
    assert index
    assert_equal :ok, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status
    report = DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(OperatorChronicle, :context, validator).report

    assert report
    assert_equal :ok, report.status
  end

  test "equivalent parentheses quoted identifiers text casts and tuple order match" do
    expressions = [
      "(context ->> 'transaction_public_id'::text), (context ->> 'halt_generation'::text)",
      "((\"context\" ->> 'halt_generation')), ((\"context\" ->> 'transaction_public_id'))",
    ]
    expressions.each do |columns|
      index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        "operator_chronicles", "test_jsonb_tuple", true, columns, where: "((event_id = 18))",
      )

      assert_equal :ok, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status
    end
  end

  test "wrong columns keys extraction functions casts and extra tuple members remain failures" do
    expressions = [
      "(other_context ->> 'transaction_public_id'), (context ->> 'halt_generation')",
      "(context ->> 'wrong_key'), (context ->> 'halt_generation')",
      "(context ->> 'Transaction_public_id'), (context ->> 'halt_generation')",
      "(context -> 'transaction_public_id'), (context ->> 'halt_generation')",
      "lower(context ->> 'transaction_public_id'), (context ->> 'halt_generation')",
      "((context ->> 'transaction_public_id')::bigint), (context ->> 'halt_generation')",
      "(context ->> 'transaction_public_id'), (context ->> 'halt_generation'), level_id",
      "(context ->> 'transaction_public_id'), (context ->> 'halt_generation'), (context ->> 'halt_generation')",
    ]
    expressions.each do |columns|
      index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        "operator_chronicles", "test_jsonb_tuple", true, columns, where: "event_id = 18",
      )

      assert_equal :fail, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status,
                   columns
    end
  end

  test "absent different and narrower partial predicates do not match" do
    [nil, "event_id = 17", "event_id = 18 AND level_id = 0", "event_id = 18 OR event_id = 17"].each do |predicate|
      index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        "operator_chronicles", "test_jsonb_tuple", true,
        "(context ->> 'transaction_public_id'), (context ->> 'halt_generation')", where: predicate,
      )

      assert_equal :fail, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status
    end
  end

  test "the expression index still fails when its model has no matching validator" do
    index =
      OperatorChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:operator_chronicles).find { |candidate|
          candidate.name == "uniq_operator_chronicles_sign_flow_halted"
        }
      end
    validators = OperatorChronicle.validators.reject { |candidate| candidate.kind == :jsonb_keys_uniqueness }

    OperatorChronicle.stub(:validators, validators) do
      assert_equal :fail, DatabaseConsistency::Checkers::UniqueIndexChecker.new(OperatorChronicle, index).report.status
    end
  end

  test "JSONB validators with a missing or differently scoped unique index still fail the reverse check" do
    [
      { keys: %w(transaction_public_id wrong_key), predicate: { event_id: 18 } },
      { keys: %w(transaction_public_id halt_generation), predicate: { event_id: 17 } },
    ].each do |options|
      validator = JsonbKeysUniquenessValidator.new(
        **options, attributes: [:context], writer: ChronicleRecord, strict: ActiveRecord::RecordNotUnique,
      )
      report = DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(
        OperatorChronicle, :context,
        validator,
      ).report

      assert report
      assert_equal :fail, report.status
    end
  end

  test "a nonunique expression index cannot satisfy a JSONB uniqueness validator" do
    validator = OperatorChronicle.validators.find { |candidate| candidate.kind == :jsonb_keys_uniqueness }
    index = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
      "operator_chronicles", "test_jsonb_tuple", false,
      "(context ->> 'transaction_public_id'), (context ->> 'halt_generation')", where: "event_id = 18",
    )

    assert_not DatabaseConsistency::Helper.unique_index_matches_validator?(
      OperatorChronicle, index, :context,
      validator,
    )
  end

  test "JSONB partial predicates preserve case inside string literals" do
    validator = JsonbKeysUniquenessValidator.new(
      attributes: [:context], keys: %w(transaction_public_id halt_generation),
      predicate: { subject_type: "Operator" }, writer: ChronicleRecord, strict: ActiveRecord::RecordNotUnique,
    )
    exact = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
      "operator_chronicles", "test_jsonb_tuple", true,
      "(context ->> 'transaction_public_id'), (context ->> 'halt_generation')", where: "subject_type = 'Operator'",
    )
    wrong_case = ActiveRecord::ConnectionAdapters::IndexDefinition.new(
      "operator_chronicles", "test_jsonb_tuple", true,
      "(context ->> 'transaction_public_id'), (context ->> 'halt_generation')", where: "subject_type = 'operator'",
    )

    assert DatabaseConsistency::Helper.unique_index_matches_validator?(OperatorChronicle, exact, :context, validator)
    assert_not DatabaseConsistency::Helper.unique_index_matches_validator?(
      OperatorChronicle, wrong_case, :context,
      validator,
    )
  end

  test "ordinary nullable column uniqueness still matches in both directions" do
    validator =
      ClientChronicle.validators.find do |candidate|
        candidate.kind == :uniqueness && candidate.attributes == [:event_uuid]
      end
    index =
      ClientChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:client_chronicles).find { |candidate|
          candidate.name == "index_client_chronicles_on_event_uuid"
        }
      end

    assert_equal :ok, DatabaseConsistency::Checkers::UniqueIndexChecker.new(ClientChronicle, index).report.status
    assert_equal :ok,
                 DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(
                   ClientChronicle, :event_uuid,
                   validator,
                 ).report.status
  end

  test "checker correspondence rejects predicate configurations that the real validator cannot apply" do
    index =
      OperatorChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:operator_chronicles).find { |candidate|
          candidate.name == "uniq_operator_chronicles_sign_flow_halted"
        }
      end
    [{ event_id: "18" }, { nonexistent_column: 18 }].each do |predicate|
      validator = JsonbKeysUniquenessValidator.new(
        attributes: [:context], keys: %w(transaction_public_id halt_generation),
        predicate: predicate, writer: ChronicleRecord, strict: ActiveRecord::RecordNotUnique,
      )

      assert_raises(ArgumentError) do
        DatabaseConsistency::Helper.unique_index_matches_validator?(OperatorChronicle, index, :context, validator)
      end
    end
  end
end
