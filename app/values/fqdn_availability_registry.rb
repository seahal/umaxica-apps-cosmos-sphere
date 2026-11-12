# typed: false
# frozen_string_literal: true

# The controller prefixes whose hosts have independent availability switches.
module FqdnAvailabilityRegistry
  CONTROLLER_SLOTS = {
    "core/app/" => :core_service,
    "core/org/" => :core_staff,
    "core/net/" => :core_network,
    "core/dev/" => :core_developer,
    "warp/app/" => :warp_service,
    "warp/org/" => :warp_staff,
    "palm/app/" => :palm_service,
  }.freeze

  SLOT_NAMES = CONTROLLER_SLOTS.values.uniq.freeze
  FLAG_PREFIX = "fqdn_available_"

  module_function

  def flag_name_for(slot) = :"#{FLAG_PREFIX}#{slot}"

  def flag_names = SLOT_NAMES.map { |slot| flag_name_for(slot) }

  def slot_for(hostname)
    host = CoreHostNormalization.normalize(hostname)
    return if host.nil?

    index[host]
  end

  def index
    @index ||=
      begin
        owned_routes = []
        Rails.application.routes.routes.each do |route|
          controller = route.defaults[:controller].to_s
          prefix = CONTROLLER_SLOTS.keys.find { |candidate| controller.start_with?(candidate) }
          next unless prefix

          constraint = route.constraints[:host]
          unless constraint.is_a?(Array) && constraint.present?
            raise ArgumentError, "#{controller} route has no explicit host constraint"
          end

          slot = CONTROLLER_SLOTS.fetch(prefix)
          constraint.each do |value|
            host = CoreHostNormalization.normalize(value)
            owned_routes << [host, slot] if host
          end
        end
        raise ArgumentError, "owned routes must define host constraints" if owned_routes.empty?

        owned_routes.each_with_object({}) do |(host, slot), hosts|
          existing_slot = hosts[host]
          if existing_slot && existing_slot != slot
            raise ArgumentError, "host constraint is assigned to multiple FQDN slots"
          end

          hosts[host] = slot
        end
      end.freeze
  end

  private_class_method :index
end
