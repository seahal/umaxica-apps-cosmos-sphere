# frozen_string_literal: true

require "test_helper"

# Pins the restored Rails `primary` connection so the retired `platform`
# database cannot return through configuration or Flipper ownership.
class PrimaryDatabaseOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "primary is configured for test and owns db/migrate" do
    config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "primary")

    assert config
    assert_equal config.database, ActiveRecord::Base.connection.select_value("SELECT current_database()")
    assert_equal ["db/migrate"], Array(config.migrations_paths)
    assert_not config.replica?
  end

  test "the retired platform connection is gone" do
    names = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true).map(&:name)

    assert_includes names, "primary"
    assert_not_includes names, "platform"
    assert_not_includes names, "platform_replica"
    assert_not_includes names, "primary_replica"
  end

  test "Flipper Active Record models stay on primary while the suite uses memory" do
    assert_equal "primary", Flipper::Adapters::ActiveRecord::Model.connection_db_config.name

    adapter = Flipper.adapter
    adapter = adapter.adapter while adapter.respond_to?(:adapter)

    assert_kind_of Flipper::Adapters::Memory, adapter
  end

  test "specialized record classes keep their existing databases" do
    assert_equal "chronicle", ChronicleRecord.connection_db_config.name
    assert_equal "rp_core_app", RpCoreAppRecord.connection_db_config.name
    assert_equal "rp_core_org", RpCoreOrgRecord.connection_db_config.name
    assert_equal "rp_warp_app", RpWarpAppRecord.connection_db_config.name
    assert_equal "rp_warp_org", RpWarpOrgRecord.connection_db_config.name
    assert_equal "rp_palm_app", RpPalmAppRecord.connection_db_config.name
  end
end
