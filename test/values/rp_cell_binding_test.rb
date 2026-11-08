# frozen_string_literal: true

require "test_helper"

class RpCellBindingTest < ActiveSupport::TestCase
  test "the public connection catalog and client lookup share fixed bindings" do
    assert_equal RpCellBinding::CELLS.keys, RpCellBinding.connections
    RpCellBinding::CELLS.each do |connection, cell|
      assert_equal cell, RpCellBinding.fetch(connection)
      assert_equal cell, RpCellBinding.for_client(cell.client_id)
    end
  end

  test "unknown connections and client IDs are rejected" do
    assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.fetch("missing") }
    assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client("missing") }
  end
end
