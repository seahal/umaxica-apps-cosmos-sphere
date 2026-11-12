# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class PublicEntrypointInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    APPLICATION_PREFIXES = %w(core warp palm).freeze
    RETIRED_PREFIXES = %w(auth base guid tech visa docs edit help info news performance).freeze
    PUBLIC_MODES = %i(bare open guest).freeze
    PRIVATE_MODES = %i(private deny_all).freeze
    DOCUMENT_PATH = Rails.root.join("docs/security/public-entrypoints.md")
    DOCUMENTED_CATEGORY_IDS = %w(
      PUBLIC_ROOTS PUBLIC_DASHBOARD PUBLIC_HEALTH PUBLIC_REVISION PUBLIC_CSP_REPORTS
      PUBLIC_WELL_KNOWN PUBLIC_ROBOTS_SITEMAPS PUBLIC_PREFERENCE PUBLIC_OAUTH_OIDC_SSO
      PUBLIC_SIGN_IN_UP PUBLIC_SIGN_OUT PUBLIC_CORE_API PUBLIC_WARP_SETTINGS PUBLIC_PWA_OFFLINE
    ).freeze

    RouteEntry = Struct.new(:verb, :path, :controller_path, :action, :controller_class, :mode, keyword_init: true)

    test "public entrypoint documentation names every enforced category" do
      content = File.read(DOCUMENT_PATH)

      DOCUMENTED_CATEGORY_IDS.each do |category_id|
        assert_includes content, "`#{category_id}`"
      end
    end

    test "retired controller namespaces do not own application routes" do
      routed = Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller].to_s
        controller if RETIRED_PREFIXES.include?(controller.split("/").first)
      end.uniq

      assert_empty routed
    end

    test "owned application routes resolve to local authentication declarations" do
      missing =
        application_route_entries.filter_map do |entry|
          next if local_authentication_declaration?(entry.controller_class)

          "#{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty missing, "Application routes must declare authentication mode locally:\n#{missing.join("\n")}"
    end

    test "every public application route matches a documented category" do
      undocumented =
        application_route_entries.filter_map do |entry|
          next unless PUBLIC_MODES.include?(entry.mode)
          next if documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty undocumented, "Public routes need a documented category:\n#{undocumented.join("\n")}"
    end

    test "private and deny-all routes do not match public categories" do
      wrongly_public =
        application_route_entries.filter_map do |entry|
          next unless PRIVATE_MODES.include?(entry.mode)
          next unless documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty wrongly_public, "Private routes must not match public categories:\n#{wrongly_public.join("\n")}"
    end

    test "unknown-host root remains the only application route outside the owned surface namespaces" do
      application_controllers =
        Rails.application.routes.routes.filter_map do |route|
          route.defaults[:controller].to_s.presence
        end

      unexpected =
        application_controllers.reject do |controller|
          controller == "unknown_hosts" || controller == "rails/pwa" ||
            controller == "inertia_rails/devtools/entries" ||
            APPLICATION_PREFIXES.include?(controller.split("/").first)
        end

      assert_empty unexpected
      assert_includes application_controllers, "unknown_hosts"
    end

    test "PUBLIC_PWA_OFFLINE covers exactly the Warp and Palm framework endpoints" do
      entries =
        Rails.application.routes.routes.filter_map do |route|
          next unless route.defaults[:controller] == "rails/pwa"

          [route.verb, route.path.spec.to_s.sub(/\(\.:format\)\z/, ""), route.defaults[:action]]
        end

      assert_equal 6, entries.size
      assert_equal ["GET"], entries.map(&:first).uniq
      assert_equal [["/offline", "offline"], ["/service-worker", "service_worker"]],
                   entries.map { |entry| entry.drop(1) }.uniq.sort
    end

    private

    def application_route_entries
      Rails.application.routes.routes.filter_map do |route|
        controller_path = route.defaults[:controller].to_s
        action = route.defaults[:action].to_s
        next if controller_path.blank? || action.blank?
        next unless APPLICATION_PREFIXES.include?(controller_path.split("/").first)

        controller_class = "#{controller_path.camelize}Controller".safe_constantize
        mode = authentication_mode(controller_class, action)

        RouteEntry.new(
          verb: route.verb.presence || "ANY",
          path: route.path.spec.to_s.sub(/\(\.:format\)\z/, ""),
          controller_path: controller_path,
          action: action,
          controller_class: controller_class,
          mode: mode,
        )
      end
    end

    def authentication_mode(controller_class, action)
      flunk("Missing controller class for application route") if controller_class.blank?

      if controller_class.respond_to?(:authentication_mode_for)
        controller_class.authentication_mode_for(action)
      elsif controller_class.const_defined?(:AUTHENTICATION_MODE, false)
        controller_class.const_get(:AUTHENTICATION_MODE, false)
      else
        flunk("#{controller_class.name} does not expose authentication mode metadata")
      end
    end

    def local_authentication_declaration?(controller_class)
      controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
        (controller_class.respond_to?(:local_authentication_mode_rules) &&
          controller_class.local_authentication_mode_rules.present?)
    end

    def documented_public_category(entry)
      public_root?(entry) || public_health?(entry) || public_revision?(entry) ||
        public_csp_report?(entry) || public_well_known?(entry) || public_robots_or_sitemap?(entry) ||
        public_preference?(entry) || public_oidc?(entry) || public_sign_entry?(entry) ||
        public_sign_out?(entry) || public_core_api?(entry) || public_warp_dashboard_or_settings?(entry)
    end

    def public_root?(entry) = PUBLIC_MODES.include?(entry.mode) && get?(entry) && entry.path == "/"

    def public_health?(entry)
      get?(entry) && [
        "/health", "/health/liveness", "/health/readiness", "/health/startup", "/api/v0/health.json",
      ].include?(entry.path)
    end

    def public_revision?(entry) = get?(entry) && ["/revision", "/api/v0/revision.json"].include?(entry.path)

    def public_csp_report?(entry) = post?(entry) && entry.path == "/csp-violation-report"

    def public_well_known?(entry) = get?(entry) && entry.path == "/.well-known/jwks.json"

    def public_robots_or_sitemap?(entry) = get?(entry) && ["/robots.txt", "/sitemap.xml"].include?(entry.path)

    def public_preference?(entry)
      entry.controller_path.match?(%r{\A(core|warp)/(app|org)/api/v0/preferences/(cookies|themes)\z}) &&
        (get?(entry) || entry.verb == "PATCH")
    end

    def public_oidc?(entry)
      entry.controller_path.match?(%r{\A(core|warp|palm)/(app|org)/oidc/(callbacks|closures)\z}) &&
        ((get?(entry) && entry.path == "/oidc/callback") ||
          (post?(entry) && entry.path == "/oidc/closures"))
    end

    def public_sign_entry?(entry)
      entry.controller_path.match?(%r{\A(core|warp|palm)/(app|org)/sign/(entries|interruptions)\z}) &&
        ((entry.path == "/sign" && (get?(entry) || post?(entry))) ||
          (get?(entry) && entry.path == "/sign/interruption"))
    end

    def public_sign_out?(entry)
      entry.controller_path.match?(%r{\A(core|warp|palm)/(app|org)/sign/(outs|out/completions)\z}) &&
        ["/sign/out", "/sign/out/new", "/sign/out/edit", "/sign/out/completion"].include?(entry.path)
    end

    def public_core_api?(entry)
      entry.controller_path.start_with?("core/") &&
        ((get?(entry) && entry.path == "/api/v0/session") ||
          (post?(entry) && entry.path == "/api/v0/token/refresh"))
    end

    def public_warp_dashboard_or_settings?(entry)
      get?(entry) && entry.controller_path.start_with?("warp/") &&
        ["/dashboard", "/settings"].include?(entry.path)
    end

    def get?(entry) = entry.verb.match?(/\bGET\b/)

    def post?(entry) = entry.verb.match?(/\bPOST\b/)
  end
end
