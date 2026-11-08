# typed: false
# frozen_string_literal: true

require "test_helper"

class BrowserSessionSecurityContextTest < ActiveSupport::TestCase
  test "is active when each bound session is active" do
    browser_session = Struct.new(:usable?).new(true)
    root_token = Struct.new(:active_status?).new(true)
    rp_session = Struct.new(:active?).new(true)
    context = BrowserSessionSecurityContext.new(
      resource: Object.new,
      browser_session: browser_session,
      root_token: root_token,
      rp_session: rp_session,
      access_payload: {},
    )

    assert_predicate context, :active?
  end
end
