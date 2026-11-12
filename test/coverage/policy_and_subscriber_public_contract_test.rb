# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationPolicyPublicContractCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "unconfigured actions and aliases deny by default" do
    policy = ApplicationPolicy.new(Object.new)

    %i(index? show? create? update? destroy?).each do |query|
      assert_not policy.public_send(query), "#{query} must remain denied by default"
    end

    assert_not policy.apply(:edit?)
    assert_not policy.apply(:new?)
  end

  test "default relation scope returns no records" do
    policy = ApplicationPolicy.new(Object.new)
    relation = ChronicleRetentionPolicy.all

    assert_predicate policy.apply_scope(relation, type: :active_record_relation), :none?
  end
end

class ChronicleRecordPolicyPublicPayloadCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "audit payload accepts the public identifier and falls back to the database identifier" do
    identified = Struct.new(:public_id, :id).new("public-reference", "database-id")
    public_id_missing = Struct.new(:public_id, :id).new(nil, "database-id")

    assert_equal "public-reference", ChronicleRecordPolicy.actor_payload(identified).fetch(:actor_id)
    assert_equal "database-id", ChronicleRecordPolicy.subject_payload(public_id_missing).fetch(:subject_id)
  end

  test "public retention projection omits permanent records and expires temporary records" do
    occurred_at = Time.utc(2026, 11, 12, 10)
    permanent = ChronicleRetentionPolicy.new(permanent: true, duration_days: 0)
    temporary = ChronicleRetentionPolicy.new(permanent: false, duration_days: 30)

    assert_nil ChronicleRecordPolicy.erasable_at_for(policy: permanent, occurred_at: occurred_at)
    assert_equal occurred_at + 30.days,
                 ChronicleRecordPolicy.erasable_at_for(policy: temporary, occurred_at: occurred_at)
  end
end

class DeprecationNotificationSubscriberPublicBoundaryCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  Frame = Struct.new(:path, :lineno)

  test "invalid native backtrace locations emit an error record" do
    errors = []
    event = ActiveSupport::Notifications::Event.new(
      "deprecation.library", 0, 0, "test",
      {
        message: "Deprecated call",
        callstack: [Frame.new("vendor/library.rb", 0)],
        gem_name: "Library",
        deprecation_horizon: "3.0",
      },
    )

    Rails.logger.stub(:error, ->(entry) { errors << entry }) do
      DeprecationNotificationSubscriber.new.emit(event)
    end

    record = JSON.parse(errors.fetch(0))

    assert_equal "rails.deprecation.unrecordable", record.fetch("event")
    assert_equal "ArgumentError", record.dig("data", "error_class")
  end

  test "maximum multi-byte Unicode fields remain within the audit byte limit" do
    warnings = []
    separator = "\u{1F512}"
    event = ActiveSupport::Notifications::Event.new(
      "deprecation.library", 0, 0, "test",
      {
        message: separator * DeprecationNotificationSubscriber::MAX_MESSAGE_CODEPOINTS,
        callstack: [
          "vendor/#{separator * (DeprecationNotificationSubscriber::MAX_CALLSITE_CODEPOINTS - "vendor/".length)}:8",
        ],
        gem_name: separator * DeprecationNotificationSubscriber::MAX_FIELD_CODEPOINTS,
        deprecation_horizon: separator * DeprecationNotificationSubscriber::MAX_FIELD_CODEPOINTS,
      },
    )

    Rails.logger.stub(:warn, ->(entry) { warnings << entry }) do
      DeprecationNotificationSubscriber.new.emit(event)
    end

    json = warnings.fetch(0)
    record = JSON.parse(json)

    assert_operator json.bytesize, :<=, DeprecationNotificationSubscriber::MAX_LOG_BYTES
    assert_not record.dig("data", "truncated")
    assert_equal DeprecationNotificationSubscriber::MAX_MESSAGE_CODEPOINTS,
                 record.dig("data", "message").length
  end
end

class BrowserBlockNotificationSubscriberPublicBoundaryCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "missing optional request metadata still emits the security event" do
    messages = []
    event = ActiveSupport::Notifications::Event.new(
      "browser_block.action_controller", 0, 0, "test", { request: nil, versions: :modern },
    )

    Rails.logger.stub(:info, ->(entry) { messages << entry }) do
      BrowserBlockNotificationSubscriber.new.emit(event)
    end

    record = JSON.parse(messages.fetch(0))

    assert_equal BrowserBlockNotificationSubscriber::EVENT_NAME, record.fetch("event")
    assert_equal(
      { "browser" => "Mozilla", "browser_version" => "4.0", "required_versions" => "modern" },
      record.fetch("data"),
    )
  end
end
