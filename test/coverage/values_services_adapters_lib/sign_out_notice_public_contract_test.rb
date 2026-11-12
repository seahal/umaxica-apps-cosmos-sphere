# frozen_string_literal: true

require "test_helper"

class SignOutNoticePublicContractTest < ActiveSupport::TestCase
  test "issue stores only notice fields with a bounded expiry and an opaque key" do
    connection = Minitest::Mock.new
    connection.expect(:key, "notice:hashed", [String])
    encoded = nil
    connection.expect(:call, "OK") do |command, key, body, nx, ex, ttl|
      encoded = JSON.parse(body)
      command == "SET" && key == "notice:hashed" && nx == "NX" && ex == "EX" && ttl == 300
    end
    now = Time.zone.parse("2026-11-12T12:00:00Z")
    token = Valkey::AuthState::SignOutNoticeStore.new(connection: connection).issue!(
      payload: { actor_ref: "opaque-owner",
                 face: "app",
                 sid: "session",
                 state: "signed-out",
                 access_expires_at: "later",
                 ignored: "secret", }, now: now,
    )

    assert_equal 32, Base64.urlsafe_decode64(token).bytesize
    assert_match(/\A[A-Za-z0-9_-]+=*\z/, token)
    assert_equal(
      { "version" => 1,
        "actor_ref" => "opaque-owner",
        "face" => "app",
        "sid" => "session",
        "state" => "signed-out",
        "access_expires_at" => "later",
        "expires_at" => "2026-11-12T12:05:00Z", }, encoded,
    )
    connection.verify
  end

  test "read returns live notices and rejects the expiry boundary" do
    now = Time.zone.parse("2026-11-12T12:00:00Z")
    [-1, 0, 1].each do |offset|
      connection = Minitest::Mock.new
      connection.expect(:key, "notice:hashed", [Digest::SHA256.hexdigest("opaque-id")])
      payload = { "version" => 1, "expires_at" => (now + offset).iso8601 }
      connection.expect(:call, payload.to_json, ["GET", "notice:hashed"])
      result = Valkey::AuthState::SignOutNoticeStore.new(connection: connection).read(raw_id: "opaque-id", now: now)
      offset.positive? ? assert_equal(payload, result) : assert_nil(result)
      connection.verify
    end
  end

  test "consume uses atomic read delete and missing notices remain missing" do
    ["", nil].each do |encoded|
      connection = Minitest::Mock.new
      connection.expect(:key, "notice:hashed", [String])
      connection.expect(
        :call, encoded,
        ["EVAL", Valkey::AuthState::SignOutNoticeStore::GETDEL_SCRIPT, 1, "notice:hashed"],
      )

      assert_nil Valkey::AuthState::SignOutNoticeStore.new(connection: connection).consume(raw_id: "opaque")
      connection.verify
    end
  end

  test "corrupt stored values fail explicitly through the public reader" do
    ["{", "[]", { version: 2 }.to_json, { version: 1, unexpected: true }.to_json,
     { version: 1 }.to_json, { version: 1, expires_at: "invalid" }.to_json,].each do |encoded|
      connection = Minitest::Mock.new
      connection.expect(:key, "notice:hashed", [String])
      connection.expect(:call, encoded, ["GET", "notice:hashed"])
      assert_raises(Umaxica::Valkey::SerializationError) do
        Valkey::AuthState::SignOutNoticeStore.new(connection: connection).read(raw_id: "opaque")
      end
      connection.verify
    end
  end

  test "blank notice ids are rejected before the storage boundary" do
    [nil, "", " "].each do |id|
      assert_raises(ArgumentError) do
        Valkey::AuthState::SignOutNoticeStore.new(connection: Minitest::Mock.new).storage_key(id)
      end
    end
  end

  test "write collisions fail explicitly" do
    connection = Minitest::Mock.new
    connection.expect(:key, "notice:hashed", [String])
    connection.expect(:call, nil, ["SET", "notice:hashed", String, "NX", "EX", 300])
    assert_raises(Umaxica::Valkey::OperationError) do
      Valkey::AuthState::SignOutNoticeStore.new(connection: connection).issue!(payload: {})
    end
    connection.verify
  end
end
