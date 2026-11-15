# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require_relative "../../lib/architecture_baseline"

# Ratchet for the Umaxica architecture cops.
#
# The recorded per-file counts reject any new violation, including one added to a file that already
# carries debt. RuboCop itself runs without exclusions. Regenerate the count inventory with
# `bin/rails architecture:baseline` after reducing violations.
class ArchitectureBaselineTest < ActiveSupport::TestCase
  def test_no_file_exceeds_its_recorded_architecture_debt
    measured = ArchitectureBaseline.measure
    recorded = ArchitectureBaseline.recorded

    ArchitectureBaseline::COPS.each do |cop|
      recorded_files = recorded.fetch(cop)
      measured_files = measured.fetch(cop)

      assert_empty measured_files, "#{cop} must have no outstanding offenses."

      measured_files.each do |path, count|
        allowed = recorded_files.fetch(path, 0)

        assert_operator count, :<=, allowed,
                        "#{path} has #{count} #{cop} offenses but the baseline allows #{allowed}. " \
                        "Fix the new violation; do not regenerate the baseline to hide it."
      end
    end
  end

  def test_baseline_does_not_list_resolved_files
    measured = ArchitectureBaseline.measure

    ArchitectureBaseline::COPS.each do |cop|
      stale = ArchitectureBaseline.recorded.fetch(cop).keys - measured.fetch(cop).keys

      assert_empty stale,
                   "#{cop} baseline lists files with no remaining offenses. " \
                   "Run bin/rails architecture:baseline to drop them."
    end
  end
end
