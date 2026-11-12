# typed: false
# frozen_string_literal: true

# The effect strings below describe operator-facing switches in the Flipper UI,
# not product copy shown to users, so they are not localized.
# rubocop:disable I18n/RailsI18n/DecorateString

# The single registry of every Flipper feature this application reads.
#
# Two problems motivate it, both observed in this codebase:
#
#   1. A misspelled feature name is not an error. `Flipper.enabled?(:outbund_email_suspended)`
#      returns false forever, so a suspension switch silently never fires and a
#      fail-closed gate silently never opens. Going through `enabled?` here turns
#      an unregistered name into an ArgumentError at the call site.
#   2. Polarity was documented only in prose next to each call site, so "what does
#      unset mean here" had to be rediscovered per feature. It is declared once,
#      per flag, below.
#
# Adding a flag means adding a row here. `Security::Invariants::FeatureFlagRegistryInvariantTest`
# fails if any other file calls `Flipper.enabled?` directly.
module FeatureFlags
  # polarity:
  #   :suspension   ON = the effect is stopped. Unset = normal operation (fail-open).
  #                 A flag store that has never been written must not take the
  #                 product down.
  #   :availability ON = the ceremony is permitted. Unset = closed (fail-closed).
  #                 A lost flag must not let an authentication ceremony through.
  Flag = Data.define(:name, :polarity, :effect)

  POLARITIES = %i(suspension availability).freeze

  REGISTRY =
    [
      Flag.new(
        name: :retention_purge_suspended, polarity: :suspension,
        effect: "Stops the irreversible deletes and anonymization in RetentionPurgeJob.",
      ),
      *FqdnAvailabilityRegistry::SLOT_NAMES.map do |slot|
        Flag.new(
          name: FqdnAvailabilityRegistry.flag_name_for(slot), polarity: :availability,
          effect: "Controls availability for the #{slot} host group.",
        )
      end,
    ].index_by(&:name).freeze

  module_function

  # @param actor [#flipper_id, nil] restricts the check to one actor gate.
  # @param flipper [#enabled?] injection point for tests.
  def enabled?(name, actor = nil, flipper: Flipper)
    fetch(name)
    return flipper.enabled?(name) if actor.nil?

    flipper.enabled?(name, actor)
  end

  def fetch(name)
    REGISTRY.fetch(name.to_sym) do
      raise ArgumentError, "unregistered feature flag: #{name}"
    end
  end

  def names = REGISTRY.keys
end
# rubocop:enable I18n/RailsI18n/DecorateString
