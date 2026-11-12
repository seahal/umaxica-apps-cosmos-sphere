# frozen_string_literal: true

require "test_helper"

class ClientChronicleTest < ActiveSupport::TestCase
  fixtures :client_chronicle_events, :client_chronicle_levels

  test "historical actors and subjects do not require a canonical account database" do
    audit = ClientChronicle.create!(
      actor_id: 123_456_789, actor_type: "RetiredAccountOwner",
      subject_id: 987_654_321, subject_type: "Client", event_id: ClientChronicleEvent::LOGIN_SUCCESS,
    )

    assert_equal 123_456_789, audit.reload.actor_id
    assert_equal "RetiredAccountOwner", audit.actor_type
    assert_equal "Client", audit.subject_type
    assert_not_nil audit.occurred_at
  end

  test "absent actor metadata uses the existing historical subject snapshot" do
    audit = ClientChronicle.create!(
      subject_id: 987_654_321, subject_type: "Client",
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
    )

    assert_equal 987_654_321, audit.actor_id
    assert_equal "Client", audit.actor_type
  end

  test "missing subject metadata and unknown local event are rejected" do
    audit = ClientChronicle.new(actor_id: 123, actor_type: "HistoricalOwner", event_id: 999_999)

    assert_not audit.valid?
    assert_not_empty audit.errors[:subject_id]
    assert_not_empty audit.errors[:subject_type]
    assert_not_empty audit.errors[:event_id]
  end
end
