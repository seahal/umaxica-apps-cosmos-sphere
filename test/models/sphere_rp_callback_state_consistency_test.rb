# frozen_string_literal: true

require "test_helper"

class SphereRpCallbackStateConsistencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  MODELS = [
    RpCoreAppCallbackState, RpCoreOrgCallbackState, RpWarpAppCallbackState,
    RpWarpOrgCallbackState, RpPalmAppCallbackState,
  ].freeze

  test "each Sphere cell rejects duplicate callback state before insertion" do
    MODELS.each do |model|
      attributes = {
        state_digest: "s" * 32,
        browser_binding_digest: "b" * 32,
        nonce_digest: "n" * 32,
        pkce_challenge: "challenge",
        pkce_verifier_ciphertext: "encrypted-verifier",
        issuer: "https://issuer.example.test",
        realm: model::REALM,
        client_id: model::CLIENT_ID,
        expires_at: 5.minutes.from_now,
      }
      original = model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?, model.name
      assert_includes duplicate.errors.details[:state_digest].pluck(:error), :taken, model.name
      assert_predicate original, :valid?
      assert_not_predicate original, :consumed?
      original.update!(consumed_at: Time.current)

      assert_predicate original.reload, :consumed?
      assert_predicate model.new(attributes.merge(state_digest: "t" * 32)), :valid?
    end
  end

  test "database uniqueness and not null survive validation bypass in every Sphere cell" do
    MODELS.each do |model|
      attributes = {
        state_digest: "u" * 32,
        browser_binding_digest: "b" * 32,
        nonce_digest: "n" * 32,
        pkce_challenge: "challenge",
        pkce_verifier_ciphertext: "encrypted-verifier",
        issuer: "https://issuer.example.test",
        realm: model::REALM,
        client_id: model::CLIENT_ID,
        expires_at: 5.minutes.from_now,
      }
      model.create!(attributes)

      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { model.insert_all!([attributes]) }
      end
      assert_raises(ActiveRecord::NotNullViolation) do
        model.transaction(requires_new: true) { model.insert_all!([attributes.merge(state_digest: nil)]) }
      end
      assert_not model.new(attributes.merge(state_digest: nil)).valid?
      assert_not model.new(attributes.merge(state_digest: "")).valid?
    end
  end

  test "callback states reject another cell identity through model and database writes" do
    MODELS.each do |model|
      attributes = {
        state_digest: "i" * 32,
        browser_binding_digest: "b" * 32,
        nonce_digest: "n" * 32,
        pkce_challenge: "challenge",
        pkce_verifier_ciphertext: "encrypted-verifier",
        issuer: "https://issuer.example.test",
        realm: model::REALM,
        client_id: model::CLIENT_ID,
        expires_at: 5.minutes.from_now,
      }

      [attributes.merge(realm: "net"), attributes.merge(client_id: "foreign-cell")].each do |foreign|
        assert_not model.new(foreign).valid?, model.name
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { model.insert_all!([foreign]) }
          end
        assert_kind_of PG::CheckViolation, error.cause
      end
    end
  end
end
