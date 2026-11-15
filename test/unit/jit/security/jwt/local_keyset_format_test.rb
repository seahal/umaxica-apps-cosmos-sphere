# typed: false
# frozen_string_literal: true

require "test_helper"

class LocalKeysetFormatTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "persisted local keyset marker remains tied to the PS256 RSA-3072 contract" do
    expected = ["PS256", "RSA", 3072, "v1"].join("-")

    assert_equal expected, JitSecurityJwtLocalKeysetInstaller::KEY_FORMAT
  end
end
