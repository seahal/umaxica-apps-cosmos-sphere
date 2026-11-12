# frozen_string_literal: true

require "test_helper"

class CredentialCookieRuntimeContractTest < ActiveSupport::TestCase
  test "credential cookie lifetimes honor zero positive and invalid negative boundaries" do
    now = Time.zone.parse("2026-11-12T12:00:00Z")
    [0, 1, "0", "1"].each do |seconds|
      assert_equal now + seconds.to_i,
                   OidcRpBrowserCredentialContract.access_cookie_options(expires_in: seconds, now: now).fetch(:expires)
      assert_equal now + seconds.to_i,
                   OidcRpBrowserCredentialContract.refresh_cookie_options(expires_in: seconds, now: now).fetch(:expires)
    end
    [-1, "-1", "bad", [], 1.5].each do |seconds|
      assert_raises(ArgumentError) {
        OidcRpBrowserCredentialContract.access_cookie_options(expires_in: seconds, now: now)
      }
      assert_raises(ArgumentError) {
        OidcRpBrowserCredentialContract.refresh_cookie_options(expires_in: seconds, now: now)
      }
    end
    assert_raises(ArgumentError) { OidcRpBrowserCredentialContract.access_cookie_options }
    assert_raises(ArgumentError) { OidcRpBrowserCredentialContract.refresh_cookie_options }
    assert_raises(ArgumentError) { OidcRpBrowserCredentialContract.session_cookie_options(expires_at: nil) }
    assert_equal now, OidcRpBrowserCredentialContract.access_cookie_options(expires_at: now).fetch(:expires)
    assert_equal now, OidcRpBrowserCredentialContract.session_cookie_options(expires_at: now).fetch(:expires)
    assert_equal(
      { access_expires_at: now, refresh_expires_at: now + 1 },
      OidcRpBrowserCredentialContract.cookie_expiries_from_response(
        { "expires_in" => "0", "refresh_token_expires_in" => "1" }, now: now,
      ),
    )
    assert_raises(ArgumentError) do
      OidcRpBrowserCredentialContract.cookie_expiries_from_response(
        { expires_in: 2, refresh_token_expires_in: 1 },
        now: now,
      )
    end
    [nil, {}, { expires_in: -1 }, { expires_in: [] }, { expires_in: "bad" }].each do |response|
      assert_raises(ArgumentError) {
        OidcRpBrowserCredentialContract.access_expires_at_from_response(response, now: now)
      }
    end
  end

  test "credential responses require both tokens and deletion options preserve security scope" do
    assert_equal %w(access refresh),
                 OidcRpBrowserCredentialContract.require_token_response!(
                   "access_token" => "access",
                   "refresh_token" => "refresh",
                 )
    [{}, { access_token: "access" }, { access_token: "", refresh_token: "refresh" }].each do |response|
      assert_raises(ArgumentError) { OidcRpBrowserCredentialContract.require_token_response!(response) }
    end
    [OidcRpBrowserCredentialContract.session_cookie_deletion_options,
     OidcRpBrowserCredentialContract.access_cookie_deletion_options,
     OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,].each do |options|
      assert_equal "/", options[:path]
      assert_equal :lax, options[:same_site]
      assert_not options.key?(:expires)
      assert_not options.key?(:httponly)
    end
  end

  test "the default notice store round trips and atomically consumes isolated runtime state" do
    store = Valkey::AuthState::SignOutNoticeStore.new
    raw_id = store.issue!(payload: { actor_ref: "opaque-coverage-subject", state: "signed-out" })
    begin
      stored = store.read(raw_id: raw_id)

      assert_equal "opaque-coverage-subject", stored.fetch("actor_ref")
      assert_equal "signed-out", stored.fetch("state")
      assert_not_includes store.storage_key(raw_id), raw_id
      assert_equal stored, store.consume(raw_id: raw_id)
      assert_nil store.read(raw_id: raw_id)
    ensure
      store.consume(raw_id: raw_id)
    end
  end
end
