# UI view inventory

Updated 2026-11-11 for the retained Sphere browser surfaces: Core, Warp without `com`, Palm, and the
separately mounted operator tools. Rails owns each surface's application and Inertia shell; React
pages are registered in surface-local entrypoints. Operator tool pages are supplied by their mounted
engines.

## React/Inertia pages

| Surface  | Entry point                            | Page modules                                                                                                                         |
| -------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Core app | `src/entrypoints/inertia/core_app.tsx` | `src/pages/core/app/roots/index.tsx`; `src/pages/core/app/sign/outs/{edit,complete,unavailable}.tsx`                                 |
| Core org | `src/entrypoints/inertia/core_org.tsx` | `src/pages/core/org/roots/index.tsx`; `src/pages/core/org/sign/outs/{edit,complete,unavailable}.tsx`                                 |
| Warp app | `src/entrypoints/inertia/warp_app.tsx` | `src/pages/warp/app/{roots/index,dashboards/show,settings/show}.tsx`; `src/pages/warp/app/sign/outs/{edit,complete,unavailable}.tsx` |
| Warp org | `src/entrypoints/inertia/warp_org.tsx` | `src/pages/warp/org/{roots/index,dashboards/show,settings/show}.tsx`; `src/pages/warp/org/sign/outs/{edit,complete,unavailable}.tsx` |
| Palm app | `src/entrypoints/inertia/palm_app.tsx` | `src/pages/palm/app/{roots/index,dashboards/show}.tsx`; `src/pages/palm/app/sign/outs/{edit,complete,unavailable}.tsx`               |

## Rails-rendered views and layouts

- Core developer landing: `app/views/core/dev/roots/index.html.erb`.
- Core app and org shells: `app/views/layouts/core/{app,org}/{application,inertia}.html.erb`.
- Warp app and org shells: `app/views/layouts/warp/{app,org}/{application,inertia}.html.erb`.
- Palm app shell: `app/views/layouts/palm/app/{application,inertia}.html.erb`.
- Warp and Palm sitemap responses use their surface-owned XML builder templates.

Keep view modules, entrypoints, layouts, and controller ownership within each surface. Shared React
components may be used through existing imports without sharing surface state or authority.
