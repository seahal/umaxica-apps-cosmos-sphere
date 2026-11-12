# Role Secret Isolation (R5-WU03A)

Status: every runtime role uses the same Rails credentials set and database configuration. The
per-role secret boundary was withdrawn by the 2026-10-23 decision in
`adr/runtime-secret-isolation-deferred.md`.

## Shared credentials and database access

- Every process reads `config/credentials/<env>.yml.enc` with `<env>.key` and shares the configured
  `SECRET_KEY_BASE`. There are no per-role credential bundles.
- Development and test connect with the fixed local PostgreSQL configuration in
  `config/database.yml`. Runtime roles do not create separate PostgreSQL logins.
- All roles run in the same development container. The role name is an application routing and
  execution boundary, not an operating-system or database isolation boundary.

Consequently, a process can read credentials that its role does not use. Removing an entry from a
role's active key set does not prevent that process from decrypting the shared credentials file.

## Route ownership

`UMAXICA_RUNTIME_ROLE` is read once at boot from the fixed allowlist in `lib/runtime_role.rb`. It is
never derived from request input. `RuntimeRole.route_owner` assigns every retained controller path;
`lib/runtime_role_route_guard.rb` refuses an unowned path before controller callbacks run.

| Controller path                                                                     | Route owner         | Behavior                                                                |
| ----------------------------------------------------------------------------------- | ------------------- | ----------------------------------------------------------------------- |
| `docs/**`, `news/**`, `help/**`, `info/**`                                          | `domain-publishing` | Content surfaces and their health and revision endpoints                |
| `edit/**`                                                                           | `rp-edit-org-ww`    | Staff Publishing management RP                                          |
| `mission_control/jobs/**`, `blazer/**`, `pg_hero/**`, `rswag/api/**`, `rswag/ui/**` | `shared`            | Mounted operator tools; each mount has its own host and access boundary |
| `unknown_hosts`                                                                     | any role            | Host-independent 404 response                                           |
| Any other controller path                                                           | none                | Refused by every role, including `shared`                               |

The `shared` role can serve every path with an explicit owner. Other allowlisted roles do not gain a
controller route merely because their role name remains configured for protocol or background
execution. Rack mounts that do not use Action Controller retain their mount middleware and host
constraints.

## Signing keys

RP private-key selection is implemented in `RuntimeRole.rp_private_env_names`. It limits which
private key names an RP process actively loads; it does not create a credentials-file boundary.
Changes to this selection must preserve the Edit RP's own client assertion and redirect-validation
contracts. OP, Auth, and other retired controller trees are not route owners in the current
application.

See the [surface matrix](../architecture/content-surface-matrix.md) and the
[runtime secret decision](../../adr/runtime-secret-isolation-deferred.md) for the current ownership
and secret boundary.
