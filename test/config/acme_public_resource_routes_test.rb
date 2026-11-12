# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AcmePublicResourceRoutesTest < ActiveSupport::TestCase
  def test_route_files_do_not_use_param_public_id
    route_files = Dir.glob(File.expand_path("../../config/routes/*.rb", __dir__))
    violations =
      route_files.filter_map do |path|
        File.read(path).match?(/param:\s*:public_id/) ? File.basename(path) : nil
      end

    assert_empty violations, "Remove `param: :public_id` from route files: #{violations.join(", ")}"
  end
end
