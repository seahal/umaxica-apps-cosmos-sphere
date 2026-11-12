# typed: false
# frozen_string_literal: true

require "test_helper"

# Push Line/Branch/Method toward the next whole .0% thresholds.
class BranchCoverageBatch40LinePushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "DiagnosticSurfaceCredentials guard fails closed and compares securely" do
    blank_source = Object.new
    blank_source.define_singleton_method(:option) { |_| nil }
    blocked = DiagnosticSurfaceCredentials.guard(
      user_key: :u, password_key: :p, credentials: blank_source,
    )

    assert_not blocked.call("u", "p")

    source = Object.new
    source.define_singleton_method(:option) do |key|
      { u: "alice", p: "secret" }.fetch(key)
    end
    guard = DiagnosticSurfaceCredentials.guard(user_key: :u, password_key: :p, credentials: source)

    assert guard.call("alice", "secret")
    assert_not guard.call("alice", "wrong")
    assert_not guard.call("bob", "secret")
  end
end
