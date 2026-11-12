# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class I18nRuntimeDefaultCleanupTest < ActiveSupport::TestCase
  LOCALES = %i(ja en).freeze

  # meta.default_title is intentionally absent: the brand and its TLD edition are
  # a locale-independent contract carried by the layouts' meta-tags site title, so
  # only page-specific titles are translated.
  KEYS = %w(
    defaults.never
    time.formats.short
    errors.invalid_authenticity_token
  ).freeze

  test "runtime default cleanup keys exist for ja and en" do
    LOCALES.each do |locale|
      KEYS.each do |key|
        assert I18n.exists?(key, locale), "missing #{key} for #{locale}"
      end
    end
  end
end
