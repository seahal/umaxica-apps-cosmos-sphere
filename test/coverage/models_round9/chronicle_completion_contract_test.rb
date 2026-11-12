# frozen_string_literal: true

require "test_helper"

class ChronicleCompletionContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "result facts merge into the intent row and pass through persistent audit sanitization" do
    policy = ChronicleRetentionPolicy.create!(
      code: "round9-result", name: "Result contract", duration_days: 30,
      permanent: false,
    )
    now = Time.current
    chronicle = Chronicle.create!(
      event_uuid: SecureRandom.uuid, action: "rp.session.revoked", result: "intent",
      chronicle_retention_policy: policy, occurred_at: now, erasable_at: now + 30.days,
      changeset: { "status" => "started", "before" => { "count" => 3 } }, metadata: {},
    )
    written = nil
    assert_no_difference -> { Chronicle.count } do
      written = ChronicleResultWriter.call(
        chronicle: chronicle, result: "succeeded", event_uuid: chronicle.event_uuid,
        request_id: "round9-completion", action: chronicle.action,
        changeset: { status: "completed",
                     after: { count: 0, token: "must-never-persist" },
                     password: "must-never-persist", },
      )
    end
    assert_equal chronicle, written
    persisted = chronicle.reload

    assert_equal "succeeded", persisted.result
    assert_equal(
      { "status" => "completed", "before" => { "count" => 3 }, "after" => { "count" => 0 } },
      persisted.changeset,
    )
  end

  test "nil and empty completion facts preserve the already recorded intent facts" do
    policy = ChronicleRetentionPolicy.create!(
      code: "round9-preserve", name: "Preserve intent facts",
      duration_days: 30, permanent: false,
    )
    [nil, {}].each do |changeset|
      now = Time.current
      chronicle = Chronicle.create!(
        event_uuid: SecureRandom.uuid, action: "rp.session.revoked", result: "intent",
        chronicle_retention_policy: policy, occurred_at: now, erasable_at: now + 30.days,
        changeset: { "before_count" => 3 }, metadata: {},
      )
      ChronicleResultWriter.call(
        chronicle: chronicle, result: "succeeded", event_uuid: chronicle.event_uuid,
        request_id: "round9-preserve", action: chronicle.action, changeset: changeset,
      )

      assert_equal "succeeded", chronicle.reload.result
      assert_equal({ "before_count" => 3 }, chronicle.changeset)
    end
  end

  test "a persisted visibility context can be passed directly and repeated without duplicating a grant" do
    ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
      policy.name = "Security"
      policy.duration_days = 365
      policy.permanent = false
    end
    context = ChronicleVisibilityContext.create!(code: "round9-audit", name: "Audit audience")
    chronicle = ChronicleIntentWriter.call(
      event_uuid: SecureRandom.uuid, action: "auth.sign_in.failed",
      visibility_contexts: [context, context],
    )

    assert_equal "intent", chronicle.reload.result
    assert_equal [context.id], ChronicleVisibility.where(chronicle: chronicle).pluck(:chronicle_visibility_context_id)
    assert_equal 1, ChronicleVisibility.where(chronicle: chronicle, chronicle_visibility_context: context).count
  end
end
