# Cloudflare Private Origin Contract

This repository exposes Rails to Cloudflare Tunnel only through the Podman `frontend` network. Two
route types share that network but not a tunnel: published browser hostnames behind Access run over
the `Auth` tunnel, and Workers VPC runs over its own dedicated `umaxica-dev-workers-vpc` tunnel.
Neither ingress path changes Rails authentication, authorization, or surface ownership.

The tunnels are deliberately separate. Until 2026-09-05 the single VPC Service was bound to the
`Auth` tunnel, so every Access application, ingress rule, replica and token rotation on the
published browser path also moved the Edge Worker's only route to Rails. Splitting them means a
change to one cannot take out the other. See "Workers VPC Traffic" below.

Every connector is attached only to this compose project's private `frontend` network. The Edge and
Global compose projects must not share a host Podman network. Edge Workers reach Rails through a
Cloudflare Workers VPC Service bound to the Workers VPC tunnel; they never resolve or dial the Rails
container over a cross-project container network.

## Invariants and Verification Gates

The private transport invariant is:

```text
same Podman frontend network
  -> same Podman DNS
  -> private origin alias
  -> Rails listener
  -> HTTP response
```

The gates are intentionally independent:

1. **Private transport**: an ephemeral curl container on the same compose `frontend` network as the
   running connector reaches a retained content or Edit host's `/health/liveness` endpoint. Operator
   tools own their mounted root paths and access checks, so probe those hosts at `/` using the
   configured access credentials. No committed script performs this; the manual procedure is below.
2. **Host Authorization**: boot Rails in development, construct `ActionDispatch::HostAuthorization`
   from the effective settings, and send `GET /` through `Rack::MockRequest` to a stub endpoint.
   Confirm HTTP 200 for the documented private origin aliases and published site hostnames; confirm
   HTTP 403 for an unconfigured Umaxica hostname and an unrelated hostname. The 2026-10-13
   observation is recorded in
   [evidence](../../evidence/2026-10-13-environment-test-retirement-A6V9.md). This is an operational
   check, not a test-suite guard; repeat it after changing host configuration.
3. **Surface routing**: route contract tests recognize non-health resources for the configured Docs,
   News, Help, Info, and Edit host groups. Operator-tool mounts have separate host constraints.
4. **Podman DNS aliases**: `podman compose config` must show the private aliases on `core`'s
   `frontend` network and no new host port publication. The connector never needs an inbound host
   port and must not be given one; the only publications in the stack are `core`'s loopback-bound
   host `3001` to container `3000`, plus `3036` for Vite. See
   `docs/operations/development-host-port-exposure.md`.
5. **Workers VPC connector prerequisites**: `cloudflare-tunnel-workers-vpc` is pinned at the
   supported `2026.8.2` release, runs with QUIC, authenticates with its own tunnel token from the
   gitignored repository `.env`, and requires outbound UDP port 7844. Its `/ready` must report four
   `readyConnections` and its log must name tunnel `03a4a67c-2aca-4f2c-9aeb-d1666f18bc87` — any
   other tunnel id means the Workers VPC path has been re-coupled to a shared tunnel. See
   "Authenticating the Connector" below.
6. **Repository regression checks**: run the focused tests first, then the full Rails suite,
   coverage, and lint checks when the test databases are available.

`/health` is excluded from Rails Host Authorization in production. A successful Gate 1 request
therefore proves transport reachability only. It does not prove that the Host is accepted by
`ActionDispatch::HostAuthorization`, and it does not substitute for Gate 3 routing evidence.

## Development Scope

Development Rails is reachable through this tunnel for hostnames configured in the Cloudflare
account. The `core` container's frontend aliases and development Host Authorization must match the
retained route constraints for Docs, News, Help, Info, Edit, and the operator tools. The Cloudflare
account owns published hostnames and Access policy; local route configuration does not prove that an
external hostname is published or protected.

`edit.umaxica.org` follows the same private-origin contract: its remotely managed Tunnel ingress
uses `http://edit.org.localhost:3000` on `frontend`. The `core` aliases in
`.devcontainer/compose.yaml` are the repository source of that origin name. The Cloudflare account
owns the matching public-hostname, ingress, DNS, and Access records; update that remote
configuration by merging with its current ingress rather than replacing it.

Access is the control that keeps the development surface non-public, and it lives in the Cloudflare
account rather than in this repository — see "External Checks" below.

## Browser Traffic Through Access

Create the Cloudflare Access application before publishing its tunnel hostname. Enable Access
protection for the published route so cloudflared validates the Access assertion before proxying the
request. Rails application authorization remains responsible for every application permission;
Access does not replace it.

The accepted scope and the deferred Rails-side JWT validation decision remain in
`adr/org-cloudflare-access-authentication-layer.md`. Cloudflare documents the deployment ordering in
[Publish a self-hosted application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
and the tunnel Access options in
[Origin configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/origin-configuration/).

## Workers VPC Traffic

The development VPC Service is HTTP, and it targets **`core-workers-vpc.internal`** on port `3000`
(port `8080` for the production image). The Worker binding belongs to the Worker repository, not
this Rails repository.

That alias is not decoration, and no `*.localhost` name may replace it. RFC 6761 reserves the
`localhost.` domain, and glibc resolves any name under it to loopback _before_ a container resolver
is consulted — on the `frontend` network itself, `getent hosts core.app.localhost` answers `::1`,
not this container. A VPC Service pointed at a `*.localhost` name therefore cannot work, which is
what drove the service to target the raw Podman address `10.89.2.2` — an address that changes
whenever the network is recreated. `core-workers-vpc.internal` is a plain Compose alias on `core`'s
`frontend` network: neither loopback-reserved nor ephemeral.

The VPC Service target selects the private route only. The hostname in the Worker's `fetch()` URL
remains the origin Host/SNI, so it must still be a narrowly allowlisted Umaxica surface hostname and
must match the surface route constraint — `core-workers-vpc.internal` never appears as a Host and
needs no `config.hosts` entry. See Cloudflare's
[VPC Services configuration](https://developers.cloudflare.com/workers-vpc/configuration/vpc-services/).

This tunnel carries no ingress rules, no public hostname and no Access application, and must not
gain any. Cloudflare routes Workers VPC traffic from the VPC Service target rather than from tunnel
ingress, so a locally managed tunnel needs no ingress configuration at all.

Cloudflare documents cloudflared `2025.7.0` or newer, QUIC via `--protocol auto` or `quic`, and
outbound UDP 7844 for Workers VPC tunnels. This connector uses `auto` so a UDP blip falls back to
HTTP/2 instead of exiting. Do not pin `http2`. Cloudflare supports cloudflared releases only for one
year, so this repository pins the current supported `2026.8.2` release. See
[Connect with Cloudflare Tunnel](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).

Access and Workers VPC are separate route types. Based on that separation, this repository does not
require `CF-Access-*` headers on the VPC path. This is an operational inference to confirm in the
Cloudflare account before rollout, not a Rails authentication bypass.

## Authenticating the Connector

The Cloudflare account holds two remotely managed development tunnels, and a connector runs exactly
one of them. Compose defines one connector service per tunnel. The primary connector is part of the
default stack so the Dev Container lifecycle starts it. The alternative connector stays behind a
profile:

| Service                         | Profile                      | Token variable                  | Tunnel                               |
| :------------------------------ | :--------------------------- | :------------------------------ | :----------------------------------- |
| `cloudflare-tunnel`             | none (starts with the stack) | `CLOUDFLARED_TOKEN`             | `Auth` — published hostnames/Access  |
| `cloudflare-tunnel-edge`        | `tunnel-edge`                | `CLOUDFLARED_EDGE_TOKEN`        | `Edge`                               |
| `cloudflare-tunnel-workers-vpc` | none (starts with the stack) | `CLOUDFLARED_WORKERS_VPC_TOKEN` | `umaxica-dev-workers-vpc` — VPC only |

`cloudflare-tunnel-edge` merges `cloudflare-tunnel`'s definition through a YAML anchor, so the two
differ only in the edge profile and token; the pinned release, the QUIC command, the `frontend`
attachment, and the crash-loop caps are shared by construction. No test guards this any longer:
`test/tooling/compose_local_override_optional_test.rb` was removed, and Compose configuration is
verified by running it (`adr/no-test-suite-for-environment-construction.md`).

Each service reads its tunnel's scoped connector token from the repository-local `.env` and passes
it to cloudflared as `TUNNEL_TOKEN`. Neither is an account API key. Each authorizes a connector to
run one tunnel, so both are still secrets and must not be committed, logged, or pasted into a
command argument.

Retrieve a token in the Cloudflare dashboard:

1. Go to **Networking > Tunnels**.
2. Open the tunnel you want this machine to connect.
3. Select **Add a replica**.
4. Copy only the `eyJ...` token from the displayed installation command.
5. Store it in the repository root `.env` and restrict the file mode:

```dotenv
CLOUDFLARED_TOKEN=<paste the first tunnel's token here>
CLOUDFLARED_EDGE_TOKEN=<paste the second tunnel's token here>
CLOUDFLARED_WORKERS_VPC_TOKEN=<paste the umaxica-dev-workers-vpc token here>
```

```bash
chmod 600 .env
```

If `.env` already contains other settings, add or replace only the token lines. Never commit `.env`;
the repository, Docker, and container build ignore files all exclude it.

Both variables use `${VAR:-}` rather than `${VAR:?}`: Compose interpolates the whole file whichever
service is named, so a required variable would stop `up core` on a machine that never runs a tunnel.
A connector started without a token exits within milliseconds, and `restart: on-failure:3` bounds
that into a visible, stopped container rather than a restart storm. Read `podman logs` for the
connector when a tunnel does not come up.

The primary connector starts with `devcontainer up` and with a plain Compose `up`. The alternative
connector is opt-in. Run these from a host terminal, not from inside `core`:

```bash
devcontainer up --workspace-folder .         # starts cloudflare-tunnel
podman compose --profile tunnel-edge up -d   # alternative tunnel
```

Starting both is supported: the connectors serve their own tunnels over the same private frontend
network. Nothing in Rails changes with the choice of tunnel. Ingress rules and published hostnames
live in the Cloudflare account, while Rails Host Authorization and route constraints remain the
application boundary.

Do not leave a standalone `docker run ... tunnel run --token ...` connector running for either
tunnel at the same time. Inspect `docker ps` and `podman ps` on the host before switching to the
Compose sidecar.

To rotate or revoke the connector credential, refresh the token in the Cloudflare dashboard, replace
only that tunnel's token value in `.env`, and recreate its connector. Removing the local value alone
does not revoke a copied token at Cloudflare:

```bash
podman compose -f compose.yaml \
  up -d --force-recreate --no-deps cloudflare-tunnel
podman compose -f compose.yaml --profile tunnel-edge \
  up -d --force-recreate --no-deps cloudflare-tunnel-edge
```

The connector reaches Rails directly over `frontend`. It has no `host.docker.internal` alias, no
Edge project network, and no supported route back through a host-published application port. Keep
the Cloudflare VPC Service pointed at an unambiguous Rails service address on `frontend`.

## Running the Transport Probe

Run this from a host terminal: `podman` is not on `PATH` inside `core`. Start `core` and whichever
connector this session uses first.

Nothing is executed inside the cloudflared container — that image carries no shell, curl, or wget.
Every request comes from a throwaway curl container attached to the connector's own network, so a
`200` is evidence that the connector's network position reaches Rails, not merely that Rails is up.

Take the connector's network from its compose labels rather than assuming a project name:

```bash
cid=$(podman ps -q --filter label=com.docker.compose.service=cloudflare-tunnel)
net=$(podman inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$cid")
```

Gate the connector before reading anything into an origin result. A container id alone proves
nothing: `ps -q` still reports one between restarts, so a crash-looping connector otherwise reads as
a Rails or DNS fault instead.

```bash
podman inspect -f '{{.State.Status}} restarts={{.RestartCount}}' "$cid"   # want: running restarts=0
podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
  -sS --max-time 5 http://cloudflare-tunnel:2000/ready                    # want: {"status":200,...}
```

For retained content and Edit aliases, request `/health/liveness`; leave `Host` to curl so it sends
`<alias>:3000`, the form admitted by development Host Authorization. Operator-tool mounts have no
shared health endpoint: request `/` with their configured access mechanism and treat the HTTP
response as transport evidence, not proof of authorization.

The alias list is the `frontend` `aliases:` block of the `core` service in `compose.yaml`; that
block is the single source, so read it there rather than copying the names into a second list that
can drift:

```bash
aliases=$(podman inspect -f '{{range .NetworkSettings.Networks}}{{range .Aliases}}{{println .}}{{end}}{{end}}' \
  "$(podman ps -q --filter label=com.docker.compose.service=core)" | grep -E '^(docs|news|help|info)\.(app|com|org)\.localhost$|^edit\.org\.localhost$')

for a in $aliases; do
  podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
    -sS -o /dev/null --max-time 5 -w "%{http_code} $a\n" "http://$a:3000/health/liveness"
done
```

Every line must read `200`. Pin the curl tag, or a digest, rather than tracking `latest`.

Observed 2026-09-05: on `umaxica-apps-cosmos-sphere-dc_frontend` this loop returns `000`, not `200`,
for every `*.localhost` alias, and `getent hosts core.app.localhost` in the same container answers
`::1`. That is glibc applying RFC 6761 — names under the reserved `localhost.` domain resolve to
loopback without consulting the container resolver — so the probe never reaches Rails through those
names. It is a property of the probe container's resolver, not evidence about the connector:
cloudflared uses Go's own resolver and is not known to apply the same special case. Treat a `000`
here as inconclusive for the Access ingress path and diagnose that path through the connector
instead.

The Workers VPC routing alias is unaffected and is the one to probe for that path:

```bash
podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
  -sS -o /dev/null --max-time 5 -w "%{http_code}\n" \
  -H "Host: core.app.localhost" http://core-workers-vpc.internal:3000/health/
```

`Host:` is set explicitly because `core-workers-vpc.internal` is a routing name only and
`config.hosts` does not admit it — the same split the Worker's `fetch()` URL relies on.

A `403` is Host Authorization, not transport: the alias resolved and Rails answered, but no
`config.hosts` entry admits that name. Fix it in `config/environments/development.rb` or remove the
alias; do not read it as a connector fault.

The health endpoints are excluded from Host Authorization in production, so this gate proves
transport only — see the note under "Invariants and Verification Gates" and run Gates 2 and 3 for
the rest.

## External Checks

Repository checks cannot prove these Cloudflare-account and network controls:

- outbound UDP 7844 is allowed from the connector environment;
- the Access application exists before its published hostname, including the development hostnames;
- the published route enables Access validation;
- the VPC Service target, port, and Worker binding match this contract;
- the Edge Worker uses the intended VPC Service binding, with `remote: true` for local development
  when the request must traverse Cloudflare;
- the tunnel has no replica in a network that cannot reach this Rails origin. Cloudflare may route
  traffic to any connector replica, so every replica for this tunnel must provide the same origin
  reachability.

Treat each as blocked until verified in the deployment environment. Do not infer them from a local
`/health` response.

The second and third items were verified for development on 2026-08-10 against the ten published
Rails hostnames: every unauthenticated external request returned an Access login redirect, a nonce
probe confirmed no such request reached the origin, and authenticated browser traffic was observed
arriving at Rails from a public client address. Evidence is in
`research/implementation/2026-08-10-development-tunnel-access-verification.md`. That run covers
development only; the first and fourth items remain unverified, and production remains blocked on
all four. A dated verification run is evidence, not a substitute for re-checking after any account
change.

The repository route contract now keeps Docs, News, Help, Info, Edit, and the six operator tools.
Historical external scan results describe only their dated observation and do not establish current
Cloudflare Access or Tunnel state. Verify published hostnames, Access protection, cookie forwarding,
and private-origin reachability in the deployment account after any edge change. Local Rails routing
does not establish that an external hostname is published.

## Server-to-Server Calls Through the Tunnel May Fail

After the Cosmos split, server-to-server calls between repositories (an RP fetching Visa's Discovery
and JWKS or calling its token, UserInfo and revocation endpoints; Access fetching an RP's
`/.well-known/jwks.json`) travel through the public hostnames and each repository's Cloudflare
Tunnel. Such calls can fail for reasons outside the application, so a failure on this path does not
by itself indicate an application defect:

- **Cloudflare Access.** The `app`, `com` and `org` hosts use the `surface-gate` policy. While it is
  locked (Allow, owner emails), every server-to-server call is redirected to the Access login and
  fails; RP sign-in stops until it is unlocked (`plans/2026-11-08-cloudflare-tunnel-split.md`).
- **Connector state.** A tunnel with no healthy connector answers Error 1033. A connector still
  running with another repository's token joins that tunnel as a replica, so requests reach a random
  repository.
- **Container lifecycle.** The receiving repository's Dev Container may be stopped or recreating.

Check these first when a cross-repository call fails in development. This path is not available for
offline or tunnel-less local work.
