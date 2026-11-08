# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceValueTest < ActiveSupport::TestCase
  test "current evidence is valid before its age limit and invalid at either boundary" do
    evidence = build_evidence(auth_time: 1_800_000_000)

    assert_not evidence.current?(now: Time.zone.at(1_799_999_999))
    assert evidence.current?(now: Time.zone.at(1_800_000_000))
    assert evidence.current?(now: Time.zone.at(1_800_000_299))
    assert_not evidence.current?(now: Time.zone.at(1_800_000_300))
  end

  test "evidence rejects an audience array containing a non-string" do
    assert_raises(ArgumentError) { build_evidence(aud: ["client", 1]) }
  end

  private

  def build_evidence(auth_time: 1_800_000_000, aud: ["client"])
    StepUpEvidenceValue.new(
      acr: "aal2",
      amr: ["passkey"],
      auth_time:,
      sid: "session",
      sub: "operator:1",
      client_id: "client",
      aud:,
      jti: "token",
    )
  end
end
