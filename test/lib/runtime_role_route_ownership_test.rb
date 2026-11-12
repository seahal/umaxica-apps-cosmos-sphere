# frozen_string_literal: true

require "test_helper"

class RuntimeRoleRouteOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  FRAMEWORK_CONTROLLER_PATHS = %w(inertia_rails/devtools/entries rails/pwa).freeze

  test "every routed application controller has an explicit owner" do
    controllers = Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller]
      next if controller.blank?

      controller = controller.to_s
      controller
    end.uniq - FRAMEWORK_CONTROLLER_PATHS
    owner_errors =
      controllers.filter_map do |path|
        RuntimeRole.route_owner(path)
        nil
      rescue RuntimeRole::UnownedRoute
        path
      end

    assert_empty owner_errors, "Every routed controller needs an explicit owner: #{owner_errors.join(", ")}"
    assert_includes controllers, "unknown_hosts"
    assert controllers.any? { |path| path.start_with?("core/") }
    assert controllers.any? { |path| path.start_with?("warp/") }
    assert_equal RuntimeRole::ANY_ROLE, RuntimeRole.route_owner("unknown_hosts")
  end

  test "unknown-host response is available to every runtime role" do
    RuntimeRole::ALL.each do |role|
      assert RuntimeRole.serves?("unknown_hosts", role), "#{role} must answer the unknown-host route"
    end
  end

  test "operator-tool controllers run only in the shared process" do
    RuntimeRole::SHARED_CONTROLLER_PREFIXES.each do |prefix|
      controller_path = "#{prefix}/index"

      assert_equal RuntimeRole::SHARED, RuntimeRole.route_owner(controller_path)
      assert RuntimeRole.serves?(controller_path, RuntimeRole::SHARED)
      assert_not RuntimeRole.serves?(controller_path, "rp-core-app-jp")
      assert_not RuntimeRole.serves?(controller_path, "rp-warp-org-jp")
    end
  end

  test "Sphere RP controllers retain their runtime owners and Core infrastructure uses shared" do
    {
      "core/app/roots" => "rp-core-app-jp",
      "core/org/roots" => "rp-core-org-jp",
      "warp/app/roots" => "rp-warp-app-jp",
      "warp/org/roots" => "rp-warp-org-jp",
      "palm/app/roots" => "rp-palm-app-jp",
    }.each do |controller_path, role|
      assert_equal role, RuntimeRole.route_owner(controller_path)
      assert_includes RuntimeRole::ALL, role
      assert RuntimeRole.serves?(controller_path, RuntimeRole::SHARED)
    end
    %w(core/net/roots core/dev/roots).each do |controller_path|
      assert_equal RuntimeRole::SHARED, RuntimeRole.route_owner(controller_path)
    end
  end

  test "an RP role serves only its owned Sphere controller paths" do
    previous_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"

    assert RuntimeRole.serves?("core/app/roots", "rp-core-app-jp")
    assert RuntimeRole.serves?("warp/org/roots", "rp-warp-org-jp")
    assert RuntimeRole.serves?("palm/app/roots", "rp-palm-app-jp")
    assert_not RuntimeRole.serves?("core/org/roots", "rp-core-app-jp")
    assert_not RuntimeRole.serves?("warp/org/roots", "rp-core-app-jp")
  ensure
    if previous_admission.nil?
      ENV.delete("UMAXICA_RP_BROWSER_ADMISSION")
    else
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_admission
    end
  end

  test "closed RP admission refuses app routes while keeping health and back-channel routes" do
    previous_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "closed"

    assert_not RuntimeRole.serves?("core/app/roots", "rp-core-app-jp")
    assert RuntimeRole.serves?("core/app/healths", "rp-core-app-jp")
    assert RuntimeRole.serves?("core/app/oidc/closures", "rp-core-app-jp")
    assert RuntimeRole.serves?("warp/org/revisions", "rp-warp-org-jp")
    assert_not RuntimeRole.serves?("palm/app/sign/outs", "rp-palm-app-jp")
  ensure
    if previous_admission.nil?
      ENV.delete("UMAXICA_RP_BROWSER_ADMISSION")
    else
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_admission
    end
  end

  test "an unsupported RP admission state fails instead of serving a browser route" do
    previous_admission = ENV["UMAXICA_RP_BROWSER_ADMISSION"]
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "paused"

    assert_raises(RuntimeRole::UnknownRole) do
      RuntimeRole.serves?("core/app/roots", "rp-core-app-jp")
    end
  ensure
    if previous_admission.nil?
      ENV.delete("UMAXICA_RP_BROWSER_ADMISSION")
    else
      ENV["UMAXICA_RP_BROWSER_ADMISSION"] = previous_admission
    end
  end

  test "Sphere RP roles retain only their own client assertion and Jump RT key names" do
    {
      "rp-core-app-jp" => %w(OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY JWT_CORE_APP_PRIVATE_KEY),
      "rp-core-org-jp" => %w(OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY JWT_CORE_ORG_PRIVATE_KEY),
      "rp-warp-app-jp" => %w(OIDC_CLIENT_WARP_APP_JP_PRIVATE_KEY JWT_WARP_APP_PRIVATE_KEY),
      "rp-warp-org-jp" => %w(OIDC_CLIENT_WARP_ORG_JP_PRIVATE_KEY JWT_WARP_ORG_PRIVATE_KEY),
      "rp-palm-app-jp" => %w(OIDC_CLIENT_PALM_APP_JP_PRIVATE_KEY JWT_PALM_APP_PRIVATE_KEY),
    }.each do |role, expected_names|
      assert_equal expected_names, RuntimeRole.rp_private_env_names(role)
    end
  end

  test "retired controller namespaces have no runtime owner" do
    %w(auth base tech visa guid docs edit help info news performance).each do |namespace|
      controller_path = "#{namespace}/app/roots"

      assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner(controller_path) }
      assert_not RuntimeRole.serves?(controller_path, RuntimeRole::SHARED)
    end
    %w(core/com/roots warp/com/roots).each do |controller_path|
      assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner(controller_path) }
      assert_not RuntimeRole.serves?(controller_path, RuntimeRole::SHARED)
    end
  end
end
