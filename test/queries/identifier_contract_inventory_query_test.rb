# frozen_string_literal: true

require "test_helper"

class IdentifierContractInventoryQueryTest < ActiveSupport::TestCase
  test "catalog scan reports database tables columns keys indexes and candidate hints" do
    result = IdentifierContractInventoryQuery.call(
      connection_specs: [
        { name: "primary", record_class: ApplicationRecord, ownership: "application" },
      ],
    )

    assert_equal IdentifierContractInventoryQuery::VERSION, result.version
    assert_match(/\A\d{4}-\d{2}-\d{2}T.*Z\z/, result.generated_at)
    assert_equal 1, result.connections.length

    connection = result.connections.fetch(0)

    assert_equal "primary", connection.fetch(:connection_name)
    assert_equal "application", connection.fetch(:ownership_scope)
    assert_match(/\Atest_primary_db(?:_\d+)?\z/, connection.fetch(:database_name))
    assert_match(/\A\d+\./, connection.fetch(:server_version))

    tables = connection.fetch(:tables)
    table_names = tables.map { |table| table.fetch("table_name") }

    assert_equal table_names.sort, table_names
    assert_includes table_names, "schema_migrations"
    assert_includes table_names, "ar_internal_metadata"
    assert_equal tables.length, connection.fetch(:summary).fetch(:table_count)
    assert_operator connection.fetch(:summary).fetch(:candidate_column_count), :>, 0
    assert_operator connection.fetch(:summary).fetch(:framework_table_count), :>=, 2

    metadata = tables.find { |table| table.fetch("table_name") == "ar_internal_metadata" }

    assert_equal "framework:rails", metadata.fetch("ownership_classification")
    assert_equal "single_non_bigint", metadata.fetch("primary_key_contract_hint")
    assert_equal ["key"], metadata.fetch("primary_key").map { |column| column.fetch("column_name") }
    key_column = metadata.fetch("columns").find { |column| column.fetch("column_name") == "key" }

    assert_empty key_column.fetch("candidate_hints")
    columns = tables.flat_map { |table| table.fetch("columns") }
    creator_id_column = columns.find { |column| column.fetch("column_name") == "creator_id" }

    assert_equal ["id_suffix"], creator_id_column.fetch("candidate_hints")
    id_column = columns.find { |column| column.fetch("column_name") == "id" }

    assert_equal ["primary_key"], id_column.fetch("candidate_hints")
    state_column = columns.find { |column| column.fetch("column_name") == "state" }

    assert_equal ["state"], state_column.fetch("candidate_hints")
    schema_migrations = tables.find { |table| table.fetch("table_name") == "schema_migrations" }

    assert_equal "framework:rails", schema_migrations.fetch("ownership_classification")
    assert_equal connection.fetch(:summary), result.to_h.fetch(:connections).fetch(0).fetch(:summary)
    json = JSON.parse(result.to_json)

    assert_equal result.version, json.fetch("version")
    assert_equal 1, json.fetch("connections").length
    assert_predicate result.connections, :frozen?
    assert_predicate tables, :frozen?
    assert_predicate tables.first.fetch("columns"), :frozen?
  end

  test "catalog scan connects through a named framework configuration and closes its pool" do
    result = IdentifierContractInventoryQuery.call(
      connection_specs: [{ name: "primary", ownership: "application" }],
    )

    assert_equal "primary", result.connections.fetch(0).fetch(:connection_name)
    assert_match(/\Atest_primary_db(?:_\d+)?\z/, result.connections.fetch(0).fetch(:database_name))
    assert_operator result.connections.fetch(0).fetch(:summary).fetch(:table_count), :>, 0
  end

  test "framework table prefixes are classified in their owning database" do
    result = IdentifierContractInventoryQuery.call(
      connection_specs: [{ name: "queue", ownership: "framework" }],
    )

    connection = result.connections.fetch(0)

    assert_match(/\Atest_queue_db(?:_\d+)?\z/, connection.fetch(:database_name))
    assert_equal "framework", connection.fetch(:ownership_scope)
    assert_operator connection.fetch(:summary).fetch(:framework_table_count), :>=, 2
    assert_equal "framework:solid_queue",
                 connection.fetch(:tables).find { |table| table.fetch("table_name") == "solid_queue_jobs" }
                   .fetch("ownership_classification")
  end

  test "default inventory reads each configured application and framework database" do
    result = IdentifierContractInventoryQuery.call

    assert_equal IdentifierContractInventoryQuery::CONNECTION_SPECS.map { |spec| spec.fetch(:name) },
                 result.connections.map { |connection| connection.fetch(:connection_name) }
    assert_equal result.connections.length, result.connections.map { |connection| connection.fetch(:database_name) }
      .uniq.length
    result.connections.each do |connection|
      assert_operator connection.fetch(:summary).fetch(:table_count), :>, 0, connection.fetch(:connection_name)
      assert_equal connection.fetch(:summary).fetch(:table_count), connection.fetch(:tables).length
    end
    assert_operator result.connections.sum { |connection|
      connection.fetch(:summary).fetch(:candidate_column_count)
    }, :>, 0
    assert_operator result.connections.sum { |connection|
      connection.fetch(:summary).fetch(:framework_table_count)
    }, :>, 0
  end

  test "connection specs reject missing empty and malformed inputs" do
    [
      [nil, ArgumentError, "connection_specs must be an Array"],
      [[], ArgumentError, "connection_specs must not be empty"],
      [["primary"], ArgumentError, "connection spec must be a Hash"],
      [[{}], KeyError, "key not found: :name"],
      [[{ name: "" }], ArgumentError, "connection name must not be empty"],
      [[{ name: "missing_database_name" }], ArgumentError,
       "unexpected database configuration for missing_database_name",],
    ].each do |specs, error_class, message|
      error =
        assert_raises(error_class, message) do
          IdentifierContractInventoryQuery.call(connection_specs: specs)
        end
      assert_equal message, error.message
    end
  end
end
