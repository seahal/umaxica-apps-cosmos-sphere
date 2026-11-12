# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Enforces the controller inheritance contract:
#   Every peripheral controller must inherit directly from a surface ApplicationController
#   or BareController. Controller-to-controller inheritance is forbidden.
#
# When a violation is fixed, remove it from KNOWN_VIOLATIONS.
# If this test fails with a new violation, the PR must either fix the inheritance
# or add an explicit entry to KNOWN_VIOLATIONS with a documented reason.
class ControllerInheritanceInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Pre-existing controller-to-controller inheritance violations that have not yet
  # been refactored. Each entry is the controller source path relative to Rails.root.
  # Do not add new entries without a documented reason.
  KNOWN_VIOLATIONS = [
    # Sign::Org::Sign::Up::* inheriting from Sign::Org::Sign::Up::* base controllers.

  ].to_set.freeze

  # Controllers that are themselves allowed to be base classes
  # (i.e., other controllers may inherit from these within KNOWN_VIOLATIONS above).
  # These must themselves inherit from ApplicationController or ActionController::Base.
  PERMITTED_LOCAL_BASES = Set.new.freeze

  # Scans all controller source files and returns paths (relative to Rails.root)
  # whose class declaration inherits from a non-approved base.
  # Approved bases: ApplicationController, BareController, ActionController::Base,
  # PreAccessController, FullAccessController,
  # PreferencesBaseController, and any class defined in PERMITTED_LOCAL_BASES.
  APPROVED_BASE_PATTERN = /
    ApplicationController
    | BareController
    | ActionController
    | PreAccessController
    | FullAccessController
    | PreferencesBaseController
    | AuthorityController
    | ::Base\b
    | BaseController\b
  /x

  test "no new controller-to-controller inheritance violations are introduced" do
    detected = detect_inheritance_violations

    new_violations = detected - KNOWN_VIOLATIONS
    stale_entries = KNOWN_VIOLATIONS - detected

    messages = []

    unless new_violations.empty?
      header = "New controller-to-controller inheritance violations " \
               "(fix inheritance or add to KNOWN_VIOLATIONS with a documented reason):"
      messages << "#{header}\n#{new_violations.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    unless stale_entries.empty?
      messages << "KNOWN_VIOLATIONS entries that no longer exist or are now fixed (remove them):\n" \
                  "#{stale_entries.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    assert_empty messages, messages.join("\n\n")
  end

  private

  def detect_inheritance_violations
    Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
      relative = path.relative_path_from(Rails.root).to_s
      next if PERMITTED_LOCAL_BASES.include?(relative)

      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      # Extract the inheritance clause from the class declaration.
      match = content.match(/class\s+\S+Controller\s*<\s*(\S+)/)
      next unless match

      superclass_ref = match[1]
      next if superclass_ref.match?(APPROVED_BASE_PATTERN)

      relative
    end.to_set
  end
end
