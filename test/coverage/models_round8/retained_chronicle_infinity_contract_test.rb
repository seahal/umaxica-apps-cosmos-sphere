# frozen_string_literal: true

require "test_helper"

class RetainedChronicleInfinityContractTest < ActiveSupport::TestCase
  test "negative infinity is already inaccessible and eligible for purge through public readers" do
    record = ClientChronicle.new(discard_at: -Float::INFINITY, purge_eligible_at: -Float::INFINITY)
    now = Time.utc(2026, 11, 12, 12)

    assert_equal(-Float::INFINITY, record.discard_at)
    assert_equal(-Float::INFINITY, record.purge_eligible_at)
    assert_not record.accessible?(now)
    assert record.lapsed?(now)
    assert record.purgeable?(now)
  end

  test "updating a real chronicle preserves unbounded future retention" do
    record = ClientChronicle.create!(
      actor_id: 800_001, actor_type: "HistoricalOwner", subject_id: 800_002,
      subject_type: "HistoricalSubject", event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY,
    )
    record.update!(context: { "reason" => "retention remains unbounded" })
    record.reload

    assert_equal Float::INFINITY, record.discard_at
    assert_equal Float::INFINITY, record.purge_eligible_at
    assert_predicate record, :accessible?
    assert_not record.purgeable?
    assert_equal "retention remains unbounded", record.context.fetch("reason")
  end
end
