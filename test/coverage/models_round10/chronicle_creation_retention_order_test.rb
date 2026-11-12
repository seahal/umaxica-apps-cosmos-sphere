# frozen_string_literal: true

require "test_helper"

class ChronicleCreationRetentionOrderTest < ActiveSupport::TestCase
  test "an unbounded future creation timestamp cannot move a recorded retention window before creation" do
    now = Time.current.change(usec: 0)
    chronicle = ClientChronicle.create!(
      actor_id: 900_001, actor_type: "HistoricalOwner", subject_id: 900_002,
      subject_type: "HistoricalSubject", event_id: ClientChronicleEvent::LOGIN_SUCCESS, created_at: now,
      occurred_at: now, discard_at: now + 1.hour, purge_eligible_at: now + 2.hours,
    )

    assert_predicate chronicle, :valid?
    assert_not chronicle.update(created_at: Float::INFINITY)
    assert_includes chronicle.errors.details.fetch(:discard_at).pluck(:error), "must be >= created_at"
    assert_includes chronicle.errors.details.fetch(:purge_eligible_at).pluck(:error), "must be >= created_at"
    chronicle.reload

    assert_equal now, chronicle.created_at
    assert_equal now + 1.hour, chronicle.discard_at
    assert_equal now + 2.hours, chronicle.purge_eligible_at
    assert_predicate chronicle, :valid?
  end
end
