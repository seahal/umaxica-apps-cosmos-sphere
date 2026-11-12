# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound8DeprecationJsonBudgetTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "HTML-escaped fields remain within the final JSON byte budget without losing callsite metadata" do
    warnings = []
    errors = []
    event = ActiveSupport::Notifications::Event.new(
      "deprecation.library", 0, 0, "round8",
      {
        message: "<" * 1000,
        gem_name: "<" * 100,
        deprecation_horizon: "<" * 100,
        callstack: ["#{"<" * 512}:9"],
      },
    )
    Rails.logger.stub(:warn, ->(entry) { warnings << entry }) do
      Rails.logger.stub(:error, ->(entry) { errors << entry }) do
        DeprecationNotificationSubscriber.new.emit(event)
      end
    end

    assert_empty errors
    assert_equal 1, warnings.length
    json = warnings.fetch(0)
    record = JSON.parse(json)
    data = record.fetch("data")

    assert_equal "rails.deprecation", record.fetch("event")
    assert_operator json.bytesize, :<=, DeprecationNotificationSubscriber::MAX_LOG_BYTES
    assert_predicate json, :valid_encoding?
    assert data.fetch("truncated")
    assert_operator data.fetch("message").length, :<, 1000
    assert_equal "<" * 100, data.fetch("gem_name")
    assert_equal "<" * 100, data.fetch("deprecation_horizon")
    assert_equal({ "file" => "<" * 512, "line" => 9 }, data.fetch("callsite"))
  end

  test "a callsite line too large for any bounded record emits only an unrecordable error class" do
    warnings = []
    errors = []
    line_digits = "9" * 9000
    event = ActiveSupport::Notifications::Event.new(
      "deprecation.library", 0, 0, "round8",
      {
        message: "private-deprecation-message",
        gem_name: "private-library-name",
        deprecation_horizon: "private-horizon",
        callstack: ["private/callsite.rb:#{line_digits}"],
      },
    )
    Rails.logger.stub(:warn, ->(entry) { warnings << entry }) do
      Rails.logger.stub(:error, ->(entry) { errors << entry }) do
        DeprecationNotificationSubscriber.new.emit(event)
      end
    end

    assert_empty warnings
    assert_equal 1, errors.length
    record = JSON.parse(errors.fetch(0))

    assert_equal "rails.deprecation.unrecordable", record.fetch("event")
    assert_equal({ "error_class" => "RangeError" }, record.fetch("data"))
    assert_not_includes errors.fetch(0), "private-"
    assert_not_includes errors.fetch(0), "callsite.rb"
    assert_not_includes errors.fetch(0), line_digits
  end
end
