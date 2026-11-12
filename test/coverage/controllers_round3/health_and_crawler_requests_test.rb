# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageRoundThreeHealthAndCrawlerRequestsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "all seven routed surfaces preserve the probe namespace and machine representation contracts" do
    [
      [ENV.fetch("PUBLIC_CORE_SERVICE_URL"), "core/app"], [ENV.fetch("PUBLIC_CORE_STAFF_URL"), "core/org"],
      ["core.net.localhost", "core/net"], ["core.dev.localhost", "core/dev"],
      [ENV.fetch("PUBLIC_WARP_SERVICE_URL"), "warp/app"], [ENV.fetch("PUBLIC_WARP_STAFF_URL"), "warp/org"],
      [ENV.fetch("PUBLIC_PALM_SERVICE_URL"), "palm/app"],
    ].each do |host, namespace|
      browser = open_session
      browser.host!(host)
      browser.https!
      startup = Health::CheckResult.new(check: :startup, status: :ok, surface: namespace)
      liveness = Health::CheckResult.new(check: :liveness, status: :ok, surface: namespace)
      readiness = Health::CheckResult.new(check: :readiness, status: :unready, surface: namespace)
      snapshot = Health::CheckResult.new(
        check: :snapshot, status: :unready, surface: namespace, dependencies: {
          "startup" => { status: "ok" }, "liveness" => { status: "ok" }, "readiness" => { status: "unavailable" },
        },
      )
      Health::StartupCheck.stub(:call, startup) do
        browser.get("/health/startup")

        assert_equal 200, browser.response.status
        assert_equal "ok\n", browser.response.body
        Health::LivenessCheck.stub(:call, liveness) do
          browser.get("/health/liveness")

          assert_equal 200, browser.response.status
          assert_equal "ok\n", browser.response.body
          Health::ReadinessCheck.stub(:call, readiness) do
            browser.get("/health/readiness")

            assert_equal 503, browser.response.status
            assert_equal "unavailable\n", browser.response.body
            browser.get("/api/v0/health.json", headers: { "Accept" => "application/json" })

            assert_equal 503, browser.response.status
            assert_equal "application/json", browser.response.media_type
            assert_equal namespace, browser.response.parsed_body.fetch("namespace")
            assert_equal "fail", browser.response.parsed_body.fetch("status")
            checks = browser.response.parsed_body.fetch("checks")

            assert_equal "pass", checks.fetch("liveness").fetch("status")
            assert_equal "fail", checks.fetch("readiness").fetch("status")
            assert_equal "no-store", browser.response.headers["Cache-Control"]
          end
        end
      end
      Health::SnapshotCheck.stub(:call, snapshot) do
        browser.get("/health")

        assert_equal 503, browser.response.status
        assert_includes browser.response.body, "namespace: #{namespace}\n"
        assert_equal 7, browser.response.body.lines.size
        assert_equal "no-store", browser.response.headers["Cache-Control"]
      end
      browser.get("/api/v0/health.json", headers: { "Accept" => "text/html" })

      assert_equal 406, browser.response.status
      assert_empty browser.response.body
      browser.get("/revision")

      assert_equal 200, browser.response.status
      assert_equal "noindex, nofollow", browser.response.headers["X-Robots-Tag"]
      browser.get("/api/v0/revision.json", headers: { "Accept" => "application/json" })

      assert_equal 200, browser.response.status
      assert browser.response.parsed_body.key?("revision")
    end
  end

  test "Warp and Palm expose only their public crawler documents with deliberate sitemap caching" do
    %w(PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL PUBLIC_PALM_SERVICE_URL).each do |setting|
      browser = open_session
      browser.host!(ENV.fetch(setting))
      browser.https!
      browser.get("/robots.txt")

      assert_equal 200, browser.response.status
      assert_equal "text/plain", browser.response.media_type
      assert_equal "User-agent: *\nDisallow:\n", browser.response.body
      browser.get("/sitemap.xml")

      assert_equal 200, browser.response.status
      assert_equal "application/xml", browser.response.media_type
      assert_includes browser.response.headers.fetch("Cache-Control"), "public"
      assert_includes browser.response.headers.fetch("Cache-Control"), "s-maxage=600"
      assert_equal "max-age=600", browser.response.headers["Surrogate-Control"]
      assert_equal "http://www.sitemaps.org/schemas/sitemap/0.9", Nokogiri::XML(browser.response.body).root.namespace.href
    end
  end
end
