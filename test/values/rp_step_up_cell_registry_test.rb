# frozen_string_literal: true

require "test_helper"

class RpStepUpCellRegistryTest < ActiveSupport::TestCase
  test "only consistent Base RP cells have a step-up registry entry" do
    base_cell = RpCellBinding.fetch("rp_base_app")
    entry = RpStepUpCellRegistry.fetch(base_cell)

    assert_equal base_cell, entry.cell
    assert_equal RpBaseAppRecord, entry.record_class

    assert_raises(ArgumentError) { RpStepUpCellRegistry.fetch("rp_base_app") }
    assert_raises(ArgumentError) { RpStepUpCellRegistry.fetch(RpCellBinding.fetch("rp_core_app")) }
    assert_raises(ArgumentError) do
      RpStepUpCellRegistry.fetch(base_cell.with(client_id: "foreign-client"))
    end
  end
end
