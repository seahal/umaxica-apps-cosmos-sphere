# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"
# require "helpers/global_test_support"

class LocaleInitializerTest < ActiveSupport::TestCase
  INITIALIZER_PATH = Rails.root.join("config/initializers/locale.rb")

  test "loads locale files when REGION_CODE is not set" do
    ENV.delete("REGION_CODE")

    assert_nothing_raised { reload_locale_initializer }
    assert_equal supported_locale_paths, config_locale_load_paths
    assert_equal [:en, :ja], I18n.available_locales.sort
    assert_equal :ja, I18n.default_locale
    assert_equal [:en], I18n.fallbacks[:en]
    assert_equal [:ja], I18n.fallbacks[:ja]
  end

  test "english and japanese locale bundles have identical leaf keys" do
    locale_trees = {
      en: YAML.load_file(Rails.root.join("config/locales/en.yml"), aliases: true).fetch("en"),
      ja: YAML.load_file(Rails.root.join("config/locales/ja.yml"), aliases: true).fetch("ja"),
    }
    leaf_keys =
      lambda do |value, prefix|
        if value.is_a?(Hash)
          value.flat_map { |key, child| leaf_keys.call(child, prefix + [key.to_s]) }
        else
          [prefix.join(".")]
        end
      end
    keys_by_locale = locale_trees.transform_values { |tree| leaf_keys.call(tree, []).to_set }
    differences = {
      en_only: (keys_by_locale.fetch(:en) - keys_by_locale.fetch(:ja)).to_a.sort,
      ja_only: (keys_by_locale.fetch(:ja) - keys_by_locale.fetch(:en)).to_a.sort,
    }

    assert_equal({ en_only: [], ja_only: [] }, differences)
  end

  test "does not resolve a missing translation from the other language" do
    reload_locale_initializer
    I18n.backend.store_translations(:en, locale_fallback_probe: { english_only: "English probe" })
    I18n.backend.store_translations(:ja, locale_fallback_probe: { japanese_only: "日本語の確認" })
    english_only_key = %w(locale_fallback_probe english_only).join(".")
    japanese_only_key = %w(locale_fallback_probe japanese_only).join(".")

    I18n.with_locale(:en) do
      assert_equal "English probe", I18n.t(english_only_key)
      assert_raises(I18n::MissingTranslationData) do
        I18n.with_locale(:ja) { I18n.t(english_only_key) }
      end
    end

    I18n.with_locale(:ja) do
      assert_equal "日本語の確認", I18n.t(japanese_only_key)
      assert_raises(I18n::MissingTranslationData) do
        I18n.with_locale(:en) { I18n.t(japanese_only_key) }
      end
    end
  ensure
    I18n.backend.reload!
  end

  private

  # Pure I18n/config test - no database/fixtures needed. `use_transactional_tests = false` was
  # the wrong tool for that: it makes Rails clear the process-wide fixture cache
  # (`@@already_loaded_fixtures`) on every run, which forces every other `fixtures :all` test
  # class to reload all ~200 fixture tables (~600 extra queries) on its next example. Overriding
  # these two hooks as no-ops opts this class out of the fixtures machinery entirely, without that
  # side effect, while keeping every other `ActiveSupport::TestCase` behavior (assertions, the
  # `test` DSL) intact. See docs/guides/test-profiling.md.
  def setup_fixtures(*)
  end

  def teardown_fixtures(*)
  end

  def reload_locale_initializer
    load(INITIALIZER_PATH)
  end

  def config_locale_load_paths
    I18n.load_path
      .map(&:to_s)
      .select { |path| path.start_with?(Rails.root.join("config/locales").to_s) }
      .sort
  end

  def supported_locale_paths
    %w(
      config/locales/en.yml
      config/locales/ja.yml
    ).map { |path| Rails.root.join(path).to_s }.sort
  end
end
