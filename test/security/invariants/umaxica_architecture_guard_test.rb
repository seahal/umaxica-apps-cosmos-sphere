# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class UmaxicaArchitectureGuardTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      AUTHORITY_TABLE_PATTERNS = [
        /avatar_assignments/,
        /avatar_memberships/,
        /avatar_persona_bindings/,
        /avatar_agent_bindings/,
        /group_avatar_memberships/,
        /account_assignments/,
        /organization_memberships/,
        /unit_memberships/,
        /persona_assignments/,
        /agent_assignments/,
        /individual_assignments/,
      ].freeze

      DIRECT_WRITE_PATTERN = /\.(?:create!|update!|destroy!)\b/

      KNOWN_CONTROLLER_AUTHORITY_WRITES = [].freeze

      CROSS_DB_INTEGER_REFERENCE_PATTERN =
        # rubocop:disable Layout/LineLength -- splitting this regex corrupts it
        /\bt\.(?:bigint|integer|references)\(?\s*:?(?:avatar|account|organization|unit|identity|persona|agent|individual|member)_(?:id|identity_id)\b/
      # rubocop:enable Layout/LineLength

      KNOWN_CROSS_DB_INTEGER_REFERENCES = [].freeze

      test "controllers do not directly write authority or lifecycle tables beyond known violations" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(DIRECT_WRITE_PATTERN)
              next unless AUTHORITY_TABLE_PATTERNS.any? { |pattern| line.match?(pattern) }

              location = "#{relative_path}:#{index + 1}"
              next if KNOWN_CONTROLLER_AUTHORITY_WRITES.include?(location)

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Controller authority/lifecycle writes must move to use-case services:\n#{offenders.join("\n")}"
      end

      test "new migrations do not add cross database integer references beyond known violations" do
        offenders =
          Rails.root.glob("db/{app,com,org,avatars}_*_migrate/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(CROSS_DB_INTEGER_REFERENCE_PATTERN)

              location = "#{relative_path}:#{index + 1}"
              next if KNOWN_CROSS_DB_INTEGER_REFERENCES.include?(location)

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Use public_id/gid/surface/resource_type for cross-DB references, not integer IDs:\n" \
                     "#{offenders.join("\n")}"
      end

      private

      def production_ruby_paths
        Rails.root.glob("{app,lib}/**/*.rb").map { |path| Pathname.new(path) }
      end
    end
  end
end
