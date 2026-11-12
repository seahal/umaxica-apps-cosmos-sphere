# frozen_string_literal: true

require "test_helper"

class RuntimeAndValuesRound8AuthenticationValueContractsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a previously classified authentication context retains its identity during strict lookup" do
    normal = AuthenticationContextValue.normal
    standby = AuthenticationContextValue.standby

    assert_same normal, AuthenticationContextValue.for(normal)
    assert_same standby, AuthenticationContextValue.for(standby)
    assert_raises(AuthenticationContextValue::UnknownContextError) { AuthenticationContextValue.for("untrusted-context") }
  end

  test "session options preserve host-only cookie isolation in both explicit secure modes" do
    secure = JitSessionCookieConfig.session_options(force_secure: true)
    plain = JitSessionCookieConfig.session_options(force_secure: false)

    assert_equal "__Host-session", secure.fetch(:key)
    assert_equal "session", plain.fetch(:key)
    assert_same true, secure.fetch(:secure)
    assert_same false, plain.fetch(:secure)
    [secure, plain].each do |options|
      assert_equal 14.days, options.fetch(:expire_after)
      assert_same true, options.fetch(:httponly)
      assert_equal :lax, options.fetch(:same_site)
      assert_not options.key?(:domain)
    end
  end
end
