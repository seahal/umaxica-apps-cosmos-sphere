# typed: false
# frozen_string_literal: true

require "test_helper"

class RetainedSurfaceStylesheetContractTest < ActiveSupport::TestCase
  VIEW_ROOT = Rails.root.join("app/views")
  STYLESHEET_ROOT = Rails.root.join("src/styles")
  SURFACE_STYLESHEET_ROOT = STYLESHEET_ROOT.join("surfaces")
  RETAINED_SURFACE_STYLESHEETS = %w(
    core_app.css core_org.css core_dev.css palm_app.css warp_app.css warp_org.css
  ).freeze
  SURFACE_STYLESHEET_REFERENCE = /vite_stylesheet_tag\s+"~\/styles\/surfaces\/([^"]+)"/
  LINE_BREAKING_PROPERTIES = %w(line-break word-break overflow-wrap).freeze

  test "every retained template links only its own surface stylesheet" do
    references = surface_stylesheet_references

    assert_predicate references, :any?, "expected retained surface templates to link stylesheets"

    references.each do |template, names|
      family, surface = template_surface(template)

      assert_equal ["#{family}_#{surface}.css"], names,
                   "#{template} must link only src/styles/surfaces/#{family}_#{surface}.css"
      assert_path_exists SURFACE_STYLESHEET_ROOT.join(names.first)
    end
  end

  test "each retained surface stylesheet is linked by its own template" do
    referenced = surface_stylesheet_references.values.flatten.uniq

    assert_equal RETAINED_SURFACE_STYLESHEETS.sort, referenced.sort
    RETAINED_SURFACE_STYLESHEETS.each do |stylesheet|
      assert_path_exists SURFACE_STYLESHEET_ROOT.join(stylesheet)
    end
  end

  test "every shared stylesheet is imported by a retained surface stylesheet" do
    surfaces = Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).map { |path| File.read(path) }
    partials = Dir.glob(STYLESHEET_ROOT.join("*.css")).map { |path| File.basename(path) }

    assert_predicate partials, :any?, "expected shared stylesheets under src/styles"

    partials.each do |partial|
      assert surfaces.any? { |contents| contents.include?(%(@import "../#{partial}";)) },
             "src/styles/#{partial} is imported by no retained surface stylesheet"
    end
  end

  test "Japanese line breaking stays in the shared baseline" do
    base = STYLESHEET_ROOT.join("base.css").read

    LINE_BREAKING_PROPERTIES.each do |property|
      assert_match(/^\s*#{Regexp.escape(property)}:/, base)
    end
    assert_includes base, ":lang(ja) {"

    Dir.glob(STYLESHEET_ROOT.join("**/*.css")).reject { |path| File.basename(path) == "base.css" }.each do |path|
      contents = File.read(path)

      LINE_BREAKING_PROPERTIES.each do |property|
        assert_no_match(
          /^\s*#{Regexp.escape(property)}:/,
          contents,
          "#{path} must leave Japanese line breaking to base.css",
        )
      end
    end
  end

  test "each retained stylesheet scopes Tailwind to its own surface and explicit shared components" do
    Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).each do |path|
      stylesheet = Pathname.new(path)
      family, surface = stylesheet.basename(".css").to_s.split("_")
      contents = stylesheet.read

      assert_includes contents, %(@import "tailwindcss" source(none);),
                      "#{stylesheet} must disable Tailwind automatic source detection"
      expected_source = "../../../app/views/#{family}/#{surface}"

      assert_includes contents, %(@source "#{expected_source}";),
                      "#{stylesheet} must scan its own view directory"

      sources = contents.scan(%r{@source "([^"]+)";}).flatten

      expected_sources =
        if family == "core" && surface == "dev"
          [expected_source]
        else
          ["../../pages/#{family}/#{surface}", "../../layouts", "../../components", "../../features",
           "../../../app/views/layouts/#{family}/#{surface}", "../../../app/views/layouts/shared",
           "../../../app/views/shared", expected_source,]
        end

      assert_equal expected_sources.sort, sources.sort,
                   "#{stylesheet} must scan only its owned surface and explicit shared components"
    end
  end

  private

  def surface_stylesheet_references
    Dir.glob(VIEW_ROOT.join("**/*.html.erb")).each_with_object({}) do |path, references|
      names = File.read(path).scan(SURFACE_STYLESHEET_REFERENCE).flatten
      references[Pathname.new(path)] = names if names.any?
    end
  end

  def template_surface(template)
    relative = template.relative_path_from(VIEW_ROOT).each_filename.to_a
    relative.shift if relative.first == "layouts"
    relative.first(2)
  end
end
