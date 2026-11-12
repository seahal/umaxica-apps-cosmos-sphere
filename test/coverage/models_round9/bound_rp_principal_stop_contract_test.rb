# frozen_string_literal: true

require "test_helper"

class BoundRpPrincipalStopContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a repeated callback cannot enroll or return a session after its bound local principal is disabled" do
    cells = [
      ["rp_core_app", RpCoreAppSession, RpCoreAppOpSessionBinding],
      ["rp_core_org", RpCoreOrgSession, RpCoreOrgOpSessionBinding],
      ["rp_warp_app", RpWarpAppSession, RpWarpAppOpSessionBinding],
      ["rp_warp_org", RpWarpOrgSession, RpWarpOrgOpSessionBinding],
      ["rp_palm_app", RpPalmAppSession, RpPalmAppOpSessionBinding],
    ]
    cells.each do |connection, session_model, anchor_model|
      cell = RpCellBinding.fetch(connection)
      expiry = 1.hour.from_now
      first = RpCallbackCommitter.call(
        cell: cell, issuer: "https://access.example.test", subject: "round9-subject",
        sid: "round9-bound-sid", absolute_expires_at: expiry,
      )

      assert_predicate first, :success?
      first.principal.update!(disabled_at: Time.current)
      anchor = anchor_model.find_by!(sid: "round9-bound-sid")

      assert_not_nil anchor.identity_binding_id
      repeated = nil
      assert_no_difference -> { session_model.count } do
        repeated = RpCallbackCommitter.call(
          cell: cell, issuer: "https://access.example.test", subject: "round9-subject",
          sid: "round9-bound-sid", absolute_expires_at: expiry,
        )
      end
      assert_equal :revoked, repeated.outcome
      assert_not repeated.success?
      assert_nil repeated.session
      assert_nil repeated.principal
      persisted_anchor = anchor_model.includes(:identity_binding).find(anchor.id)

      assert_equal first.principal.id, persisted_anchor.identity_binding.principal_id
      assert_not_nil first.principal.reload.disabled_at
    end
  end
end
