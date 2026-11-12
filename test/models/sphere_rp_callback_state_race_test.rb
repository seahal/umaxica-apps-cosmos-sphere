# frozen_string_literal: true

require "test_helper"

class SphereRpCallbackStateRaceTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "competing callback inserts commit only one state in each Sphere cell" do
    models = [RpCoreAppCallbackState, RpCoreOrgCallbackState, RpWarpAppCallbackState,
              RpWarpOrgCallbackState, RpPalmAppCallbackState,]

    models.each do |model|
      attributes = {
        state_digest: "race" * 8,
        browser_binding_digest: "b" * 32,
        nonce_digest: "n" * 32,
        pkce_challenge: "challenge",
        pkce_verifier_ciphertext: "encrypted-verifier",
        issuer: "https://issuer.example.test",
        realm: model::REALM,
        client_id: model::CLIENT_ID,
        expires_at: 5.minutes.from_now,
      }
      ready = Queue.new
      release = Queue.new
      outcomes = Queue.new
      workers =
        2.times.map do
          Thread.new do
            model.connection_pool.with_connection do
              candidate = model.new(attributes)
              ready << candidate.valid?
              release.pop
              begin
                model.transaction { model.insert_all!([attributes]) }
                outcomes << :committed
              rescue ActiveRecord::RecordNotUnique
                outcomes << :duplicate
              end
            end
          end
        end

      begin
        assert_equal [true, true], [ready.pop, ready.pop], model.name
        2.times { release << true }
        workers.each(&:join)

        assert_equal %i(committed duplicate), 2.times.map { outcomes.pop }.sort, model.name
        assert_equal 1, model.where(state_digest: attributes.fetch(:state_digest)).count, model.name
      ensure
        2.times { release << true }
        workers.each(&:join)
        model.where(state_digest: attributes.fetch(:state_digest)).delete_all
      end
    end
  end
end
