# frozen_string_literal: true

require "test_helper"

class ChronicleAndReferencePublicBoundariesTest < ActiveSupport::TestCase
  test "missing historical metadata and event references remain invalid without external account reads" do
    [ClientChronicle, OperatorChronicle].each do |model|
      record = model.new(event_id: nil, actor_id: nil, actor_type: nil, subject_id: nil, subject_type: nil)

      assert_not record.valid?
      assert record.errors.of_kind?(:actor_id, :blank)
      assert record.errors.of_kind?(:actor_type, :blank)
      assert record.errors.of_kind?(:subject_id, :blank)
      assert record.errors.of_kind?(:subject_type, :blank)
      event_association = (model == ClientChronicle) ? :user_chronicle_event : :staff_chronicle_event

      assert record.errors.of_kind?(event_association, :blank)
    end
  end

  test "the retained operator level uses the inherited reference defaults contract idempotently" do
    before = OperatorChronicleLevel.order(:id).pluck(:id)
    OperatorChronicleLevel.ensure_defaults!

    assert_equal OperatorChronicleLevel::NOTHING, OperatorChronicleLevel.nothing_id
    assert_not_nil OperatorChronicleLevel.find_by(id: OperatorChronicleLevel::NOTHING)
    OperatorChronicleLevel.ensure_defaults!

    assert_equal (before + OperatorChronicleLevel::DEFAULTS).uniq.sort, OperatorChronicleLevel.order(:id).pluck(:id)
  end

  test "database clock converts a timestamp string supplied by its adapter into an instant" do
    connection = ChronicleRecord.lease_connection
    clock = Minitest::Mock.new
    clock.expect(:select_value, "2026-11-12 12:34:56.123456+00", ["SELECT clock_timestamp()", "DatabaseClock"])
    connection.stub(:select_value, ->(*arguments) { clock.select_value(*arguments) }) do
      actual = ChronicleRecord.database_now

      assert_equal Time.utc(2026, 11, 12, 12, 34, 56, 123_456), actual
    end
    clock.verify
  end

  test "a chronicle without a retention policy is invalid instead of dereferencing absent policy state" do
    chronicle = Chronicle.new(
      event_uuid: SecureRandom.uuid, action: "rp.validation", result: "intent",
      occurred_at: Time.current, chronicle_retention_policy: nil,
    )

    assert_not chronicle.valid?
    assert chronicle.errors.of_kind?(:chronicle_retention_policy, :blank)
  end

  test "authentication event timestamps accept already typed instants without reinterpretation" do
    instant = Time.utc(2026, 11, 12, 12, 34, 56)
    authentication = Actor::Authentication.new(access_claims: { "auth_time" => instant })

    assert_equal instant, authentication.authentication_event_at
  end
end
