# frozen_string_literal: true

require "test_helper"

class CspIntakePublicContractTest < ActiveSupport::TestCase
  test "report bodies honor the byte boundary and malformed JSON remains explicit" do
    [CspViolationReportIntake::MAX_BODY_BYTES - 1, CspViolationReportIntake::MAX_BODY_BYTES].each do |size|
      body = "{}" + (" " * (size - 2))
      result = CspViolationReportIntake.call(raw_body: body, host: "core.example.app")

      assert_equal :accepted, result.status
      assert_equal 0, result.reports_count
    end
    result = CspViolationReportIntake.call(
      raw_body: " " * (CspViolationReportIntake::MAX_BODY_BYTES + 1),
      host: "core.example.app",
    )

    assert_equal :too_large, result.status
    assert_equal 0, result.reports_count
    assert_equal :malformed, CspViolationReportIntake.call(raw_body: "{", host: "core.example.app").status
  end

  test "legacy reports redact URL queries and expose a bounded fixed event schema" do
    events = []
    body = { "csp-report" => {
      "document-uri" => "https://core.example.app/account?secret=x#fragment",
      "blocked-uri" => "https://cdn.example.test/asset?token=y",
      "source-file" => "http://[invalid?secret=z",
      "effective-directive" => "script-src",
      "original-policy" => "a" * 257,
      "status-code" => "200",
      "line-number" => "bad",
      "column-number" => 0,
    } }
    Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
      result = CspViolationReportIntake.call(
        raw_body: body.to_json, host: "core.example.app",
        user_agent: "Browser/1 sensitive",
      )

      assert_equal 1, result.reports_count
    end
    assert_equal CspViolationReportIntake::EVENT_NAME, events.one? && events.first.first
    payload = events.first.last

    assert_equal CspViolationReportIntake::SCHEMA_KEYS.sort, payload.keys.sort
    assert_equal "https://core.example.app/account", payload[:document_uri]
    assert_equal "http://[invalid", payload[:source_file]
    assert_equal "application", payload[:category]
    assert_equal "application:script-src:https://cdn.example.test", payload[:aggregation_key]
    assert_equal 256, payload[:original_policy].length
    assert_equal 200, payload[:status_code]
    assert_nil payload[:line_number]
    assert_equal 0, payload[:column_number]
    assert_equal "Browser/1", payload[:user_agent_family]
  end

  test "Reporting API accepts CSP objects only and classifies extension schemes" do
    events = []
    entries = [nil, "noise", { type: "network-error", body: { "blocked-uri" => "inline" } },
               { type: "csp-violation", body: nil },
               { body: { "blocked-uri" => "moz-extension://identifier/a?secret=x",
                         "violated-directive" => "style-src", } },
               { type: "csp-violation", body: { "blocked-uri" => "data:text/plain,abc" } },]
    Rails.event.stub(:notify, ->(_name, payload) { events << payload }) do
      result = CspViolationReportIntake.call(raw_body: entries.to_json, host: "core.example.app")

      assert_equal :accepted, result.status
      assert_equal 2, result.reports_count
    end
    assert_equal "browser_extension", events.first[:category]
    assert_equal "browser_extension:style-src:moz-extension", events.first[:aggregation_key]
    assert_nil events.first[:user_agent_family]
    assert_equal "application:unknown:data", events.last[:aggregation_key]
  end

  test "unsupported top level and non scalar report fields do not manufacture reports" do
    [nil, 1, "text", { "blocked-uri" => [], "effective-directive" => {} }].each do |body|
      result = CspViolationReportIntake.call(raw_body: body.to_json, host: "core.example.app")

      assert_equal :accepted, result.status
      assert_equal 0, result.reports_count
    end
  end
end
