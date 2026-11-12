# frozen_string_literal: true

require "test_helper"

class ComPreferenceChronicleTest < ActiveSupport::TestCase
  fixtures :com_preference_chronicles, :com_preference_chronicle_events, :com_preference_chronicle_levels

  test "historical subject snapshots survive without their external owner" do
    audit = com_preference_chronicles(:one)
    audit.update!(
      subject_id: 987_654_321, subject_type: "ComPreference", actor_id: 123_456_789,
      actor_type: "HistoricalOwner", discard_at: 1.day.from_now, purge_eligible_at: 2.days.from_now,
    )

    assert_equal 987_654_321, audit.reload.subject_id
    assert_equal "HistoricalOwner", audit.actor_type
    assert_not_nil audit.com_preference_chronicle_event
    assert_not_nil audit.com_preference_chronicle_level
  end

  test "missing historical subject identifiers remain invalid" do
    audit = com_preference_chronicles(:one)
    audit.subject_id = nil

    assert_not audit.valid?
    assert_raises(ActiveRecord::NotNullViolation) do
      ComPreferenceChronicle.transaction(requires_new: true) { audit.save!(validate: false) }
    end
    audit.subject_id = 987_654_321
    audit.subject_type = nil

    assert_not audit.valid?
  end
end
