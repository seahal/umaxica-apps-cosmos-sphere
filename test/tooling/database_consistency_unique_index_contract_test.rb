# frozen_string_literal: true

require "test_helper"
require "database_consistency"

class DatabaseConsistencyUniqueIndexContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "released checker matches a standard uniqueness validator and unique index" do
    validator =
      ClientChronicle.validators.find do |candidate|
        candidate.kind == :uniqueness && candidate.attributes == [:event_uuid]
      end
    index =
      ClientChronicle.connection_pool.with_connection do |connection|
        connection.indexes(:client_chronicles).find do |candidate|
          candidate.name == "index_client_chronicles_on_event_uuid"
        end
      end

    assert validator
    assert index
    assert_equal :ok, DatabaseConsistency::Checkers::UniqueIndexChecker.new(ClientChronicle, index).report.status
    assert_equal :ok,
                 DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(
                   ClientChronicle, :event_uuid,
                   validator,
                 ).report.status
  end
end
