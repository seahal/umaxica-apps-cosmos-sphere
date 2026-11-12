# Development Host Port Exposure

Development containers do not publish services to the host's external network interfaces by default.
Where host access is genuinely required, the publication is restricted to loopback.

This is the standing contract for every Compose file in this repository. It is not advice about a
particular service, and a host firewall is not an acceptable substitute for it.

## The Rule

1. **Prefer no publication at all.** If a service is only consumed by other containers, it gets no
   `ports:` entry. Containers reach it by Compose service name over the shared network
   (`primary:5432`, `valkey-cache:6379`, `valkey-kvs:6379`, `tempo:3200`).
2. **If the host genuinely needs it, publish to loopback only.** Write the bind address explicitly:
   `127.0.0.1:3001:3000`, never `3001:3000`. A `ports:` entry with no host address makes Podman bind
   `0.0.0.0`, which places the service on every host interface — LAN, Wi-Fi, Ethernet, and Tailscale
   included.
3. **Datastores are never published.** PostgreSQL (`primary`, `replica`) and Valkey are reached only
   by Compose DNS name; host-native Rails is not supported.

## Container Bind and Host Publication Are Separate Decisions

A process binding `0.0.0.0` _inside_ its container is normal and usually required — it is how the
container becomes reachable on the Podman network at all. It says nothing about host exposure, which
is decided solely by `ports:`.

```text
BINDING=0.0.0.0             ->  Rails listens on the core container's own interfaces.
ports: 127.0.0.1:3001:3000  ->  the host reaches container Rails on host port 3001 only.
ports: 3001:3000            ->  every machine on the LAN reaches it.  <- not allowed
```

`.devcontainer/compose.yaml` therefore keeps `BINDING: "0.0.0.0"` and `VITE_RUBY_HOST: "0.0.0.0"`.
Do not "harden" those to `127.0.0.1`: that would break `cloudflare-tunnel`, the transport probe in
`docs/operations/cloudflare-private-origin.md`, and every container-to-container call, while
changing nothing about host exposure.

## Current Publications

Each Cosmos repository publishes exactly one host port: its Dev Container Rails. The four
repositories use different host ports so their Dev Containers can run side by side:

| Repository                       | Host publication | Container port |
| -------------------------------- | ---------------- | -------------- |
| `umaxica-apps-cosmos-access`     | `127.0.0.1:3001` | `core:3000`    |
| `umaxica-apps-cosmos-governance` | `127.0.0.1:3002` | `core:3000`    |
| `umaxica-apps-cosmos-press`      | `127.0.0.1:3003` | `core:3000`    |
| `umaxica-apps-cosmos-sphere`     | `127.0.0.1:3004` | `core:3000`    |

Everything else is reached over Compose networks by service name and has no host publication:
PostgreSQL (`primary`, `replica`), Valkey (`valkey`, `valkey-cache`, `valkey-kvs`), Vite (3036),
noVNC (6080), fakecloud (4566), Grafana, Alloy, Tempo, Prometheus and Loki. Host-native Rails is not
supported, so nothing on the host needs a datastore or telemetry port. Without the Vite publication,
assets still load through Rails, but browser hot module replacement does not connect.

`test/tooling/compose_host_port_exposure_test.rb` pins this: only `core` publishes, only container
port `3000`, and only to loopback.

## Kafka

The broker runs two listeners, both on the `backend` network:

```text
CONTROLLER://kafka:29093    KRaft quorum
INTERNAL://kafka:29092      clients and inter-broker traffic
```

There is no `EXTERNAL` listener. The previous `EXTERNAL://0.0.0.0:9092`, advertised as
`localhost:9092`, existed only to back the host publication of 9092. Nothing consumes it: no
`rdkafka`, `racecar`, `ruby-kafka`, or `karafka` dependency exists, and the
`opentelemetry-instrumentation-*` entries in `Gemfile.lock` instrument clients that are not
installed. The healthcheck bootstraps from `kafka:29092`.

Adding a Kafka client later means pointing it at `kafka:29092`. It does not mean restoring the host
publication.

## Cloudflare Tunnel

`cloudflare-tunnel` needs no inbound host port and must never be given one. It dials Cloudflare
outbound over QUIC (UDP 7844) and resolves the Rails origin over Global's private Podman network:

```text
cloudflare-tunnel -> frontend network -> core:3000 (Rails)
```

The Edge Worker reaches Rails through its Cloudflare Workers VPC Service binding; the Edge and
Global compose projects do not share a host Podman network. Tunnel and VPC Service routing live in
the Cloudflare account, not in this repository. The Rails target must name a `frontend` service
address. A target pointing at `host.docker.internal:3000` would route Cloudflare traffic back out
through the host and is not supported by this contract — see
`docs/operations/cloudflare-private-origin.md`.

## Verification

Run on the **host**, not inside a container:

```sh
podman ps --format 'table {{.Names}}\t{{.Ports}}'
sudo ss -lntup | grep -E ':(3001|3002|3003|3004)\b'
```

Expected: each running repository's `core` shows its own `127.0.0.1:300N->3000/tcp`, and no other
container shows a host mapping. No line contains `0.0.0.0`, `*`, or a LAN address.

From a second machine on the same LAN, this must fail to connect:

```sh
curl --max-time 5 http://<host-lan-ip>:3001/
```

The container-network path is gated separately by the transport probe in
`docs/operations/cloudflare-private-origin.md`, whose Gate 4 also requires `podman compose config`
to show no new host port publication.

## Out of Scope

GitHub Actions `services:` blocks in `.github/workflows/` publish `5432` and `6379` on the runner.
That is a different threat model — a single-use runner VM with no LAN neighbours and no persistent
data — and the addresses are runner-local. This contract governs Compose files only, and
`test/tooling/compose_host_port_exposure_test.rb` checks Compose files only.

## Review Checklist

Reject a change that adds any of the following without an entry in the table above:

- a `ports:` value with no explicit host address
- a datastore publication that is not bound to `127.0.0.1`
- any publication of Kafka 9092
- a `network_mode: host` service
- a `--publish`/`-p` flag in a script that omits the bind address
