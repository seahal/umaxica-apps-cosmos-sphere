# frozen_string_literal: true

require "test_helper"

class RuntimePrimitivesRound4JwtAnomalyNotificationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "unsupported extra objects cannot add unapproved fields to anomaly notifications" do
    captured = []
    subscriber = ->(event) { captured << event.payload }
    ActiveSupport::Notifications.subscribed(subscriber, "jwt.anomaly.detected") do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "core.example", reason: "DECODE_ERROR",
        header: { "kid" => "public-key" }, payload: { "aud" => ["rp-a", 1, nil] }, extra: Object.new,
      )
    end

    assert_equal 1, captured.length
    event = captured.fetch(0)

    assert_equal "AUTH_CLIENT_DECODE_ERROR", event.fetch(:code)
    assert_equal ["rp-a"], event.fetch(:aud)
    assert_equal "public-key", event.fetch(:kid)
    assert_not event.key?(:extra)
  end
end
