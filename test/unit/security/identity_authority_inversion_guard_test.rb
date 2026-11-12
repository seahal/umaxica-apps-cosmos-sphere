# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "retained Edit RP ID token verification uses its dedicated OIDC verifier" do
    callback = Rails.root.join("app/controllers/concerns/oidc_callback.rb").read
    verifier = Rails.root.join("app/adapters/oidc_op_id_token_verifier.rb")

    assert_predicate verifier, :file?
    assert_includes callback, "OidcOpIdTokenVerifier.new"
  end
end
