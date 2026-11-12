# Remove rails_db (2026-11-10)

Owner: this repository (same change in all four Cosmos repositories). Status: decided (owner,
2026-11-10, "too dangerous"); urgent.

## Why

`rails_db` is a browser database console. In development it self-mounts at `/rails/db` on every host
with no authentication (`RailsDb.automatic_routes_mount` defaults to true and
`RailsDb.verify_access_proc` to allow all), exposing arbitrary SQL execution
(`POST /rails/db/execute`) and table truncation. The Gemfile keeps it in `group :development` and
`test/security/invariants/mounted_engine_invariant_test.rb` keeps it out of test and production, but
development Rails is published through Cloudflare Tunnel, and the public `app`/`com`/`org` hosts sit
behind the `surface-gate` Access policy, which is normally Bypass. So while a development container
is running and the gate is open, the console may be reachable from the internet on hosts such as
`auth.umaxica.app/rails/db`. Not verified by request; treat as exposed.

## Immediate mitigation (owner)

Lock `surface-gate` (Allow, owner emails) until `rails_db` is removed from every running development
container, or confirm `/rails/db` is unreachable on each public host from a private window.

## Work order (Codex)

```
Remove the rails_db gem from this repository:
- Delete `gem "rails_db"` and its comment from the Gemfile; update Gemfile.lock with
  `bundle install --local` (only rails_db and its now-unused dependencies may disappear).
- Remove every reference: initializers, routes, configuration, documentation, the RailsDb entries in
  test/security/invariants/mounted_engine_invariant_test.rb (keep the invariant for the remaining
  engines and keep `/rails/db` in the forbidden paths so it can never return).
- Confirm no route under /rails/db exists in development (`bin/rails routes` filtered), and that the
  development server answers /rails/db with 404 on every host.
- Run bin/rubocop, the mounted-engine invariant and test/security. Record results in evidence/.
- Do not touch other operator tools, authentication or databases. No commit.
```

Afterwards, recreate the development containers so no running process still loads the gem, then
unlock `surface-gate` if desired.
