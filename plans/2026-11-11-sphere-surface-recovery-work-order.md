Task (umaxica-apps-cosmos-sphere): recover Sphere's own surfaces that were deleted by mistake, then
redo the surface hard reset with Sphere's correct surface list. No commit. Never print secrets or
environment values.

## What went wrong

The previous run applied the wrong surface list. It deleted Sphere's own surfaces (Core, Warp, Palm:
about 260 paths, uncommitted) and kept Press's surfaces (docs, edit, help, info, news). It also
rewrote README.md to describe Press's surfaces. Nothing was committed, so every deleted file is
still in HEAD.

## Sphere's surfaces (the only correct list)

OWN, keep:

- core: app, org, net, dev hosts (`www-jp.umaxica.*`; development `core.*.localhost`)
- warp: app, org (`warp-jp.umaxica.*`) — no com (owner decision 2026-11-10;
  docs/backlog/2026-11-10-sphere-has-no-com.md)
- palm: app (`palm-jp.umaxica.app`)
- operator tools: mission, flipper, blazer, pghero, coverband, swagger See
  adr/cosmos-sphere-surfaces-and-rp-independence.md and its 2026-11-10 amendment.

FOREIGN, remove: docs, edit, help, info, news (Press); auth, visa (Access); base, tech (Governance);
guid, performance and every `.com` surface.

## Do not touch (owner and reviewer changes already in the worktree)

Keep exactly as they are now, never restore them from HEAD:

- config/credentials/*.yml.enc (secrets were removed or rotated on 2026-11-11)
- .devcontainer/**, compose files, .env* files
- docs/backlog/**, docs/runbooks/**, plans/**, evidence/**, adr/** (except where step 5 says)

## Steps

1. Read AGENTS.md and the rules it requires for config/routes/**, app/controllers/**, app/views/**,
   src/**, test/** and removals (generic/no-compatibility-layer.mdc, generic/routing.mdc,
   project/surfaces.mdc, generic/rails-concerns.mdc).
2. Recover: list every path deleted in the worktree that HEAD has (`git status --porcelain`, status
   D). Restore from HEAD every deleted path that belongs to core, warp or palm (routes, controllers,
   views, layouts, helpers, concerns, models, values, services, jobs, locales, src pages, features,
   entrypoints, styles, tests, gait features), plus every shared file those need to load and pass
   (concerns, layouts, src/components, src/styles, test support). Use
   `git restore --source=HEAD -- <path>` on explicit paths only; never restore the whole tree. Write
   the list of restored paths to the evidence record.
3. Restore README.md and AGENTS.md from HEAD, then edit README.md so it describes Sphere's own
   surfaces only (core, warp without com, palm, operator tools). Follow
   project/readme-authoring.mdc.
4. Remove FOREIGN surfaces as listed above: route files and blocks, controllers, views, helpers,
   concerns used only by them, locale keys used only by them, src pages and features, tests, boot
   configuration host entries, ENV readers for their URLs (and the variables in
   .env.container.devcontainer and .env templates — names only, never values), host lists in
   config/environments/development.rb. Remove all warp `.com` handling (warp_corporate host,
   app/controllers/warp/com, `*.com.localhost`, corporate URL readers) and close
   docs/backlog/2026-11-10-sphere-has-no-com.md with a note.
5. Then remove what becomes dead after step 4 (services, values, jobs, policies, adapters, concerns
   with no remaining caller); repeat until nothing new is dead. Do NOT delete models or migrations;
   instead report, per abstract *Record database, which models are still referenced from non-model
   code (USED / ONLY-VIA-MODELS / UNUSED).
6. Fix forward until these pass: bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle
   exec erb_lint --lint-all, bun run check, bin/rails test. List pre-existing failures separately
   from failures caused by this change.
7. Before finishing, check: `config/routes/` contains only core.rb, warp.rb, palm.rb and the
   operator tool files; `app/controllers/` contains only core, warp, palm, concerns and the shared
   top-level files; `bin/rails routes` lists no docs, edit, help, info, news, auth, visa, base,
   tech, guid or `.com` host.

## Report

Record in evidence/YYYY-MM-DD-sphere-surface-recovery-XXXX.md (full `git rev-parse HEAD`, note that
uncommitted changes affected results): restored paths, removed paths summary, routes per host, the
database/model report, check results, anything kept with a reason. No commit.
