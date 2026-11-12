# Remove non-Sphere databases

Date: 2026-11-12. Repository: umaxica-apps-cosmos-sphere. Branch: feature. HEAD:
`44dfa264c91c58121e48800c6f2680464914e8c4`.

## Scope and provenance

The working tree already contained 4,238 changed paths at intake. Results include that pre-existing
work. No reset, stash, commit, production/shared database mutation, or physical database drop was
performed. This report records local source retirement, not deletion of the owning services' data.
The owner's 2026-11-12 task and subsequent explicit permission authorize code-only retirement of
Chronicle's preference dependencies while preserving every retained table, column and historical
row.

All eight explicitly requested harness rules exist. Required matching repository guidance and the
retirement, security and specification Skills were read. The referenced Access ADR
`access-is-a-pure-openid-provider.md` is absent from this local repository; the supplied owner
decision and current Sphere source define this task's ownership. Other repositories were not
modified.

## Connection disposition

| Sphere connection/source                           | Disposition / authority                                         |
| -------------------------------------------------- | --------------------------------------------------------------- |
| primary                                            | KEEP; existing framework/operator tools                         |
| queue                                              | KEEP; Solid Queue unchanged                                     |
| storage                                            | KEEP; reserved storage database, schema unchanged               |
| chronicle                                          | KEEP; Sphere audit history, opaque historical owner identifiers |
| rp_core_app, rp_core_org                           | KEEP; Core local RP state                                       |
| rp_warp_app, rp_warp_org                           | KEEP; Warp local RP state                                       |
| rp_palm_app                                        | KEEP; Palm local RP state                                       |
| app_zenith, org_zenith                             | Remove Sphere connections/source; Governance owns accounts      |
| avatar                                             | Remove Sphere connections/source; Governance owns avatars       |
| app_setting, org_setting, com_setting              | Remove Sphere connections/source; Governance owns preferences   |
| app_signal, org_signal                             | Remove Sphere connections/source; Governance owns notifications |
| occurrence                                         | Remove Sphere connections/source; not owned by Sphere           |
| op_base_app, op_base_org                           | Remove Sphere connections/source; Access owns OP state          |
| publishing                                         | Remove Sphere connections/source; Press owns content            |
| search                                             | Remove unused reserved connection/source; no tables             |
| rp_base_app, rp_base_org, rp_tech_org, rp_edit_org | Remove Sphere connections/source; Governance / Press RP cells   |

Replicas follow their writer. Both environments now contain nine writers and seven replica
configurations (16 entries). Retiring these connection names does not declare the physical owner
service databases retired. No unconfirmed database was adopted into Sphere. The unconfigured
db/audit_schema.rb artifact is version zero and contains only an extension declaration, with no
tables. It was left unchanged and was not treated as an active database connection.

## Implementation

- Removed 730 abstract/concrete foreign model classes, their exclusive concerns, migrations, dumps,
  fixtures, tests, controllers, routes, operations, jobs, queries, resolvers, values and feature UI.
  Removed historical principal migration sources with the corresponding foreign implementation.
- Reduced database.yml, RP cell bindings, authenticator maps, Health profiles, CI database names and
  local test preparation environment lists. Removed scheduled foreign jobs; retained the original
  Solid Queue maintenance entry and Chronicle retention schedule.
- Seeds replay only retained Chronicle reference catalogs. Removed foreign preference, credential,
  anomaly and account lifecycle initializers and maintenance tasks.
- Existing local-cell OIDC/JWKS/PKCE authentication and refresh now run for the shared role too.
  Removed OP reads, Base-only step-up/logout branches and canonical account aliases. Removed the
  unused legacy policy DSL that referenced the retired Access policy and the obsolete callback
  authorization hook. CSRF, Origin, Fetch Metadata and local session/revocation checks remain
  exercised.
- Authenticated Core app profile responses and authenticated authorization-audit identity dependence
  explicitly return 503. Foreign preference/content/avatar/credential features are deleted.
- Chronicle keeps opaque actor/subject IDs and type labels. Removed foreign entity lookups and
  preference guards. The existing four Chronicle purge targets and hold/batch semantics remain;
  ComPreferenceChronicle was not added to that pre-existing purge allow-list.
- RP-local client metadata now names the existing five cell IDs, existing boot hosts and existing
  signing namespaces, with private_key_jwt. Removed foreign client-secret resolution/authentication
  and Base metadata. Access OP registration and encrypted credentials were not changed.
- Architecture debt inventories were regenerated to remove retired/resolved source entries; no new
  exclusion was added. Retired lifecycle/WebAuthn feature guards covered deleted
  carriers/ceremonies; config/ci.rb no longer names those deleted tests. Current CSRF and identity
  boundary guards remain.

### Retained schema proof

All 101 retained migration/dump files have identical SHA256 values before and after the task. The
temporary baseline manifest SHA256 is
`4506266bfbdf2cd196f50e510a79df06b971edd2a56578924437ce5031337f1f`. No retained schema migration was
added or rewritten. The initial development prepare applied 13 pre-existing pending migrations from
the earlier integrity work; their source hashes are unchanged. Test prepare had no pending
migrations. Final prepares both returned 0. An empty-database reconstruction was not repeated for
this retirement.

## Verification

Runtime commands used process-only `AUTH_JWT_ISSUER=auth-test-issuer`, the existing nonsecret
fixture issuer; the inherited shell otherwise lacked the required setting. No persisted default was
added. Test runs also used `RAILS_ENV=test PARALLEL_WORKERS=1` and the explicit reduced
`POSTGRESQL_TEST_PREPARE_DATABASES` value:

```text
test_primary_db,test_rp_core_app_db,test_rp_warp_app_db,test_rp_palm_app_db,test_rp_core_org_db,test_rp_warp_org_db,test_chronicle_db,test_queue_db,test_storage_db
```

The parent shell had exported the old list, overriding dotenv, so updating the checked-in local list
alone initially failed the existing safety check. The reduced explicit value retains that check.

| Command / check                                                        | Observed result                                                                                  |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| RAILS_ENV=development bin/rails db:prepare                             | exit 0                                                                                           |
| RAILS_ENV=test bin/rails db:prepare                                    | exit 0                                                                                           |
| bin/rubocop                                                            | exit 0; 728 files, no offenses                                                                   |
| bundle exec erb_lint --lint-all                                        | exit 0; 477 templates, no errors                                                                 |
| bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error         | exit 0; zero warnings/errors                                                                     |
| bin/rails test                                                         | 1,508 runs, 8,684 assertions, zero failures/errors/skips                                         |
| COVERAGE=true bin/rails test                                           | same passing 1,508 tests; exit 2 from coverage thresholds                                        |
| owned-cell/fail-closed/Health/ownership/CSRF guards (intermediate run) | 36 runs, 188 assertions, zero failures/errors/skips                                              |
| all surviving model tests (intermediate scoped run)                    | 366 runs, 2,659 assertions, zero failures/errors/skips                                           |
| retained purge/Chronicle/protocol tests (intermediate scoped run)      | 15 runs, 60 assertions, zero failures/errors/skips                                               |
| bun run test:coverage                                                  | 207 tests pass; exit 1 from unchanged 99% thresholds                                             |
| bun run check                                                          | exit 0; formatting, lint, source coverage of typecheck, TypeScript, Knip and OpenAPI checks pass |
| bun run openapi:lint                                                   | exit 0, one unused bearerToken warning                                                           |
| bun run openapi:verify                                                 | exit 0; all three bundles match isolated regeneration                                            |
| RAILS_ENV=test bundle exec database_consistency                        | exit 0; no configuration/exclusions supplied                                                     |
| direct DatabaseConsistency processor count                             | 1,079 reports, all :ok; 52 concrete application models                                           |
| git diff --check                                                       | exit 0                                                                                           |

DatabaseConsistency prints “No configuration files were provided” and still runs its processors. No
.database_consistency.yml was created, no checker was disabled and no process exit was discarded. No
Solid Queue warnings were reported; its internals remain outside the change. Blazer schemas were
unchanged. Checker results are model/schema inspection, not proof of live Access interoperability.
Real PostgreSQL tests additionally exercise retained audit insertion, opaque historical identifiers,
retention eligibility before/at/after the boundary, infinite retention and callback/session
contracts.

### Red and Green

Removal initially exposed foreign test dependencies, invalid historical fixture retention times and
missing pure protocol helpers. These failed before the corresponding fixes; opaque-history fixtures,
pure authorization-header/state helpers and exact existing OIDC prompt/max_age normalization were
then corrected without restoring OP database reads.

Before retirement, the narrow RP baseline already returned 56 runs / 171 assertions / 21 errors:
missing Core/Warp client registrations. After deletion, the full suite exposed the same missing
local client metadata and namespace prerequisite. Kept RP metadata was derived from RpCellBinding,
JitSecurityJwtRegistry's required namespaces, boot host configuration and the accepted 2026-11-10
hostname amendment. Existing sign-start, state signature and HTTP revocation tests then reached
Green. Warp's stale www-jp issuer expectation was updated to the accepted warp-jp hostname; the
standalone Palm test now explicitly loads its existing state assertion helper.

The new public request tests authenticate all five cells with real local records and signed tokens,
reject missing callback state before exchange, and assert explicit 503 for missing owner profile and
audit identity data. Related refresh, token binding, invalid cookie deletion and route absence tests
remain in the passing full suite.

### Limits and unresolved gates

- Ruby coverage: lines 87.87% (8,198/9,329), branches 55.91% (875/1,565), methods 74.23%
  (1,184/1,595); unchanged minima 98% / 93% / 97%. Coverage was measured, not declared successful.
- JS coverage: lines 86.07%, statements 86.19%, branches 87.36%, functions 88.18%; unchanged 99%
  gate fails. No full pre-task coverage baseline was captured, so change attribution is unproven.
- Knip's external Ruby consumer declaration now includes Playwright: the Capybara driver launches
  its CLI through PLAYWRIGHT_CLI_EXECUTABLE_PATH. The installed CLI reports 1.65.0. No dependency
  was removed and no DatabaseConsistency setting was changed. Knip now passes.
- The original OpenAPI verifier regenerated into the working tree and then used git diff, which
  rejected the pre-existing uncommitted bundles. The owner explicitly approved changing this
  verification method during continuation. package.json now calls scripts/verify_openapi_bundles.ts,
  which generates all three bundles in a temporary directory and compares their bytes with the
  current artifacts. The script is included in tsconfig.node.json and passes strict type checking,
  lint and explicit formatting. It succeeds on current artifacts and returns 1 for a deliberately
  stale app, com or org artifact in isolated disposable copies. OpenAPI source documents were not
  edited. Earlier verification regenerated already-dirty bundled artifacts; those working-tree
  results were preserved. The replacement leaves all current artifacts untouched. This scoped CI
  verification exception was explicitly approved.
- No real Access deployment/provider integration was performed. Local RP flows now work without OP
  tables; no unresolved OP read or retained-schema change is required by the implemented paths.
- No exhaustive standalone abstract-Record allow-list test existed. Existing Health allow-lists,
  primary ownership, migration-path guards, RP matrices and model/fixture ownership tests passed;
  source/config inventory separately verified the seven application-owned abstract Record classes.

## Remaining reference hits

Exact removed abstract Record names: zero in app/lib/config/db/test/src. Scanning all 730 removed
class names with word boundaries yields 44 textual hits, all listed below. Historical type strings
are values, never class resolution or cross-database associations.

| File and matching lines                                                      | Intentional meaning                                                                         |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `app/controllers/concerns/core_browser_api_boundary.rb`:50                   | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `app/controllers/concerns/oidc_callback.rb`:258                              | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `app/controllers/palm/app/roots_controller.rb`:27                            | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `app/models/account_access_event.rb`:46                                      | Retained historical account-type contract; schema unchanged.                                |
| `app/values/authentication_context_value.rb`:58                              | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `app/values/security_token_lifetimes.rb`:24                                  | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `config/application.rb`:110                                                  | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `config/initializers/session_store.rb`:4                                     | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `config/locales/en.yml`:47, 54, 82, 138, 209                                 | Shared Client ID / actor terminology labels, without model lookup.                          |
| `config/locales/ja.yml`:82                                                   | Shared Client ID / actor terminology labels, without model lookup.                          |
| `db/chronicle_migrate/20260614090000_create_account_access_events.rb`:29     | Retained historical account-type contract; schema unchanged.                                |
| `db/chronicle_structure.sql`:50                                              | Retained historical account-type contract; schema unchanged.                                |
| `src/inertia/surface.ts`:95                                                  | Generic client/operator terminology or boundary explanation; no removed constant reference. |
| `test/fixtures/app_preference_chronicles.yml`:41                             | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/fixtures/com_preference_chronicles.yml`:42                             | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/fixtures/org_preference_chronicles.yml`:42                             | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/account_access_event_test.rb`:37, 54                            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/app_preference_chronicle_test.rb`:11                            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/client_chronicle_event_uuid_consistency_test.rb`:11, 12, 34, 35 | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/client_chronicle_test.rb`:11, 16, 22, 27                        | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/com_preference_chronicle_test.rb`:11                            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/operator_chronicle_correlation_constraint_test.rb`:15           | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/operator_chronicle_expression_uniqueness_test.rb`:16            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/operator_chronicle_level_test.rb`:20                            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/operator_chronicle_sign_flow_halted_test.rb`:47                 | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/operator_chronicle_test.rb`:11, 16, 22, 27                      | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/models/org_preference_chronicle_test.rb`:11                            | Opaque historical type labels / JSON predicate regression coverage.                         |
| `test/security/invariants/recorder_sanitization_invariant_test.rb`:47        | User Agent test text; Agent is an English noun.                                             |
| `test/tooling/database_consistency_jsonb_uniqueness_test.rb`:121, 125        | Opaque historical type labels / JSON predicate regression coverage.                         |

Connection-word scan has 12 intentional matching lines: i18n-tasks `search` configuration, CSS
input[type=search], the cross-database-reference prohibition regex, two unchanged storage README
ownership references, EnforcementEvent's counter/audit explanation, two RFC problem-detail uses of
“occurrence-specific”, three cache-policy ADR filename citations, and the unchanged Blazer
configuration comment with retired database examples (Blazer remains out of scope). None configures
a removed connection. Substring matches such as warp_app_settings_path name the retained RP page,
not app_setting.

## Continuation closure

The final consumer audit removed two unreachable Edit/Tech-only branches from the shared OIDC
initiator/callback. OIDC client signing namespaces now contain only the existing five Sphere cells.
The regression test first failed because the shared process could sign for BASE_RP_APP_WW; after
removing unowned namespaces, all four removed cell namespaces are refused. Existing registry tests
now exercise Core instead of a retired Base RP. External Base/Access nodes in the Jump graph fixture
remain intentional peer topology, not local cells or database connections. The four foreign signing
namespace strings in oidc_state_jwt_test.rb are deliberate denial inputs.

A new five-cell browser round trip exercises real Rails CSRF, state, nonce, PKCE, ES384 ID Token
verification, PostgreSQL identity/session commits, cookie installation, target restoration and state
replay rejection. Only the external token endpoint and public key lookup are replaced at their
production seams. No OP/canonical model is loaded. The scoped signing/callback regression run passes
33 tests / 282 assertions. The final whole Rails suite passes 1,508 tests / 8,684 assertions.

All explicitly requested mandatory local commands now pass. Optional global coverage thresholds
remain unmet as quantified above; OpenAPI lint also retains its one unused bearerToken warning. No
warning-free whole-project coverage claim is made. All 101 retained schema/migration hashes remain
unchanged. The full HEAD and dirty-worktree caveat at the start still apply.

## Documentation handoff for Claude

No existing docs/ADR/checklist/diagram was rewritten. The following inventory contains documents
that describe retired features or reference the previous topology and require owner review; a match
alone does not mean every statement in that document is obsolete. In particular the database
inventory/disposition/integrity, preference, publishing, actor,
authentication/session/authorization, retention and IdP state-machine material now needs
reconciliation. The static-invariant rule still names the retired feature-specific guard files.

- `.agents/harnesses/rules/project/static-invariant-guards.mdc`
- `adr/README.md`
- `adr/api-collection-contract.md`
- `adr/api-collection-offset-pagination.md`
- `adr/api-error-format-problem-details.md`
- `adr/api-versioning-and-client-conventions.md`
- `adr/authority-lifecycle-table-policy.md`
- `adr/avatar-account-bridge-boundary.md`
- `adr/cosmos-base-surface-decomposition.md`
- `adr/cosmos-sphere-surfaces-and-rp-independence.md`
- `adr/database-trigger-usage-boundary.md`
- `adr/emergency-secret-credential-commit-acknowledgement.md`
- `adr/fakecloud-podman-staging-environment.md`
- `adr/global-and-publishing-default-no-store-policy.md`
- `adr/global-regional-database-ownership.md`
- `adr/news-is-timeline.md`
- `adr/openapi-bundle-outside-public.md`
- `adr/org-actor-operator-naming.md`
- `adr/org-entra-id-sign-in-boundary.md`
- `adr/owner-api-openapi-description-deferred.md`
- `adr/preference-soft-bubble-doctrine.md`
- `adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md`
- `adr/principal-zenith-physical-consolidation.md`
- `adr/publish-repository-importmap-boundary.md`
- `adr/publishing-db-content-authority.md`
- `adr/publishing-persistence-polymorphism-prohibition.md`
- `adr/publishing-taxonomy-architecture.md`
- `adr/publishing-twelve-family-encrypted-persistence.md`
- `adr/read-only-content-surfaces-in-rails.md`
- `adr/regional-docs-news-content-model.md`
- `adr/regional-help-surface-direction.md`
- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`
- `adr/runtime-secret-isolation-deferred.md`
- `adr/setting-preference-remove-polymorphic-owner.md`
- `adr/sign-up-flow-admission-binding-and-cardinality.md`
- `adr/staging-aurora-postgresql-topology.md`
- `adr/surface-database-connection-naming.md`
- `adr/unified-enforcement.md`
- `db/storages_migrate/README.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/avatar-account-bridge.md`
- `docs/architecture/content-surface-matrix.md`
- `docs/architecture/database-authority-placement.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/model-database-inventory.md`
- `docs/architecture/op-rp-ownership-manifest.md`
- `docs/architecture/persona-organization-authority.md`
- `docs/architecture/preference.md`
- `docs/architecture/principal-zenith-membership-organization-placement.md`
- `docs/architecture/publishing-persistence.md`
- `docs/architecture/regional-content.md`
- `docs/architecture/sns-subject-resource-grill.md`
- `docs/architecture/sphere-database-disposition.md`
- `docs/architecture/sphere-database-integrity.md`
- `docs/checklists/README.md`
- `docs/checklists/authentication-flow-integrity.md`
- `docs/checklists/authentication.md`
- `docs/checklists/authorization.md`
- `docs/checklists/avatar-ownership.md`
- `docs/checklists/browser-rp.md`
- `docs/checklists/contact-identifiers.md`
- `docs/checklists/email-observability.md`
- `docs/checklists/identifier-contracts.md`
- `docs/checklists/integrated-stack.md`
- `docs/checklists/jump-handoff.md`
- `docs/checklists/preference-lifecycle.md`
- `docs/checklists/session-management.md`
- `docs/checklists/sign-out.md`
- `docs/mermaid/README.md`
- `docs/mermaid/idp-op-client-activation.mmd`
- `docs/mermaid/idp-state-axis-classification.md`
- `docs/mermaid/idp-state-machine-candidate-disposition.md`
- `docs/mermaid/idp-state-machine-storage-overview.mmd`
- `docs/mermaid/idp-state-machine-storage-topology.md`
- `docs/mermaid/idp-state-machine-transition-inventory.md`
- `docs/mermaid/idp-state-value-coverage.md`
- `docs/reference/feature-flags.md`

OpenAPI documents also require Claude's review: preference paths remain documentation for retired
routes, while session/token-refresh documents must reflect the retained owner boundary and explicit
unavailable response. Their pre-existing working-tree changes and generated bundles are preserved.

- `openapi/app/paths/preferences-cookie.yml`
- `openapi/app/paths/preferences-theme.yml`
- `openapi/app/paths/session.yml`
- `openapi/app/paths/token-refresh.yml`
- `openapi/app.yml`
- `openapi/bundled/openapi.app.yml`
- `openapi/bundled/openapi.com.yml`
- `openapi/bundled/openapi.org.yml`
- `openapi/com/paths/preferences-cookie.yml`
- `openapi/com/paths/preferences-theme.yml`
- `openapi/com/paths/preferences-web-push.yml`
- `openapi/com.yml`
- `openapi/org/paths/preferences-cookie.yml`
- `openapi/org/paths/preferences-theme.yml`
- `openapi/org/paths/session.yml`
- `openapi/org/paths/token-refresh.yml`
- `openapi/org.yml`
- `openapi/shared/components.yml`
- `openapi/shared/paths/api-v0-health.yml`
- `openapi/shared/paths/api-v0-revision.yml`
