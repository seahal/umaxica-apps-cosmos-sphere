# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerPublicContractsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "health wire vocabulary maps each probe independently and failure dominates warning" do
    [
      [:ok, :ok, :ok, "pass", 200],
      [:degraded_acceptable, :ok, :ok, "warn", 200],
      [:starting, :ok, :ok, "warn", 200],
      [:ok, :starting, :ok, "fail", 503],
      [:ok, :ok, :starting, "fail", 503],
      [:unready, :degraded_acceptable, :ok, "fail", 503],
    ].each do |liveness_status, startup_status, readiness_status, status, http_status|
      liveness = Health::CheckResult.new(check: :liveness, status: liveness_status, surface: "app")
      startup = Health::CheckResult.new(check: :startup, status: startup_status, surface: "app")
      readiness = Health::CheckResult.new(check: :readiness, status: readiness_status, surface: "app")
      result = HealthStatusSerializer.call(liveness:, startup:, readiness:, namespace: "core/app", timestamp: "instant")

      assert_equal status, result.body.fetch(:status)
      assert_equal http_status, result.http_status
      assert_equal "core/app", result.body.fetch(:namespace)
      assert_equal "instant", result.body.fetch(:timestamp)
      assert_equal %i(startup liveness readiness), result.body.fetch(:checks).keys
    end
  end

  test "health serialization refuses a future upstream status instead of guessing a wire verdict" do
    known = Health::CheckResult.new(check: :startup, status: :ok, surface: "app")
    unknown = Struct.new(:status).new(:future_status)
    error =
      assert_raises(ArgumentError) do
        HealthStatusSerializer.call(
          liveness: unknown, startup: known, readiness: known, namespace: "core/app", timestamp: "instant",
        )
      end
    assert_equal "unmapped health status: :future_status", error.message
  end

  test "navigation targets enforce scopes and reject arbitrary path input" do
    routes = Rails.application.routes.url_helpers
    [nil, "", 0, "HOME", "missing", "https://untrusted.example", "/sign", "x:y", "x\\y"].each do |input|
      result = RedirectsNavigationTargetResolver.call(input, routes:, scope: :public)

      assert_not result.ok?, input.inspect
      assert_equal :nt, result.kind
    end
    %i(home signed_out).each do |key|
      result = RedirectsNavigationTargetResolver.call(key, routes:, params: { ri: "jp" }, scope: :public)

      assert_predicate result, :ok?
      assert_equal((key == :home) ? "/?ri=jp" : "/sign/out?ri=jp", result.value)
    end
    assert_equal "scope_denied",
                 RedirectsNavigationTargetResolver.call(:dashboard, routes:, scope: :public).failure_reason
    assert_equal "scope_denied", RedirectsNavigationTargetResolver.call(:home, routes:, scope: :unknown).failure_reason
    assert_equal "/", RedirectsNavigationTargetResolver.call("home", routes:, params: { ri: "" }).value
    assert_equal "/sign/out", RedirectsNavigationTargetResolver.call(:signed_out, routes:).value
    assert_equal "org", RedirectsNavigationTargetResolver.surface(surface: "org")
    assert_equal "app", RedirectsNavigationTargetResolver.surface({})
  end

  test "Chronicle error message truncation and safe categorical values preserve only allowed data" do
    [1023, 1024, 1025].each do |length|
      message = ("safe error. " * 100)[0, length]
      result = ChronicleRecordPolicy.log_payload(
        event: "failed", event_uuid: "event", request_id: "request", action: "auth.sign_in.failed",
        actor: nil, subject: nil, error: StandardError.new(message),
      )

      assert_equal [length, 1024].min, result.fetch(:error_message).bytesize
      assert_nil result.fetch(:actor_id)
      assert_nil result.fetch(:subject_type)
    end
    assert_equal(
      { "external_id" => "[FILTERED]", "reason_code" => "safe.reason", "safe" => [nil, 3] },
      ChronicleRecordPolicy.sanitize(
        { external_id: "not-a-uuid",
          reason_code: "safe.reason",
          safe: [nil, 3],
          token: "credential",
          request_id: "private", },
      ),
    )
    assert_nil ChronicleRecordPolicy.sanitize_text(nil)
    assert_equal "[FILTERED]", ChronicleRecordPolicy.sanitize_text("Bearer secret-value")
    assert_raises(ArgumentError) { ChronicleRecordPolicy.retention_policy_code_for("step_up.unknown") }
    %w(audit.export.finished account.deleted account.destroyed account.irreversible).each do |action|
      assert_equal "permanent", ChronicleRecordPolicy.retention_policy_code_for(action)
    end
    %w(rate_limit.blocked csrf_detected unknown).each do |action|
      assert_equal "security", ChronicleRecordPolicy.retention_policy_code_for(action)
    end
  end
end
