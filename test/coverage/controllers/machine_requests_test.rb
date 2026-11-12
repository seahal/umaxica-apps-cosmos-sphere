# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerMachineRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "each retained surface exposes uncached revision text and machine JSON with explicit negotiation" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each do |setting|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      browser.get("/revision", headers: { "Accept" => "text/html" })

      assert_equal 200, browser.response.status
      assert_equal "text/plain", browser.response.media_type
      assert_includes browser.response.body, "title: Revision status\n"
      assert_equal "no-store", browser.response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", browser.response.headers["X-Robots-Tag"]

      [nil, "*/*", "application/*", "application/json", "text/html"].each do |accept|
        headers = accept.nil? ? {} : { "Accept" => accept }
        browser.get("/api/v0/revision.json", headers:)

        assert_equal((accept == "text/html") ? 406 : 200, browser.response.status)
        assert_equal "no-store", browser.response.headers["Cache-Control"]
        next if accept == "text/html"

        assert_equal "application/json", browser.response.media_type
        assert browser.response.parsed_body.key?("revision")
        assert_predicate browser.response.parsed_body.fetch("timestamp"), :present?
      end
    end
  end

  test "health probe refusal and snapshot output do not disclose dependency exceptions" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    unavailable = Health::CheckResult.new(check: :readiness, status: :unready, surface: "app")
    Health::ReadinessCheck.stub(:call, unavailable) do
      get "/health/readiness"
    end

    assert_response :service_unavailable
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]
    snapshot = Health::CheckResult.new(
      check: :snapshot, status: :unready, surface: "app", dependencies: {
        "startup" => { status: "ok" }, "liveness" => { status: "ok" }, "readiness" => { status: "unavailable" },
      },
    )
    Health::SnapshotCheck.stub(:call, snapshot) do
      get "/health"
    end

    assert_response :service_unavailable
    assert_includes response.body, "namespace: core/app\n"
    assert_includes response.body, "startup: ok\n"
    assert_includes response.body, "readiness: unavailable\n"
    assert_equal 7, response.body.lines.size
    assert_not_includes response.body, "exception"
  end

  test "health snapshot rejects an incomplete dependency contract rather than displaying a blank result" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    snapshot = Health::CheckResult.new(check: :snapshot, status: :ok, surface: "app", dependencies: {})
    Health::SnapshotCheck.stub(:call, snapshot) do
      error = assert_raises(Health::MalformedSnapshotError) { get("/health") }
      assert_includes error.message, "startup"
    end
  end

  test "CSP reports accept null Origin and bound the browser supplied document size" do
    %w(PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL
       PUBLIC_PALM_SERVICE_URL).each do |setting|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      ["{", "{}", '{"csp-report":{"violated-directive":"script-src"}}',
       "x" * CspViolationReportIntake::MAX_BODY_BYTES,
       "x" * (CspViolationReportIntake::MAX_BODY_BYTES + 1),].each do |body|
        browser.post(
          "/csp-violation-report", params: body, headers: {
            "CONTENT_TYPE" => "application/csp-report", "Origin" => "null",
          },
        )

        assert_equal 204, browser.response.status
        assert_empty browser.response.body
        assert_nil browser.response.location
        assert_nil browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      end
    end
  end
  test "CSP rate limiting stops intake while preserving the browser telemetry no-content contract" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    accepted_reports = 0
    CspViolationReportIntake.stub(:call, ->(**) { accepted_reports += 1 }) do
      121.times do
        post "/csp-violation-report", params: "{}", headers: {
          "CONTENT_TYPE" => "application/csp-report", "REMOTE_ADDR" => "192.0.2.84", "Origin" => "null",
        }

        assert_response :no_content
      end
    end

    assert_equal 120, accepted_reports
    assert_empty response.body
    assert_nil response.location
  end

  test "a malformed JSON browser telemetry envelope is explicitly absorbed without a session" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
    post "/csp-violation-report", params: "{", headers: {
      "CONTENT_TYPE" => "application/json", "Origin" => "null", "REMOTE_ADDR" => "192.0.2.85",
    }

    assert_response :no_content
    assert_empty response.body
    assert_nil response.location
  end
end
