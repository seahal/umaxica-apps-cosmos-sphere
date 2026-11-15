# frozen_string_literal: true

require "test_helper"
require "observability_redactor"
require "umaxica/valkey/store_error_handler"

class RuntimeAndValuesRound7PublicValueBoundariesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "surface detection accepts the public host string form without a request object" do
    assert_equal :app, CoreSurface.detect("core.app.example")
    assert_equal :org, CoreSurface.current("core.org.example")
    assert_equal :unknown, CoreSurface.detect("unclassified.example")
    assert CoreSurface.matches?("core.app.example", "app")
  end

  test "step-up assertion expectation rejects absent blank and non-string bindings" do
    [nil, "", " ", 0].each do |invalid|
      assert_raises(ArgumentError) { OidcClientAssertionStepUpExpectationValue.new(grant: invalid, subject: "subject") }
      assert_raises(ArgumentError) { OidcClientAssertionStepUpExpectationValue.new(grant: "grant", subject: invalid) }
    end
    value = OidcClientAssertionStepUpExpectationValue.new(grant: "grant-reference", subject: "subject-reference")

    assert_equal "grant-reference", value.grant
    assert_equal "subject-reference", value.subject
    assert_predicate value, :frozen?
  end

  test "Jump key identifiers enforce UTF-16 length without accepting unencodable bytes" do
    ["x" * 127, "x" * 128, ("😀" * 63) + "a", "😀" * 64].each do |kid|
      assert SecurityJwtJumpRtTokenCodec.valid_kid?(kid)
    end
    ["x" * 129, ("😀" * 64) + "a", "\xFF".b].each do |kid|
      assert_not SecurityJwtJumpRtTokenCodec.valid_kid?(kid)
    end
  end

  test "Jump headers reject alternate algorithms types and unregistered metadata" do
    valid = { "alg" => "PS256", "typ" => "JWT", "kid" => "public-key" }

    assert SecurityJwtJumpRtTokenCodec.valid_header?(valid)
    [nil, [], valid.merge("typ" => "at+jwt"), valid.merge("alg" => "none"),
     valid.merge("kid" => nil), valid.merge("jku" => "https://attacker.example/keys"),].each do |header|
      assert_not SecurityJwtJumpRtTokenCodec.valid_header?(header)
    end
  end

  test "missing URL data is redacted rather than represented as an empty location" do
    assert_equal ObservabilityRedactor::REDACTED, ObservabilityRedactor.scrub_url(nil)
  end

  test "a Valkey degraded-operation notification omits the exception URL and credentials" do
    messages = []
    logger = Object.new
    logger.define_singleton_method(:error) { |message| messages << message }
    handler = Umaxica::Valkey::StoreErrorHandler.lambda_for(:cache)
    exception = IOError.new("redis://user:private-password@host.example/2")
    Rails.stub(:logger, logger) do
      handler.call(method: :read, exception:, returning: nil)
    end

    assert_equal 1, messages.length
    assert_includes messages.fetch(0), "valkey.store.unavailable"
    assert_includes messages.fetch(0), "IOError"
    assert_not_includes messages.fetch(0), "private-password"
    assert_not_includes messages.fetch(0), "host.example"
  end
end
