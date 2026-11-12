# frozen_string_literal: true

require "test_helper"
require "architecture_baseline"

class ResolversAndAuthValuesRound5ArchitectureBaselinePublicArtifactsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "baseline write derives sorted count and exclusion artifacts from one public measurement" do
    counts = {
      "Umaxica/ExplicitMethodVisibility" => { "app/z.rb" => 2, "app/a.rb" => 1 },
      "Umaxica/NoConcernInclusionHooks" => {},
    }
    artifacts = {}
    ArchitectureBaseline::COUNTS_PATH.stub(:write, ->(content) { artifacts[:counts] = content }) do
      ArchitectureBaseline::TODO_PATH.stub(:write, ->(content) { artifacts[:todo] = content }) do
        ArchitectureBaseline.write(counts)
      end
    end
    recorded = YAML.safe_load(artifacts.fetch(:counts))
    exclusions = YAML.safe_load(artifacts.fetch(:todo))

    assert_equal %w(app/a.rb app/z.rb), recorded.fetch("Umaxica/ExplicitMethodVisibility").keys
    assert_equal ["app/a.rb", "app/z.rb"], exclusions.fetch("Umaxica/ExplicitMethodVisibility").fetch("Exclude")
    assert_equal({}, recorded.fetch("Umaxica/NoConcernInclusionHooks"))
    assert_nil exclusions.fetch("Umaxica/NoConcernInclusionHooks").fetch("Exclude")
    assert artifacts.values.all? { |text| text.start_with?(ArchitectureBaseline::HEADER) }
    assert_equal 2, counts.fetch("Umaxica/ExplicitMethodVisibility").fetch("app/z.rb")
  end

  test "measurement refuses a failed subprocess that emitted no report" do
    status = Struct.new(:exitstatus).new(2)
    Open3.stub(:capture2, ["", status]) do
      error = assert_raises(ArchitectureBaseline::MeasurementError) { ArchitectureBaseline.measure }

      assert_equal "rubocop exited with 2 and no parsable output", error.message
    end
  end

  test "measurement counts only the owned architecture cops from the process report" do
    report = {
      "files" => [{ "path" => "app/example.rb",
                    "offenses" => [
                      { "cop_name" => "Umaxica/ExplicitMethodVisibility" },
                      { "cop_name" => "Umaxica/ExplicitMethodVisibility" },
                      { "cop_name" => "Style/Unrelated" },
                    ], }],
    }
    status = Struct.new(:exitstatus).new(1)
    measured = Open3.stub(:capture2, [JSON.generate(report), status]) { ArchitectureBaseline.measure }

    assert_equal({ "app/example.rb" => 2 }, measured.fetch("Umaxica/ExplicitMethodVisibility"))
    assert_empty measured.fetch("Umaxica/NoConcernInclusionHooks")
  end
end
