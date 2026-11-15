# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "retired regional authorities cannot participate in Jump returns" do
    %w(app com org).each do |realm|
      retired_origin = "https://jp.umaxica.#{realm}"

      assert_nil JumpRtReturnPolicy.namespace_for_origin(retired_origin)
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: "https://www.umaxica.#{realm}", source: retired_origin,
      )
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: retired_origin, source: "https://www.umaxica.#{realm}",
      )
    end
  end

  test "duplicate configured issuer origins fail instead of selecting an ambiguous namespace" do
    JumpRtSurface.stub(:issuer_origin, ->(_namespace) { "https://duplicate.example" }) do
      error =
        assert_raises(JumpRtConfigurationError) do
          JumpRtReturnPolicy.namespace_for_origin("https://duplicate.example")
        end

      assert_includes error.message, "BASE_APP"
      assert_includes error.message, "VISA_APP"
    end
  end

  test "normalize_origin returns nil for invalid URI" do
    assert_nil JumpRtReturnPolicy.normalize_origin("not a url")
  end

  test "normalize_origin returns nil for non-http scheme" do
    assert_nil JumpRtReturnPolicy.normalize_origin("ftp://example.com")
  end

  test "normalize_origin returns nil for URI with userinfo" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://user:pass@www.umaxica.app")
  end

  test "origins with a path query or fragment are rejected" do
    ["https://www.umaxica.app/", "https://www.umaxica.app/path",
     "https://www.umaxica.app?x=1", "https://www.umaxica.app#fragment",].each do |origin|
      assert_nil JumpRtReturnPolicy.normalize_origin(origin), origin
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app", source: origin)
    end
  end

  test "normalize_origin normalizes https origin" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin normalizes http origin" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com")

    assert_equal "http://example.com", result
  end

  test "normalize_origin downcases host" do
    result = JumpRtReturnPolicy.normalize_origin("https://WWW.UMAXICA.APP")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin includes non-default port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:8443")

    assert_equal "https://www.umaxica.app:8443", result
  end

  test "normalize_origin omits default https port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:443")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin omits default http port" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com:80")

    assert_equal "http://example.com", result
  end

  test "normalize_origin returns nil for blank host" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://")
  end

  test "allowed_source returns true for valid source matching destination" do
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://visa.umaxica.app",
      source: "https://www.umaxica.app",
    )
  end

  test "allowed_source returns false for unauthorized source" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.umaxica.app",
      source: "https://evil.example.com",
    )
  end

  test "allowed_source returns false when destination origin is unknown" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://unknown.example.com",
      source: "https://www.umaxica.app",
    )
  end

  test "default_port_for returns 443 for https" do
    assert_equal 443, JumpRtReturnPolicy.default_port_for("https")
  end

  test "default_port_for returns 80 for http" do
    assert_equal 80, JumpRtReturnPolicy.default_port_for("http")
  end

  test "only Base and Visa authorization handoffs are allowed across all 16 ordered pairs" do
    namespaces = {
      "base-app" => "BASE_APP",
      "base-org" => "BASE_ORG",
      "visa-app" => "VISA_APP",
      "visa-org" => "VISA_ORG",
    }
    origins = {
      "base-app" => "https://www.umaxica.app",
      "base-org" => "https://www.umaxica.org",
      "visa-app" => "https://visa.umaxica.app",
      "visa-org" => "https://visa.umaxica.org",
    }
    edges = [
      ["base-app", "visa-app"],
      ["base-org", "visa-org"],
      ["visa-app", "base-app"],
      ["visa-org", "base-org"],
    ]
    expected_edges = edges.map { |source, destination| [namespaces.fetch(source), namespaces.fetch(destination)] }

    assert_equal 4, expected_edges.size
    assert_equal expected_edges.sort, JumpRtReturnPolicy::ALLOWED_EDGES.sort
    pairs = origins.keys.product(origins.keys)

    assert_equal 16, pairs.size
    pairs.each do |source, destination|
      assert_equal edges.include?([source, destination]),
                   JumpRtReturnPolicy.allowed_source?(
                     destination_origin: origins.fetch(destination),
                     source: origins.fetch(source),
                   ),
                   "#{source} -> #{destination}"
    end
  end

  test "A02-10: the Visa handoff table matches the signed Jump edge catalog" do
    document = Rails.root.join("docs/operations/jump-rt-visa-edges.md").read
    rows =
      document.scan(/^\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|$/).map do |row|
        row.map { |cell| cell.strip.delete_prefix("`").delete_suffix("`").strip }
      end
    expected =
      JumpRtReturnPolicy::EDGE_CATALOG.filter_map do |edge|
        issuer = edge.fetch(:issuer_namespace)
        destination = edge.fetch(:destination_namespace)
        next unless issuer.start_with?("VISA_") || destination.start_with?("VISA_")

        [issuer, JumpRtSurface.issuer_origin(issuer), destination, JumpRtSurface.issuer_origin(destination),
         edge.fetch(:purpose).tr("_", " "),]
      end

    assert_equal expected.sort, rows.select { |row| row.first.match?(/\A[A-Z_]+\z/) }.sort
    expected.each do |namespace, source, _destination, destination_origin, _purpose|
      token = JumpRtIssuer.call(namespace: namespace, url: "#{destination_origin}/", dst: "internal")
      issuer = JitSecurityJwtRegistry.surface(namespace)
      payload, = JWT.decode(
        token, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["PS256"], verify_iss: true, iss: source, verify_aud: true,
        aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )

      assert_equal destination_origin, URI.parse(payload.fetch("url")).origin
      assert JumpRtReturnPolicy.allowed_source?(destination_origin: destination_origin, source: source)
    end
  end

  test "the Jump edge catalog is the source of the allowed graph and names Visa origins" do
    projected =
      JumpRtReturnPolicy::EDGE_CATALOG.map do |edge|
        [edge.fetch(:issuer_namespace), edge.fetch(:destination_namespace)]
      end

    assert_equal projected.sort, JumpRtReturnPolicy::ALLOWED_EDGES.sort
    visa_edge_count =
      JumpRtReturnPolicy::EDGE_CATALOG.count do |edge|
        edge.fetch(:issuer_namespace).start_with?("VISA_") || edge.fetch(:destination_namespace).start_with?("VISA_")
      end

    assert_equal 4, visa_edge_count

    JumpRtReturnPolicy::EDGE_CATALOG.select do |edge|
      edge.fetch(:issuer_namespace).start_with?("VISA_") || edge.fetch(:destination_namespace).start_with?("VISA_")
    end.each do |edge|
      issuer = edge.fetch(:issuer_namespace)
      destination = edge.fetch(:destination_namespace)
      issuer_origin = JumpRtSurface.issuer_origin(issuer)
      destination_origin = JumpRtSurface.issuer_origin(destination)
      token = JumpRtIssuer.call(
        namespace: issuer, url: "https://jump-contract.example/oauth/authorize",
        dst: "internal",
      )
      payload, = JWT.decode(token, nil, false)

      assert_equal issuer_origin, payload.fetch("iss")
      assert_equal "https://jump-contract.example/oauth/authorize", payload.fetch("url")
      assert JumpRtReturnPolicy.allowed_source?(
        destination_origin: destination_origin,
        source: issuer_origin,
      ), "#{issuer} -> #{destination} (#{edge.fetch(:purpose)})"
    end
  end

  test "unregistered stale private and sentinel origins are denied in either direction" do
    [nil, "", "https://zzzz.umaxica.app", "https://www.umaxica.zzz",
     "https://www-zz.umaxica.app", "https://www.jp.umaxica.app", "https://jpx.umaxica.app",
     "https://palm.jp.umaxica.app", "https://edit.umaxica.org", "http://base.app.localhost",
     "https://base.app.localhost", "https://127.0.0.1",].each do |origin|
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app", source: origin)
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: origin, source: "https://www.umaxica.app")
    end
  end

  test "retired logical ceremony issuer is not a jump return source" do
    %w(app com org).each do |tld|
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: "https://www.umaxica.#{tld}",
        source: "https://log.umaxica.#{tld}",
      ), tld
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: "https://www.jp.umaxica.#{tld}",
        source: "https://log.umaxica.#{tld}",
      ), tld
    end
  end

  def with_env(values)
    saved = {}
    values.each_key { |key| saved[key.to_s] = ENV[key.to_s] }
    values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    values.each_key do |key|
      if saved[key.to_s].nil?
        ENV.delete(key)
      else
        ENV[key] = saved[key.to_s]
      end
    end
  end
end
