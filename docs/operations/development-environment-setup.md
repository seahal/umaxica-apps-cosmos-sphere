# Development Environment Setup

Status: draft. Sections marked "To be written" are placeholders for content that has not been
verified yet.

This guide collects, in order, every step a fresh clone needs before the application runs locally,
other than database preparation and seeding. Each step links to the document that owns the details;
this guide records only the order and the cross-cutting notes.

## 1. Host prerequisites

Install Podman 5 or newer, `podman-compose`, VS Code, and the Dev Containers extension, then apply
the one-time host configuration in
[devcontainer-cli-podman-startup.md](devcontainer-cli-podman-startup.md). Podman-specific caveats
are in [container-engine-podman-notes.md](container-engine-podman-notes.md).

## 2. Material that is not in git

Obtain and place the items listed in
[development-credential-provisioning.md](development-credential-provisioning.md):

- `config/credentials/development.key` and `config/credentials/test.key`, from the development lead.
  Never generate them with `bin/rails credentials:edit`.
- The repository-root `.env` with `UID`, `GID`, `CLOUDFLARED_TOKEN`, and `CLOUDFLARED_EDGE_TOKEN`.

## 3. Cloudflare tunnel

The retained Edit relying-party callback may need a public HTTPS development host when testing a
complete OIDC flow. Configure the development tunnel following
[cloudflare-private-origin.md](cloudflare-private-origin.md).

To be written: which development hostnames map to which surface, and how to confirm the tunnel is
reachable.

## 4. Start the development container

Follow [devcontainer-cli-podman-startup.md](devcontainer-cli-podman-startup.md). Port exposure rules
are in [development-host-port-exposure.md](development-host-port-exposure.md), and the available
container targets are in [development-container-targets.md](development-container-targets.md).

## 5. Databases

Database creation, migration, and seeding are covered by [db-workflow.md](db-workflow.md) and
[test-environment.md](test-environment.md). They are out of scope for this guide.

## 6. Local AWS substitute

To be written: when [local-aws-fakecloud.md](local-aws-fakecloud.md) is required for local work.

## 7. External identity provider

The retained Edit surface is an OIDC relying party. It does not serve local social sign-in or
provider callback routes. A complete local OIDC flow may need the external provider and its
registered callback configured to use the development tunnel. Keep provider credentials in the
provider's own approved secret boundary; this repository does not configure Google, Apple, or Entra
sign-in ceremonies.

## 8. Other external services

To be written: Cloudflare Turnstile ([../security/turnstile.md](../security/turnstile.md)) and any
other active service that needs per-environment configuration.

## 9. Verify the environment

To be written: the smallest set of checks that confirm a working setup.
