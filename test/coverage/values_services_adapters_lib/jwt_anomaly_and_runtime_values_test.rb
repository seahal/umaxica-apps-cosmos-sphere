# frozen_string_literal: true

require "test_helper"

class JwtAnomalyAndRuntimeValuesTest < ActiveSupport::TestCase
  test "JWT diagnostic events bound metadata and omit all unapproved extras" do
    events = []
    subscriber =
      ActiveSupport::Notifications.subscribe("jwt.anomaly.detected") do |*arguments|
        events << ActiveSupport::Notifications::Event.new(*arguments).payload
      end
    begin
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "staff", host: "host." * 60,
        header: { "kid" => "key", "alg" => "PS256" },
        payload: { "typ" => "at+jwt",
                   "iss" => "issuer",
                   "aud" => ["audience", 1, nil] + Array.new(
                     8,
                     "other",
                   ),
                   "jti" => "id", },
        reason: "MISSING_SUB", error: ArgumentError.new("invalid claim"), extra: { secret: "hidden" },
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
    event = events.fetch(0)

    assert_equal "AUTH_OPERATOR_MISSING_SUB", event[:reason_code]
    assert_equal 255, event[:request_host].length
    assert_equal 6, event[:aud].length
    assert_equal "ArgumentError", event[:error_class]
    assert_not event.key?(:secret)
    assert_equal "at+jwt", event[:typ]
  end

  test "JWT missing claims have stable reason codes and invalid contexts produce no event" do
    assert_equal "MISSING_SUB", JitSecurityJwtAnomalyReporter.reason_for_missing_claim("Missing required claim sub")
    assert_equal "DECODE_ERROR", JitSecurityJwtAnomalyReporter.reason_for_missing_claim("other failure")
    events = []
    subscriber =
      ActiveSupport::Notifications.subscribe("jwt.anomaly.detected") do |*arguments|
        events << ActiveSupport::Notifications::Event.new(*arguments).payload
      end
    begin
      JitSecurityJwtAnomalyReporter.report_auth(resource_type: "unknown", host: "host", reason: "ERROR")
      JitSecurityJwtAnomalyReporter.report_auth(resource_type: "client", host: "host", reason: nil)
      %w(app.example.com core.com.example core.org.example other.example).each do |host|
        JitSecurityJwtAnomalyReporter.report_preference(host: host, payload: { "aud" => "audience" }, reason: "ERROR")
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_equal %w(APP_PREFERENCE COM_PREFERENCE ORG_PREFERENCE), events.pluck(:context)
    assert_equal ["audience"] * 3, events.pluck(:aud)
  end

  test "anomaly reporting failure does not replace the caller's authentication decision" do
    Rails.logger.stub(:info, ->(*) { raise IOError, "logging unavailable" }) do
      assert_nil JitSecurityJwtAnomalyReporter.report_auth(resource_type: "client", host: "host", reason: "ERROR")
    end
  end

  test "MCP surface values are immutable exhaustive and have stable equality" do
    %w(app com org).each do |surface|
      identity = McpSurfaceIdentity.new(realm: "warp", surface: surface)
      same = McpSurfaceIdentity.new(realm: "warp", surface: surface)

      assert_predicate identity, :frozen?
      assert_equal identity, same
      assert_equal identity.hash, same.hash
      assert_not_equal identity, Object.new
      assert_equal "umaxica-warp-#{surface}", identity.server_name
      assert_equal({ realm: "warp", surface: surface }, identity.as_public_json)
      assert_same Health::Profiles.const_get(surface.capitalize), identity.health_profile
    end
    assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "unsupported", surface: "app") }
    assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "warp", surface: "unsupported") }
  end

  test "Valkey namespaces preserve explicitly supplied scope without sharing responsibility keys" do
    assert_equal "auth_state:authorization_code:run:worker:test",
                 Umaxica::Valkey::Namespaces.authorization_codes(
                   suite_run_id: "run", worker_id: "worker",
                   test_id: "test",
                 )
    assert_equal "auth_state:sign_out_notice", Umaxica::Valkey::Namespaces.sign_out_notices
    assert_equal "auth_state:admission", Umaxica::Valkey::Namespaces.admission
    assert_equal "auth_state:rp_refresh", Umaxica::Valkey::Namespaces.rp_refresh
    assert_equal "otp-verification", Umaxica::Valkey::Namespaces.otp_verification
  end

  test "Valkey URL parsing distinguishes supported schemes ports and malformed indexes" do
    parsed = Umaxica::Valkey::ResponsibilityUrls.parse("rediss://valkey.example:6380/7", responsibility: :auth_state)

    assert_predicate parsed, :redis_scheme?
    assert_equal 6380, parsed.port
    assert_equal 7, parsed.db
    assert_equal "valkey.example", parsed.host
    bare = Umaxica::Valkey::ResponsibilityUrls.parse("redis://valkey.example", responsibility: :cache)

    assert_equal 6379, bare.port
    assert_equal 0, bare.db
    [nil, "", "https://valkey.example/0", "redis:///0", "redis://valkey.example/no", "redis://[invalid"].each do |url|
      assert_raises(Umaxica::Valkey::ConfigurationError) {
        Umaxica::Valkey::ResponsibilityUrls.parse(
          url,
          responsibility: :auth_state,
        )
      }
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) {
      Umaxica::Valkey::ResponsibilityUrls.parse(
        "redis://host",
        responsibility: :unknown,
      )
    }
  end
end
