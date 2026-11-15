# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectTargetUsageTest < ActiveSupport::TestCase
  DIRECT_PARAM_REDIRECT = /redirect_to\s*\(?\s*params\[/.freeze
  DIRECT_ALLOW_OTHER_HOST = /allow_other_host:\s*true/.freeze
  RAW_PT_PARAM = /\bparams\[:pt\]/.freeze
  LEGACY_XT_REDIRECT = /\bredirect_to_xt(?:_url)?\b/.freeze

  # Every entry builds its target from a route helper with a configured host, or from a destination
  # persisted and validated when its transaction was issued. None reads the target from a parameter.
  ALLOW_OTHER_HOST_ALLOWLIST = %w(
    app/controllers/concerns/common_redirect.rb
    app/controllers/concerns/oidc_rp_logout_launcher.rb
  ).freeze

  RAW_PT_ALLOWLIST_PATTERNS = [].freeze

  test "controllers do not redirect directly to params" do
    offenders =
      ruby_files.grep(%r{\Aapp/controllers/}).select do |path|
        File.read(path).match?(DIRECT_PARAM_REDIRECT)
      end

    assert_empty offenders
  end

  test "allow_other_host true is limited to reviewed Jump and protocol handoff boundaries" do
    users = ruby_files.select { |path| File.read(path).match?(DIRECT_ALLOW_OTHER_HOST) }

    assert_equal ALLOW_OTHER_HOST_ALLOWLIST.sort, users.sort
  end

  test "legacy xt redirect facade is not used" do
    offenders =
      ruby_files.select do |path|
        File.read(path).match?(LEGACY_XT_REDIRECT)
      end

    assert_empty offenders
  end

  test "retained sign-in views do not propagate raw authentication pt" do
    offenders =
      Dir.glob("app/views/sign/**/*.{erb,haml,slim}").select do |path|
        next false if RAW_PT_ALLOWLIST_PATTERNS.any? { |pattern| path.match?(pattern) }

        File.read(path).match?(RAW_PT_PARAM)
      end

    assert_empty offenders
  end

  test "retained controllers do not consume raw authentication pt directly" do
    offenders =
      Dir.glob("app/controllers/sign/**/*_controller.rb").select do |path|
        next false if RAW_PT_ALLOWLIST_PATTERNS.any? { |pattern| path.match?(pattern) }

        File.read(path).match?(RAW_PT_PARAM)
      end

    assert_empty offenders
  end

  private

  def ruby_files
    Dir.glob("{app,config,lib}/**/*.rb")
  end
end
