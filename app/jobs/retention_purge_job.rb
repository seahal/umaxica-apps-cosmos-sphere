# typed: false
# frozen_string_literal: true

# Chronicle retention uses the existing purge eligibility established by its lifecycle writers.
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  DEFAULT_BATCH_SIZE = 500
  MAX_BATCH_SIZE = 500
  FEATURE_NAME = :retention_purge_suspended
  RETAINABLE_MODELS = [
    AppPreferenceChronicle, OrgPreferenceChronicle, ClientChronicle, OperatorChronicle,
  ].freeze

  public

  def perform(batch_size: DEFAULT_BATCH_SIZE)
    limit = normalized_batch_size(batch_size)
    unless limit&.between?(1, MAX_BATCH_SIZE)
      raise ArgumentError, "batch_size must be between 1 and #{MAX_BATCH_SIZE}"
    end

    if FeatureFlags.enabled?(FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("retention.purge.suspended"))
      return
    end

    failures = []
    RETAINABLE_MODELS.each do |klass|
      now = klass.database_now
      klass.where(purge_eligible_at: ..now).in_batches(of: limit).delete_all
    rescue StandardError => e
      failures << e
      Rails.error.report(
        e,
        handled: false,
        context: { job: self.class.name, retained_model: klass.name, batch_size: limit },
      )
    end
    raise failures.first if failures.any?
  end

  private

  def normalized_batch_size(value)
    return value if value.is_a?(Integer)
    return Integer(value) if value.is_a?(String)

    nil
  rescue ArgumentError, TypeError
    nil
  end
end
