# frozen_string_literal: true

require "test_helper"

class SphereRpCallbackDigestLengthTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  MODELS = [
    RpCoreAppCallbackState, RpCoreOrgCallbackState, RpWarpAppCallbackState,
    RpWarpOrgCallbackState, RpPalmAppCallbackState,
  ].freeze
  DIGEST_COLUMNS = %i(state_digest browser_binding_digest nonce_digest).freeze

  setup do
    @attributes = {
      state_digest: "s" * 32,
      browser_binding_digest: "b" * 32,
      nonce_digest: "n" * 32,
      pkce_challenge: "challenge",
      pkce_verifier_ciphertext: "encrypted-verifier",
      issuer: "https://issuer.example.test",
      expires_at: Time.utc(2030, 1, 1),
    }
  end

  test "models reject missing zero below and above 32-byte digests in every Sphere cell" do
    MODELS.each do |model|
      attributes = @attributes.merge(realm: model::REALM, client_id: model::CLIENT_ID)
      DIGEST_COLUMNS.each do |column|
        [nil, "", "x" * 31, "x" * 33, "\u00e9" * 32].each do |value|
          record = model.new(attributes.merge(column => value))

          assert_not record.valid?, "#{model.name}.#{column}: #{value.inspect}"
          assert_includes record.errors.details[column], { error: :wrong_length, count: 32 }
        end
      end
    end
  end

  test "32 bytes succeed for binary and multibyte inputs regardless of original character count" do
    # Unicode is intentional test data: sixteen two-byte characters must be treated as 32 bytes.
    ["\xFF\x00".b * 16, "\u00e9" * 16].each do |digest|
      MODELS.each do |model|
        attributes = @attributes.merge(
          realm: model::REALM, client_id: model::CLIENT_ID,
          state_digest: digest, browser_binding_digest: digest, nonce_digest: digest,
        )
        record = model.new(attributes)

        assert_equal 32, record.state_digest.length
        assert_equal Encoding::BINARY, record.state_digest.encoding
        assert_predicate record, :valid?
        result = model.insert_all!([attributes])
        saved = model.find(result.rows.flatten.first)

        DIGEST_COLUMNS.each { |column| assert_equal digest.b, saved[column] }
      end
    end
  end

  test "direct inserts reject missing zero below and above 32-byte digests for every column" do
    MODELS.each do |model|
      attributes = @attributes.merge(realm: model::REALM, client_id: model::CLIENT_ID)
      DIGEST_COLUMNS.each do |column|
        [nil, "", "x" * 31, "x" * 33, "\u00e9" * 32].each do |value|
          expected_error = value.nil? ? ActiveRecord::NotNullViolation : ActiveRecord::StatementInvalid
          error =
            assert_raises(expected_error, "#{model.name}.#{column}: #{value.inspect}") do
              model.transaction(requires_new: true) { model.insert_all!([attributes.merge(column => value)]) }
            end
          assert_kind_of(value.nil? ? PG::NotNullViolation : PG::CheckViolation, error.cause)
        end
      end
    end
  end

  test "direct updates cannot replace any valid digest with missing or invalid byte lengths" do
    MODELS.each do |model|
      record = model.create!(@attributes.merge(realm: model::REALM, client_id: model::CLIENT_ID))
      DIGEST_COLUMNS.each do |column|
        [nil, "", "x" * 31, "x" * 33, "\u00e9" * 32].each do |value|
          expected_error = value.nil? ? ActiveRecord::NotNullViolation : ActiveRecord::StatementInvalid
          assert_raises(expected_error, "#{model.name}.#{column}: #{value.inspect}") do
            model.transaction(requires_new: true) { model.where(id: record.id).update_all(column => value) }
          end
          assert_equal @attributes.fetch(column).b, record.reload[column]
        end
      end
    end
  end
end
