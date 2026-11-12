# frozen_string_literal: true

require "test_helper"

class RpSessionResolutionValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "every retained RP cell refuses a session before its identity binding is resolved" do
    cells = [
      [RpCoreAppSession, RpCoreAppOpSessionBinding],
      [RpCoreOrgSession, RpCoreOrgOpSessionBinding],
      [RpWarpAppSession, RpWarpAppOpSessionBinding],
      [RpWarpOrgSession, RpWarpOrgOpSessionBinding],
      [RpPalmAppSession, RpPalmAppOpSessionBinding],
    ]
    cells.each do |session_model, binding_model|
      unresolved = binding_model.create!(
        issuer: "https://access.example.test", realm: session_model::REALM,
        client_id: session_model::CLIENT_ID, sid: "round8-unresolved", identity_binding: nil,
      )

      assert_nil unresolved.reload.identity_binding_id
      session = session_model.new(
        op_session_binding: unresolved, absolute_expires_at: 1.minute.from_now,
        installed_generation: 0,
      )

      assert_not session.valid?
      assert_includes session.errors.details.fetch(:op_session_binding).pluck(:error),
                      "must have a resolved identity binding"
      assert_no_difference -> { session_model.count } do
        assert_not session.save
      end
      assert_predicate session, :new_record?
    end
  end

  test "every retained RP cell refuses a missing session anchor before persistence" do
    models = [RpCoreAppSession, RpCoreOrgSession, RpWarpAppSession, RpWarpOrgSession, RpPalmAppSession]
    models.each do |model|
      session = model.new(op_session_binding: nil, absolute_expires_at: 1.minute.from_now, installed_generation: 0)

      assert_not session.valid?
      assert session.errors.of_kind?(:op_session_binding, :blank)
      assert_includes session.errors.details.fetch(:op_session_binding).pluck(:error),
                      "must have a resolved identity binding"
      assert_predicate session, :new_record?
    end
  end
end
