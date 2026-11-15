# typed: false
# frozen_string_literal: true

require "test_helper"

class PublicIdTest < ActiveSupport::TestCase
  # Define a dummy model for testing
  class DummyModel < ApplicationRecord
    include PublicId

    before_create :generate_public_id
    before_validation :generate_public_id, on: :create
    before_validation :refresh_generated_public_id_after_collision, on: :create
    around_create :retry_public_id_collision
    validate :public_id_immutable_after_create, on: :update
    validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true

    # This model is not backed by a real table, so we fake whatever ActiveRecord needs.
    # The dummy_models table does not exist in the test database, but we can temporarily
    # create it via ActiveRecord::Base.connection.create_table or reuse an existing table
    # by pointing table_name = :some_existing_table. We keep things simple since we only
    # verify the callback behavior. To call save! we do need a table, so we mimic the
    # pattern from ordinary fixtures by creating a temporary table here.
    # Alternatively, a migration could build this table during setup/teardown.

    # The temporary dummy_models table is created for each test run.
    # This configuration belongs in Minitest setup/teardown hooks.
  end

  setup do
    # Create a temporary dummy_models table that has a public_id column
    ActiveRecord::Base.connection.create_table(:dummy_models) do |t|
      t.string(:public_id)
      t.timestamps
    end
    DummyModel.reset_column_information
    # Mock Nanoid so that it always returns the same ID for stability
    @original_nanoid_generate = Nanoid.method(:generate)
    Nanoid.define_singleton_method(:generate) { |**_args| "testpublicid123456789" }
  end

  teardown do
    # Remove the temporary table
    ActiveRecord::Base.connection.drop_table(:dummy_models, if_exists: true)
    # Restore the original Nanoid mock
    Nanoid.define_singleton_method(:generate, @original_nanoid_generate)
  end

  test "public_id is generated before creation" do
    dummy_instance = DummyModel.new

    assert_nil dummy_instance.public_id
    dummy_instance.save!

    assert_not_nil dummy_instance.public_id
    assert_equal "testpublicid123456789", dummy_instance.public_id
  end

  test "generated public_id has correct length" do
    dummy_instance = DummyModel.new
    dummy_instance.save!

    assert_equal 21, dummy_instance.public_id.length
  end

  test "public_id is not nil after creation" do
    dummy_instance = DummyModel.new
    dummy_instance.save!

    assert_not_nil dummy_instance.public_id
  end

  test "existing public_id is not overridden" do
    dummy_instance = DummyModel.new
    dummy_instance.public_id = "existingid12345678901"
    dummy_instance.save!

    assert_equal "existingid12345678901", dummy_instance.public_id
  end

  test "public validation refreshes a generated identifier that already exists" do
    existing = DummyModel.create!(public_id: "a" * PublicId::GENERATION_SIZE)
    identifiers = [existing.public_id, "b" * PublicId::GENERATION_SIZE]
    candidate = DummyModel.new

    Nanoid.stub(:generate, ->(**) { identifiers.shift }) do
      assert_predicate candidate, :valid?
    end

    assert_equal "b" * PublicId::GENERATION_SIZE, candidate.public_id
  end

  test "public fixed-id insertion timestamps timestamped model rows and is idempotent" do
    identifier = 2_000_000_002

    DummyModel.transaction(requires_new: true) do
      assert_not DummyModel.exists?(id: identifier)
      assert_predicate DummyModel, :table_exists?

      assert DummyModel.insert_missing_fixed_ids!([identifier])
      DummyModel.insert_missing_fixed_ids!([identifier])
      row = DummyModel.find(identifier)

      assert_kind_of Time, row.created_at
      assert_kind_of Time, row.updated_at
      raise ActiveRecord::Rollback
    end
  ensure
    ApplicationRecord.clear_fixed_id_seed_cache!
  end

  test "public_id accepts exactly the 21-character NanoID length" do
    dummy_instance = DummyModel.new(public_id: "a" * 21)

    assert_predicate dummy_instance, :valid?
  end

  test "public_id rejects one character below and above the fixed length" do
    [20, 22].each do |length|
      dummy_instance = DummyModel.new(public_id: "a" * length)

      assert_not dummy_instance.valid?, "#{length} characters"
      assert dummy_instance.errors.of_kind?(:public_id, :wrong_length), "#{length} characters"
    end
  end

  test "persisted public_id cannot be changed through the record update boundary" do
    dummy_instance = DummyModel.create!
    dummy_instance.public_id = "replacementid12345678"

    error = assert_raises(ActiveRecord::RecordInvalid) { dummy_instance.save! }

    assert_equal "cannot be changed after creation", error.record.errors[:public_id].first
    assert_equal "testpublicid123456789", dummy_instance.reload.public_id
  end
end
