# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Guards docs/operations/development-host-port-exposure.md.
#
# A `ports:` entry with no host address makes Podman bind 0.0.0.0, which places a development
# service on every host interface (LAN, Wi-Fi, Ethernet, Tailscale). This test reads the Compose
# files as text rather than running `podman compose config`, so it needs no container engine and
# runs in CI. It is a contract test over committed configuration, not a test of environment
# construction (.agents/harnesses/rules/project/no-environment-tests.mdc).
class ComposeHostPortExposureTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # Every tracked Compose file that participates in a development `up`. The gitignored
  # `compose.override.yaml` is deliberately absent: it is optional, per-machine, and not present
  # on a fresh clone.
  COMPOSE_FILES = %w(
    compose.yaml
    .devcontainer/compose.yaml
  ).freeze

  # Services that must never be reachable from the host, at any bind address. Each is consumed
  # only over a Compose network, by service name. Tempo, Prometheus and Loki are backends of the
  # Alloy gateway: Grafana queries them over `observability`, and nothing on the host dials them.
  CONTAINER_ONLY_SERVICES = %w(tempo prometheus loki).freeze

  # An IPv4 or IPv6 loopback host address is the only accepted publication target.
  LOOPBACK_HOST_ADDRESSES = ["127.0.0.1", "::1"].freeze

  def test_every_published_port_binds_loopback
    offenders = each_published_port.reject { |entry| loopback?(entry.fetch(:published)) }

    assert_empty offenders.map { |entry| describe(entry) },
                 "Compose port publications must name an explicit loopback host address " \
                 "(127.0.0.1 or ::1). A bare \"PORT:PORT\" binds 0.0.0.0 and exposes the " \
                 "service to the LAN."
  end

  def test_backend_observability_services_have_no_host_publication
    offenders =
      each_published_port.select { |entry| CONTAINER_ONLY_SERVICES.include?(entry.fetch(:service)) }

    assert_empty offenders.map { |entry| describe(entry) },
                 "Tempo, Prometheus and Loki are reached only by Alloy and Grafana over the " \
                 "`observability` network. Publishing one to the host adds an ingestion path " \
                 "that bypasses the single Alloy gateway."
  end

  # Each Cosmos repository publishes only its Dev Container Rails, on its own host port, so the four
  # Dev Containers can run side by side. Datastores, Vite, noVNC, fakecloud, Grafana and Alloy are
  # reached over Compose networks only.
  def test_only_dev_container_rails_is_published
    entries = each_published_port.to_a

    assert_equal [["core", "3000"]], entries.map { |entry| [entry.fetch(:service), container_port(entry)] },
                 "Only `core` publishes, and only Rails (container port 3000); found " \
                 "#{entries.map { |entry| describe(entry) }.inspect}"
  end

  def test_no_service_uses_host_networking
    offenders =
      each_service.filter_map do |file, service, definition|
        "#{file} #{service}: network_mode: host" if definition["network_mode"] == "host"
      end

    assert_empty offenders,
                 "`network_mode: host` bypasses port publication entirely and puts every " \
                 "listener on the host's interfaces."
  end

  # fakecloud is the one AWS-facing service that is published, and only to loopback so OpenTofu
  # and the AWS CLI can run from the host. No service may gain a container socket mount: that
  # would hand it full container-management rights under the invoking user, which is a far
  # larger grant than any port publication.
  def test_no_service_mounts_a_container_socket
    offenders =
      each_service.flat_map do |file, service, definition|
        Array(definition["volumes"]).filter_map do |mount|
          source = mount.is_a?(Hash) ? mount["source"].to_s : mount.to_s
          "#{file} #{service}: #{source}" if source.include?("docker.sock") || source.include?("podman.sock")
        end
      end

    assert_empty offenders, "No Compose service may mount a container runtime socket."
  end

  private

  def each_service
    COMPOSE_FILES.flat_map do |file|
      services = load_compose(file)["services"] || {}
      services.filter_map { |name, definition| [file, name, definition] if definition }
    end
  end

  def each_published_port
    each_service.flat_map do |file, service, definition|
      Array(definition["ports"]).map do |port|
        { file: file, service: service, entry: port, published: published_host_address(port) }
      end
    end
  end

  # Compose accepts both the short string form ("127.0.0.1:3000:3000") and the long mapping form
  # ({"target" => 3000, "published" => "3000", "host_ip" => "127.0.0.1"}). Anything this method
  # cannot resolve to a host address is reported rather than assumed safe.
  def published_host_address(port)
    return port["host_ip"].to_s if port.is_a?(Hash)

    text = port.to_s
    return text[/\A\[([^\]]+)\]:/, 1] if text.start_with?("[")

    segments = text.split(":")
    (segments.length >= 3) ? segments.first : ""
  end

  def container_port(entry)
    port = entry.fetch(:entry)
    return port["target"].to_s if port.is_a?(Hash)

    interpolate(port.to_s).split(":").last
  end

  def interpolate(text)
    text.gsub(/\$\{[A-Z0-9_]+:-([^}]*)\}/, '\1')
  end

  def loopback?(address)
    LOOPBACK_HOST_ADDRESSES.include?(address)
  end

  def describe(entry)
    "#{entry.fetch(:file)} #{entry.fetch(:service)}: #{entry.fetch(:entry).inspect}"
  end

  def load_compose(relative_path)
    path = File.join(REPOSITORY_ROOT, relative_path)
    return {} unless File.exist?(path)

    # Compose interpolation (`${VAR:-default}`) is opaque to YAML but always sits inside a scalar,
    # so plain parsing is enough to read the structure. Aliases must be expanded: the second
    # Cloudflare connector merges the first, and an unexpanded service would hide whatever it
    # inherits from this contract. The inputs are tracked repository files, so there is no
    # untrusted anchor to guard against.
    YAML.safe_load_file(path, aliases: true) || {}
  end
end
