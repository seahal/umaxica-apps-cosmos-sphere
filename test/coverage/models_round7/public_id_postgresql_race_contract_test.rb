# frozen_string_literal: true

require "test_helper"

class PublicIdPostgresqlRaceContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a generated identifier collision after validation is retried against PostgreSQL" do
    first = "r7a" + ("A" * 18)
    replacement = "r7b" + ("B" * 18)
    identifiers = [first, replacement]
    candidate = RpCoreAppPrincipal.new
    PublicId.stub(:generate, -> { identifiers.shift }) do
      assert_predicate candidate, :valid?
      winner = RpCoreAppPrincipal.create!(public_id: first)
      candidate.save!(validate: false)

      assert_equal first, winner.reload.public_id
      assert_equal replacement, candidate.reload.public_id
      assert_not_equal winner.id, candidate.id
      assert_equal 2, RpCoreAppPrincipal.where(public_id: [first, replacement]).count
    end
    assert_empty identifiers
  end

  test "repeated PostgreSQL identifier collisions stop after the bounded retry budget" do
    collision = "r7c" + ("C" * 18)
    generated = 0
    candidate = RpCoreAppPrincipal.new
    PublicId.stub(
      :generate, -> {
                   generated += 1
                   collision
                 },
    ) do
      assert_predicate candidate, :valid?
      winner = RpCoreAppPrincipal.create!(public_id: collision)
      assert_raises(ActiveRecord::RecordNotUnique) { candidate.save!(validate: false) }

      assert_predicate candidate, :new_record?
      assert_equal winner.id, RpCoreAppPrincipal.find_by!(public_id: collision).id
      assert_equal 1, RpCoreAppPrincipal.where(public_id: collision).count
    end
    assert_equal PublicId::MAX_COLLISION_RETRIES + 1, generated
  end

  test "a primary key conflict is propagated without replacing a valid public identifier" do
    generated_id = "r7d" + ("D" * 18)
    generated = 0
    candidate = RpCoreAppPrincipal.new
    PublicId.stub(
      :generate, -> {
                   generated += 1
                   generated_id
                 },
    ) do
      assert_predicate candidate, :valid?
      existing = RpCoreAppPrincipal.create!(public_id: "r7e" + ("E" * 18))
      candidate.id = existing.id
      assert_raises(ActiveRecord::RecordNotUnique) { candidate.save!(validate: false) }

      assert_equal generated_id, candidate.public_id
      assert_equal "r7e" + ("E" * 18), existing.reload.public_id
      assert_predicate candidate, :new_record?
    end
    assert_equal 1, generated
  end
end
