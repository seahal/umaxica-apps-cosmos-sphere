# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class I18nDebugTest < ActiveSupport::TestCase
  test "lookup debug" do
    I18n.with_locale(:ja) do
      assert I18n.exists?("errors.otp_locked"), "ja.errors.otp_locked missing"
      assert I18n.exists?("sign.shared.sign_out.title"), "ja.sign.shared.sign_out.title missing"
    end

    I18n.with_locale(:en) do
      assert I18n.exists?("sign.default_passkey_description"),
             "en.sign.default_passkey_description missing"
    end
  end
end
