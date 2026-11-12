# typed: false
# frozen_string_literal: true

require "test_helper"

class RetentionPurgeJobTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "invalid batch sizes fail before any deletion" do
    [nil, "", "not-a-number", 0, -1, 501, 1.5].each do |batch_size|
      assert_raises(ArgumentError) { RetentionPurgeJob.perform_now(batch_size:) }
    end
  end

  test "eligible audit history is purged while future and infinite retention remain" do
    now = ClientChronicle.database_now
    event = ClientChronicleEvent.create!
    level = ClientChronicleLevel.create!
    subject_id = SecureRandom.random_number(1_000_000_000) + 1
    deadlines = [now - 1.second, now, now + 1.second, Float::INFINITY]
    ClientChronicle.insert_all!(
      deadlines.map do |deadline|
        {
          subject_id:,
          subject_type: "HistoricalSubject",
          event_id: event.id,
          level_id: level.id,
          created_at: now - 1.day,
          updated_at: now - 1.day,
          discard_at: now - 1.day,
          purge_eligible_at: deadline,
        }
      end,
    )

    FeatureFlags.stub(:enabled?, false) do
      ClientChronicle.stub(:database_now, now) { RetentionPurgeJob.perform_now(batch_size: 1) }
    end

    assert_equal deadlines.last(2), ClientChronicle.where(subject_id:, subject_type: "HistoricalSubject")
      .order(:purge_eligible_at).pluck(:purge_eligible_at)
  end

  test "suspension preserves every Chronicle target at the reachable batch boundaries" do
    FeatureFlags.stub(:enabled?, true) do
      [1, 500, "500"].each do |batch_size|
        assert_no_difference RetentionPurgeJob::RETAINABLE_MODELS.map { |model| "#{model.name}.count" } do
          RetentionPurgeJob.perform_now(batch_size:)
        end
      end
    end
  end

  test "database failures are reported and propagated from the public job boundary" do
    failure = PG::ConnectionBad.new("Chronicle writer unavailable")
    reports = []

    FeatureFlags.stub(:enabled?, false) do
      AppPreferenceChronicle.stub(:database_now, -> { raise failure }) do
        Rails.error.stub(:report, ->(error, **options) { reports << [error, options] }) do
          raised =
            assert_raises(PG::ConnectionBad) do
              RetentionPurgeJob.perform_now(batch_size: 1)
            end

          assert_same failure, raised
        end
      end
    end

    assert_equal 1, reports.length
    assert_same failure, reports.fetch(0).first
    assert_equal "AppPreferenceChronicle", reports.fetch(0).last.fetch(:context).fetch(:retained_model)
    assert_equal 1, reports.fetch(0).last.fetch(:context).fetch(:batch_size)
  end
end
