# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StandardErrorRescueInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REVIEWED_RESCUES = {
    "app/controllers/concerns/actor_support.rb" => {
      count: 1,
      classification: "auth boundary; current-resource failures raise ActorSupport::ResolutionError " \
                      "unless credentials were refused",
    },
  }.freeze

  test "reviewed StandardError rescues stay classified" do
    offenders =
      REVIEWED_RESCUES.filter_map do |path, expected|
        actual = rescue_count(path)
        next if actual == expected.fetch(:count) && expected.fetch(:classification).present?

        "#{path}: expected #{expected.fetch(:count)}, got #{actual} (#{expected.fetch(:classification)})"
      end

    assert_empty offenders, "Reviewed StandardError rescue inventory changed:\n#{offenders.join("\n")}"
  end

  private

  def rescue_count(path)
    Rails.root.join(path).read.scan(/\brescue\s+StandardError\b/).size
  end
end
