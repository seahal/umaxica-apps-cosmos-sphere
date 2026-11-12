import { expect, test } from "vitest";

import SignOutCompleted from "@/features/auth/session/SignOutCompleted";
import SignOutConfirmation from "@/features/auth/session/SignOutConfirmation";
import SignOutUnavailable from "@/features/auth/session/SignOutUnavailable";
import SurfaceDashboard from "@/features/auth/SurfaceDashboard";
import WarpDashboard from "@/features/dashboards/WarpDashboard";
import WarpSettings from "@/features/dashboards/WarpSettings";
import RootLanding from "@/features/landing/RootLanding";

const pages = import.meta.glob<{ default: unknown }>("../../src/pages/**/*.tsx", { eager: true });

const expectedScreens = {
  "../../src/pages/core/app/roots/index.tsx": RootLanding,
  "../../src/pages/core/app/sign/outs/complete.tsx": SignOutCompleted,
  "../../src/pages/core/app/sign/outs/edit.tsx": SignOutConfirmation,
  "../../src/pages/core/app/sign/outs/unavailable.tsx": SignOutUnavailable,
  "../../src/pages/core/org/roots/index.tsx": RootLanding,
  "../../src/pages/core/org/sign/outs/complete.tsx": SignOutCompleted,
  "../../src/pages/core/org/sign/outs/edit.tsx": SignOutConfirmation,
  "../../src/pages/core/org/sign/outs/unavailable.tsx": SignOutUnavailable,
  "../../src/pages/palm/app/dashboards/show.tsx": SurfaceDashboard,
  "../../src/pages/palm/app/roots/index.tsx": RootLanding,
  "../../src/pages/palm/app/sign/out/completions/complete.tsx": SignOutCompleted,
  "../../src/pages/palm/app/sign/outs/complete.tsx": SignOutCompleted,
  "../../src/pages/palm/app/sign/outs/edit.tsx": SignOutConfirmation,
  "../../src/pages/palm/app/sign/outs/unavailable.tsx": SignOutUnavailable,
  "../../src/pages/warp/app/dashboards/show.tsx": WarpDashboard,
  "../../src/pages/warp/app/roots/index.tsx": RootLanding,
  "../../src/pages/warp/app/settings/show.tsx": WarpSettings,
  "../../src/pages/warp/app/sign/outs/complete.tsx": SignOutCompleted,
  "../../src/pages/warp/app/sign/outs/edit.tsx": SignOutConfirmation,
  "../../src/pages/warp/app/sign/outs/unavailable.tsx": SignOutUnavailable,
  "../../src/pages/warp/org/dashboards/show.tsx": WarpDashboard,
  "../../src/pages/warp/org/roots/index.tsx": RootLanding,
  "../../src/pages/warp/org/settings/show.tsx": WarpSettings,
  "../../src/pages/warp/org/sign/outs/complete.tsx": SignOutCompleted,
  "../../src/pages/warp/org/sign/outs/edit.tsx": SignOutConfirmation,
  "../../src/pages/warp/org/sign/outs/unavailable.tsx": SignOutUnavailable,
};

test("the page inventory contains only the established surface screens", () => {
  expect(Object.keys(pages).toSorted()).toEqual(Object.keys(expectedScreens).toSorted());
});

test.each(Object.entries(expectedScreens))(
  "surface-local page %s exports its established screen",
  (path, component) => {
    expect(pages[path]?.default).toBe(component);
  },
);
