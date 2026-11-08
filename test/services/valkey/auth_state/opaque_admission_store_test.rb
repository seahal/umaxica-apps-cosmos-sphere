# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateOpaqueAdmissionStoreTest < ActiveSupport::TestCase
  setup do
    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.admission(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      namespace: @namespace,
    )
    @store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: @connection)
  end

  teardown do
    next if @connection.nil?

    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")
    Umaxica::Valkey::Cleanup.ensure_empty!(@connection, prefix: "#{@namespace}:")
    @connection.close
  end

  test "handoff consume is one-shot and sixty-second TTL contract" do
    assert_equal 60.seconds, Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL

    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
      subject_ref: "client:1",
    )
    first = @store.consume!(purpose: :authentication_handoff, raw_code: raw)

    assert_predicate first, :success?
    assert_equal "authentication_handoff", first.payload.fetch("purpose")

    second = @store.consume!(purpose: :authentication_handoff, raw_code: raw)

    assert_predicate second, :replay?
  end

  test "missing code fails closed" do
    result = @store.consume!(purpose: :sign_in_result, raw_code: "missing")

    assert_predicate result, :missing?
  end

  test "binding mismatch does not consume the admission" do
    raw = @store.issue!(
      purpose: :authentication_result,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
    )

    rejected = @store.consume!(
      purpose: :authentication_result,
      raw_code: raw,
      expected: { actor_type: "operator", surface: "org", subject_ref: "transaction-1" },
    )

    assert_predicate rejected, :binding_mismatch?

    accepted = @store.consume!(
      purpose: :authentication_result,
      raw_code: raw,
      expected: { actor_type: "client", surface: "app", subject_ref: "transaction-1" },
    )

    assert_predicate accepted, :success?
  end

  test "binding expectations reject unknown payload fields" do
    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
    )

    assert_raises ArgumentError do
      @store.consume!(
        purpose: :authentication_handoff,
        raw_code: raw,
        expected: { unknown: "value" },
      )
    end
  end

  test "result issuance accepts a caller-generated opaque code and records its generation" do
    raw = SecureRandom.urlsafe_base64(32, padding: false)

    stored = @store.issue!(
      purpose: :authentication_result,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
      raw_code: raw,
      result_generation: 3,
    )

    assert_equal raw, stored
    assert_equal 3, @store.read(raw).fetch("result_generation")
    assert_equal "transaction-1", @store.read(raw).fetch("subject_ref")
  end

  test "a non-secret reference consumes the admission without putting the code in the URL" do
    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
      reference: "transaction-1",
    )

    consumed = @store.consume_reference!(
      reference: "transaction-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate consumed, :success?
    assert_equal "authentication_handoff", consumed.payload.fetch("purpose")

    replay = @store.consume_reference!(
      reference: "transaction-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate replay, :replay?
    assert_predicate raw, :present?
  end

  test "reference binding mismatch does not consume the admission" do
    @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
      reference: "entry-1",
    )

    rejected = @store.consume_reference!(
      reference: "entry-1",
      expected: { actor_type: "operator", surface: "org" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate rejected, :binding_mismatch?

    accepted = @store.consume_reference!(
      reference: "entry-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate accepted, :success?
  end

  test "issue rejects retired visitor and mismatched actor surface values" do
    [
      { actor_type: "visitor", surface: "com" },
      { actor_type: "client", surface: "com" },
      { actor_type: "client", surface: "org" },
      { actor_type: "unknown", surface: "app" },
    ].each do |binding|
      assert_raises(ArgumentError) do
        @store.issue!(purpose: :authentication_handoff, **binding)
      end
    end
  end

  test "every operation reports Valkey unavailability as Unavailable" do
    down = Object.new
    down.define_singleton_method(:key) { |suffix| "down:#{suffix}" }
    down.define_singleton_method(:call) { |*| raise Redis::CannotConnectError, "connection refused" }
    store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: down)

    assert_raises(Umaxica::Valkey::Unavailable) do
      store.issue!(purpose: "authentication_result", actor_type: "client", surface: "app")
    end
    assert_raises(Umaxica::Valkey::Unavailable) { store.read("code") }
    assert_raises(Umaxica::Valkey::Unavailable) { store.consume!(purpose: "authentication_result", raw_code: "code") }
    assert_raises(Umaxica::Valkey::Unavailable) { store.consume_reference!(reference: "ref") }
  end

  test "a stored admission that is not JSON is reported as corrupt" do
    raw = "stored-#{SecureRandom.hex(4)}"
    digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "authentication_result", raw_code: raw)
    @connection.call("SET", @connection.key("admission:authentication_result:#{digest}"), "{not json")

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw) }
  end

  test "an unexpected consume reply fails closed as a corrupt payload" do
    odd = Object.new
    odd.define_singleton_method(:key) { |suffix| "odd:#{suffix}" }
    odd.define_singleton_method(:call) { |*| ["surprise", nil] }
    store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: odd)

    assert_raises(Umaxica::Valkey::SerializationError) do
      store.consume!(purpose: "authentication_result", raw_code: "code")
    end
    assert_raises(Umaxica::Valkey::SerializationError) { store.consume_reference!(reference: "ref") }
  end

  test "binding expectations must be a hash" do
    assert_raises(ArgumentError) do
      @store.consume!(purpose: "authentication_result", raw_code: "code", expected: [["surface", "app"]])
    end
  end

  test "the instance digest matches the class digest" do
    assert_equal Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "p", raw_code: "c"),
                 @store.digest_for(purpose: "p", raw_code: "c")
  end

  test "reissue rejects missing consumed and wrong-purpose references without changing the original admission" do
    arguments = { reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app" }
    missing = assert_raises(Umaxica::Valkey::OperationError) { @store.reissue_reference!(**arguments) }

    assert_equal "admission reference is unavailable", missing.message

    raw = @store.issue!(**arguments)
    mismatch =
      assert_raises(Umaxica::Valkey::OperationError) do
        @store.reissue_reference!(**arguments.merge(purpose: "authentication_result"))
      end

    assert_equal "admission reference purpose mismatch", mismatch.message
    assert_equal "issued", @store.read(raw, purpose: "authentication_handoff").fetch("state")
    assert_predicate @store.consume_reference!(reference: "entry-1"), :success?

    replay = assert_raises(Umaxica::Valkey::OperationError) { @store.reissue_reference!(**arguments) }

    assert_equal "admission reference was consumed", replay.message
    assert_predicate @store.consume!(purpose: "authentication_handoff", raw_code: raw), :replay?
  end

  test "reissue and restore reject corrupt reference pointers" do
    pointer_key = @connection.key("admission-reference:#{Digest::SHA256.hexdigest("reference:entry-1")}")
    @connection.call("SET", pointer_key, "{not json")
    arguments = { reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app" }

    assert_raises(Umaxica::Valkey::SerializationError) { @store.reissue_reference!(**arguments) }
    assert_raises(Umaxica::Valkey::SerializationError) do
      @store.restore_reference!(**arguments, raw_code: "restored-code")
    end
    assert_equal "{not json", @connection.call("GET", pointer_key)
  end

  test "restore recreates an absent pointer using the original code and binding" do
    now = Time.utc(2026, 11, 7, 12)
    raw = @store.restore_reference!(
      reference: "entry-1", purpose: "cancellation_handoff", actor_type: "operator", surface: "org",
      subject_ref: "transaction-1", base_session_ref: "base-1", ceremony_session_ref: "ceremony-1",
      result_generation: 4, raw_code: "original-code", now:,
    )
    payload = @store.read_reference!(reference: "entry-1", purposes: ["cancellation_handoff"])

    assert_equal "original-code", raw
    assert_equal "transaction-1", payload.fetch("subject_ref")
    assert_equal "base-1", payload.fetch("base_session_ref")
    assert_equal "ceremony-1", payload.fetch("ceremony_session_ref")
    assert_equal "operator", payload.fetch("actor_type")
    assert_equal "org", payload.fetch("surface")
    assert_equal 4, payload.fetch("result_generation")
    assert_equal now.iso8601, payload.fetch("issued_at")
    assert_equal (now + 60.seconds).iso8601, payload.fetch("expires_at")
    assert_predicate @store.consume_reference!(reference: "entry-1", purposes: ["cancellation_handoff"]), :success?
    assert_predicate @store.consume!(purpose: "cancellation_handoff", raw_code: raw), :replay?
  end

  test "restore refuses a different purpose without replacing the original code" do
    raw = @store.issue!(
      reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
    )
    error =
      assert_raises(Umaxica::Valkey::OperationError) do
        @store.restore_reference!(
          reference: "entry-1", purpose: "authentication_result", actor_type: "client", surface: "app",
          raw_code: "replacement-code",
        )
      end

    assert_equal "admission reference purpose mismatch", error.message
    assert_equal "authentication_handoff", @store.read_reference!(reference: "entry-1").fetch("purpose")
    assert_predicate @store.consume!(purpose: "authentication_handoff", raw_code: raw), :success?
    assert_nil @store.read("replacement-code")
  end

  test "reference reads return nil for missing pointers and expired primary records" do
    assert_nil @store.read_reference!(reference: "missing-entry")

    raw = @store.issue!(
      reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
    )
    digest = @store.digest_for(purpose: "authentication_handoff", raw_code: raw)
    @connection.call("DEL", @connection.key("admission:authentication_handoff:#{digest}"))

    assert_nil @store.read_reference!(reference: "entry-1")
    assert_predicate @store.consume_reference!(reference: "entry-1"), :missing?
  end

  test "reference reads reject disallowed purposes and inconsistent or malformed stored bindings" do
    raw = @store.issue!(
      reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
    )

    assert_raises(ArgumentError) do
      @store.read_reference!(reference: "entry-1", purposes: ["authentication_result"])
    end

    digest = @store.digest_for(purpose: "authentication_handoff", raw_code: raw)
    primary_key = @connection.key("admission:authentication_handoff:#{digest}")
    payload = @store.read(raw, purpose: "authentication_handoff")
    @connection.call("SET", primary_key, JSON.generate(payload.merge("reference" => "another-entry")))

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read_reference!(reference: "entry-1") }

    @connection.call("SET", primary_key, JSON.generate(payload.except("reference")))

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read_reference!(reference: "entry-1") }

    @connection.call("SET", primary_key, "{not json")

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read_reference!(reference: "entry-1") }
  end

  test "reissue restore and reference reads preserve the cause of dependency unavailability" do
    failure = Redis::CannotConnectError.new("connection refused")
    @connection.stub(:call, ->(*) { raise failure }) do
      reissue_error =
        assert_raises(Umaxica::Valkey::Unavailable) do
          @store.reissue_reference!(
            reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
          )
        end
      restore_error =
        assert_raises(Umaxica::Valkey::Unavailable) do
          @store.restore_reference!(
            reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
            raw_code: "original-code",
          )
        end
      read_error = assert_raises(Umaxica::Valkey::Unavailable) { @store.read_reference!(reference: "entry-1") }

      assert_same failure, reissue_error.cause
      assert_same failure, restore_error.cause
      assert_same failure, read_error.cause
    end
  end

  test "public operations reject blank locators and unsupported purpose lists" do
    [nil, "", " "].each do |blank|
      assert_raises(ArgumentError) { @store.read(blank) }
      assert_raises(ArgumentError) { @store.read_reference!(reference: blank) }
      assert_raises(ArgumentError) { @store.consume_reference!(reference: blank) }
      assert_raises(ArgumentError) do
        @store.restore_reference!(
          reference: "entry-1", purpose: "authentication_handoff", actor_type: "client", surface: "app",
          raw_code: blank,
        )
      end
    end
    [[], ["unknown_purpose"]].each do |purposes|
      assert_raises(ArgumentError) { @store.consume_reference!(reference: "entry-1", purposes:) }
    end

    assert_raises(ArgumentError) { @store.issue!(purpose: "unknown", actor_type: "client", surface: "app") }
    assert_raises(ArgumentError) do
      @store.reissue_reference!(reference: "entry-1", purpose: "unknown", actor_type: "client", surface: "app")
    end
    assert_raises(ArgumentError) do
      @store.restore_reference!(
        reference: "entry-1", purpose: "unknown", actor_type: "client", surface: "app", raw_code: "code",
      )
    end
  end
end
