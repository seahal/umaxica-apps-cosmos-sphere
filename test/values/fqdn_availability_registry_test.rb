# typed: false
# frozen_string_literal: true

require "test_helper"

class FqdnAvailabilityRegistryTest < ActiveSupport::TestCase
  test "maps every Sphere route host to its owned availability slot" do
    expected = {
      "core/app/" => :core_service,
      "core/org/" => :core_staff,
      "core/net/" => :core_network,
      "core/dev/" => :core_developer,
      "warp/app/" => :warp_service,
      "warp/org/" => :warp_staff,
      "palm/app/" => :palm_service,
    }

    expected.each do |prefix, slot|
      routes =
        Rails.application.routes.routes.select do |route|
          route.defaults[:controller].to_s.start_with?(prefix)
        end

      assert_predicate routes, :any?, "expected routes for #{prefix}"

      routes.each do |route|
        route.constraints.fetch(:host).each do |host|
          assert_equal slot, FqdnAvailabilityRegistry.slot_for(host), "#{prefix} host constraint"
        end
      end
    end

    assert_equal expected.values.uniq.sort, FqdnAvailabilityRegistry::SLOT_NAMES.sort
  end

  test "refuses unowned and missing hosts" do
    assert_nil FqdnAvailabilityRegistry.slot_for("unowned.invalid")
    assert_nil FqdnAvailabilityRegistry.slot_for(nil)
    assert_nil FqdnAvailabilityRegistry.slot_for("")
  end
end
