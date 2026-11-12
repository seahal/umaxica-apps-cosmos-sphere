# typed: false
# frozen_string_literal: true

require "test_helper"

# Pins the legacy `/web/v0` and `/edge/v0` API surface. The Sphere route split retired its Base and
# Auth owners, so no legacy operations remain in this application.
#
# `adr/api-route-vocabulary-consolidation.md` (Accepted 2026-06-13) makes `/api/v0` the canonical
# namespace and treats these two as transitional: "Future API routes, and future migrations of
# existing API routes, should converge toward `/api/v0/...`". That direction had no enforcement, so
# nothing stopped the legacy surface from growing while the ADR said it should be shrinking.
#
# A route added under either legacy namespace requires a service-specific review, as in
# `.agents/harnesses/rules/project/regression-guards.mdc`.
class LegacyApiNamespaceGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  LEGACY_PREFIXES = %w(/web/v0 /edge/v0).freeze

  LEGACY_OPERATIONS = {}.freeze

  test "the legacy API namespaces contain exactly the pinned operations" do
    assert_equal LEGACY_OPERATIONS.keys.sort, routed_legacy_operations.to_a.sort,
                 "the retired /web/v0 and /edge/v0 namespaces must not return without review"
  end

  test "no service serves the same endpoint under both a legacy namespace and /api/v0" do
    # The comparison is per service and surface, not per path. The same path on two different hosts
    # is two different endpoints here -- `POST /edge/v0/token/refresh` is Base and
    # `POST /api/v0/token/refresh` is Core, and they are different credential transports, not a
    # duplicate. A single service answering the same question under both namespaces is the real
    # hazard: that is how one endpoint came to have two error formats depending on which namespace
    # the caller used.
    legacy = endpoints { |path| path.start_with?(*LEGACY_PREFIXES) }
    canonical = endpoints { |path| path.start_with?("/api/v0") }

    half_migrated =
      legacy.filter_map { |service, surface, verb, path|
        twin = [service, surface, verb, path.sub(%r{\A/(web|edge)/v0}, "/api/v0")]
        "#{service}/#{surface} #{verb} #{path}" if canonical.include?(twin)
      }

    assert_empty half_migrated,
                 "these endpoints are served under both a legacy namespace and /api/v0 by the same " \
                 "service: #{half_migrated.sort.join(", ")}"
  end

  test "core exposes no routes under a legacy API namespace" do
    core_legacy =
      endpoints { |path| path.start_with?(*LEGACY_PREFIXES) }
        .select { |service, _surface, _verb, _path| service == "core" }

    assert_empty core_legacy, "Core must expose preference APIs only under /api/v0"
  end

  private

  def routed_legacy_operations
    endpoints { |path| path.start_with?(*LEGACY_PREFIXES) }.map { |_, _, verb, path| "#{verb} #{path}" }.to_set
  end

  # Service and surface come from the controller path (for example `auth/app/web/v0/in/email/otps`) rather
  # than the route name, because the PATCH and PUT members that `resource` generates are unnamed.
  def endpoints
    Rails.application.routes.routes.filter_map { |route|
      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next unless yield(path)

      verb = route.verb.to_s
      next if verb.empty?

      service, surface = route.defaults[:controller].to_s.split("/").first(2)
      next if service.blank? || surface.blank?

      [service, surface, verb, path]
    }.to_set
  end
end
