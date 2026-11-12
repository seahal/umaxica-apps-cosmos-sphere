# frozen_string_literal: true

require "test_helper"

class ClientChronicleEventUuidConsistencyTest < ActiveSupport::TestCase
  fixtures :client_chronicle_events, :client_chronicle_levels

  test "a non-null event UUID is unique in model validation and PostgreSQL" do
    attributes = {
      actor_id: 123_456_789,
      actor_type: "Client",
      subject_type: "Client",
      subject_id: "987654321",
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      event_uuid: "dd4669ee-9f71-4a52-a96c-ce90db905054",
    }
    original = ClientChronicle.create!(attributes)
    duplicate = ClientChronicle.new(attributes)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.details[:event_uuid].pluck(:error), :taken
    assert_predicate original, :valid?
    assert_predicate ClientChronicle.new(attributes.merge(event_uuid: "b8ca643d-1f0e-46b1-af8c-31716cce52f6")), :valid?

    raw = original.attributes.except("id", "created_at", "updated_at")
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientChronicle.transaction(requires_new: true) { ClientChronicle.insert_all!([raw]) }
    end
  end

  test "legacy events without a UUID remain independent valid audit records" do
    attributes = {
      actor_id: 123_456_789,
      actor_type: "Client",
      subject_type: "Client",
      subject_id: "987654321",
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      event_uuid: nil,
    }

    first = ClientChronicle.create!(attributes)
    second = ClientChronicle.create!(attributes)

    assert_nil first.event_uuid
    assert_nil second.event_uuid
    assert_not_equal first.id, second.id
    assert_predicate first, :valid?
    assert_predicate second, :valid?
  end
end
