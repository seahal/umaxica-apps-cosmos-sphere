# frozen_string_literal: true

require "test_helper"

# Committed `db/*_structure.sql` files are generated SQL schema authorities.
# Version-controlled migrations remain the authoring path; the dump must be a
# complete, schema-only replay artifact and must not silently become a mixed
# data export.
class DatabaseReconstructionAuthorityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SCHEMA_TABLE_MARKER = /CREATE (?:UNLOGGED )?TABLE public\./

  def structure_dumps
    dumps = Rails.root.glob("db/*_structure.sql")
    dumps << Rails.root.join("db/structure.sql") if Rails.root.join("db/structure.sql").exist?
    dumps.uniq
  end

  test "committed structure dumps contain real table definitions" do
    offenders =
      structure_dumps.filter_map do |path|
        content = path.read
        next if content.match?(SCHEMA_TABLE_MARKER)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty offenders,
                 "structure.sql dumps must contain table definitions:\n" \
                 "#{offenders.join("\n")}"
  end

  test "structure dumps contain no business data" do
    structure_dumps.each do |path|
      content = path.read

      business_inserts = content.lines.grep(/^INSERT INTO /).grep_v(/schema_migrations/)

      assert_empty business_inserts, "#{path.basename} contains business data"
    end
  end

  test "initial schema files are not loaded by migrations" do
    loaders =
      Rails.root.glob("db/**/*_migrate/*.rb").filter_map do |path|
        next unless path.read.match?(%r{db/initial_schemas/})

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty loaders,
                 "migrations must define their initial schema directly: #{loaders.join(", ")}"
    assert_empty Rails.root.glob("db/initial_schemas/*.rb"),
                 "obsolete schema-loader files must not remain as a second authority"
  end

  test "schema_format remains sql but dump_schema_after_migration is disabled" do
    assert_equal :sql, Rails.application.config.active_record.schema_format
    assert_not Rails.application.config.active_record.dump_schema_after_migration
  end

  test "primary uses the conventional db/structure.sql dump path" do
    assert_predicate Rails.root.join("db/structure.sql"), :exist?
    assert_not Rails.root.join("db/platform_structure.sql").exist?
    assert_match(SCHEMA_TABLE_MARKER, Rails.root.join("db/structure.sql").read)
  end
end
