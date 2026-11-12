# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound9PublicIntakeAndResultBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "malformed CSP endpoint origins aggregate without forwarding query credentials" do
    events = []
    subscriber = ->(name, payload) { events << [name, payload] }
    result =
      Rails.event.stub(:notify, subscriber) do
        CspViolationReportIntake.call(
          raw_body: JSON.generate(
            "csp-report" => {
              "blocked-uri" => "https://[bad?token=synthetic-secret",
              "effective-directive" => "script-src",
            },
          ),
          host: "core.example.app",
        )
      end

    assert_equal :accepted, result.status
    assert_equal 1, result.reports_count
    assert_equal 1, events.length
    assert_equal CspViolationReportIntake::EVENT_NAME, events.fetch(0).fetch(0)
    event = events.fetch(0).fetch(1)

    assert_equal "application:script-src:invalid", event.fetch(:aggregation_key)
    assert_equal "https://[bad", event.fetch(:blocked_uri)
    assert_not_includes event.to_json, "synthetic-secret"
  end

  test "nonhealthy dependency results expose only failed status without internal diagnostic text" do
    %i(degraded_acceptable unready starting).each do |status|
      dependency = Health::DependencyResult.new(kind: :database, status:, message: "private diagnostic")

      assert_not_predicate dependency, :ok?
      assert_equal "failed", dependency.public_status
    end
    healthy = Health::DependencyResult.new(kind: :database, status: :ok)

    assert_predicate healthy, :ok?
    assert_equal "ok", healthy.public_status
  end

  test "a direct API exceptions request without a numeric status path produces a safe 500 problem" do
    env = Rack::MockRequest.env_for("/api/v0/failed")
    env["action_dispatch.request_id"] = "public-request-reference"
    env["action_dispatch.exception"] = RuntimeError.new("private exception detail")
    status, headers, body = ApiProblemExceptionsApp.call(env)
    json = body.to_a.join
    problem = JSON.parse(json)

    assert_equal 500, status
    assert_equal "application/problem+json", headers.fetch("content-type")
    assert_equal "no-store", headers.fetch("cache-control")
    assert_equal 500, problem.fetch("status")
    assert_equal "/api/v0/failed", problem.fetch("instance")
    assert_equal "public-request-reference", problem.fetch("request_id")
    assert_not_includes json, "private exception detail"
  end
end
