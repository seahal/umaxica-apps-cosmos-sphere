# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpGatewayRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The gateway forwards a token it does not read, so the only thing it can check
  # is the shape. Each refusal is a token that could not have been issued here.
  test "a jump token of the wrong shape is refused by the reason it failed" do
    {
      "" => :blank_token,
      "short.token.here" => :token_too_short,
      ("a" * 70) => :malformed_token,
    }.each do |token, reason|
      result = RedirectsJumpGatewayUrl.call(token)

      assert_not result.ok?, token.inspect
      assert_equal reason.to_s, result.failure_reason, token.inspect
    end
  end

  test "a jump token carrying a control character is refused before its shape is read" do
    result = RedirectsJumpGatewayUrl.call("abc\u0000def" + ("a" * 70))

    assert_not result.ok?
    assert_equal "control_char", result.failure_reason
  end

  test "a well-formed jump token is forwarded to the gateway origin as the rt parameter" do
    token = "#{"a" * 30}.#{"b" * 30}.#{"c" * 30}"
    result = RedirectsJumpGatewayUrl.call(token)

    assert_predicate result, :ok?
    assert_includes result.value, "rt=#{token}"
    assert_match(%r{\Ahttps?://}, result.value)
  end
end
