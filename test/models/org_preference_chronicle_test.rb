# frozen_string_literal: true

require "test_helper"

class OrgPreferenceChronicleTest < ActiveSupport::TestCase
  fixtures :org_preference_chronicles, :org_preference_chronicle_events, :org_preference_chronicle_levels

  test "historical subject snapshots survive without their external owner" do
    audit = org_preference_chronicles(:one)
    audit.update!(
      subject_id: 987_654_321, subject_type: "OrgPreference", actor_id: 123_456_789,
      actor_type: "HistoricalOwner", discard_at: 1.day.from_now, purge_eligible_at: 2.days.from_now,
    )

    assert_equal 987_654_321, audit.reload.subject_id
    assert_equal "HistoricalOwner", audit.actor_type
    assert_not_nil audit.org_preference_chronicle_event
    assert_not_nil audit.org_preference_chronicle_level
  end

  test "missing historical subject identifiers remain invalid" do
    audit = org_preference_chronicles(:one)
    audit.subject_id = nil

    assert_not audit.valid?
    assert_raises(ActiveRecord::NotNullViolation) do
      OrgPreferenceChronicle.transaction(requires_new: true) { audit.save!(validate: false) }
    end
    audit.subject_id = 987_654_321
    audit.subject_type = nil

    assert_not audit.valid?
  end
end
