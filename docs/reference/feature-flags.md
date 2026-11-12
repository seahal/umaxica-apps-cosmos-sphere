# Feature Flags

Flags are stored in Flipper's PostgreSQL `primary` database and managed through the mounted Flipper
operator tool. They are runtime controls. Required application configuration still uses
`ENV.fetch("NAME")` and fails at boot when it is missing.

## Current flags

| Flag                        | Polarity     | Effect                                                                             |
| --------------------------- | ------------ | ---------------------------------------------------------------------------------- |
| `retention_purge_suspended` | suspension   | Stops the irreversible deletes and anonymization performed by `RetentionPurgeJob`. |
| `fqdn_available_<slot>`     | availability | Controls one Core, Warp, or Palm host group.                                       |

Availability flags fail closed when unset or when the flag store is unavailable. Suspension flags
fail open when unset; an operator enables one to stop the named work.

The retained slots are `core_service`, `core_staff`, `core_network`, `core_developer`,
`warp_service`, `warp_staff`, and `palm_service`. `FqdnAvailabilityRegistry` derives the host
allowlist from the retained controller routes. Existing rows for retired host slots are left in the
database and are no longer read.

## Operational notes

- `db/seeds.rb` enables retained FQDN availability flags in development only. Production is not
  seeded; enabling a production availability flag is an explicit operator action through Flipper.
