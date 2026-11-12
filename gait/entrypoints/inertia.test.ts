import { createInertiaApp } from "@inertiajs/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageResolver,
} from "@/inertia/surface";

import { present } from "../support/present";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.reject(new Error("test inertia error"))),
  // The entrypoint globs every page of its surface, and the features behind them navigate.
  router: { on: vi.fn(() => () => {}) },
}));

// `createInertiaApp`'s real declaration is a three-overload union keyed on `render`/`setup`, so
// the mock records its argument as the union. Narrowing it with a guard rather than an assertion
// means a change to what an entrypoint actually passes fails here instead of being asserted onto.
type SurfaceInertiaConfig = {
  resolve: (name: string) => { default: { layout?: unknown } };
  strictMode: boolean;
  defaults: typeof surfaceInertiaDefaults;
};

function isSurfaceInertiaConfig(value: unknown): value is SurfaceInertiaConfig {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  return (
    typeof Reflect.get(value, "resolve") === "function" &&
    typeof Reflect.get(value, "strictMode") === "boolean" &&
    typeof Reflect.get(value, "defaults") === "object"
  );
}

/** The options an entrypoint handed `createInertiaApp`, or a failure naming what it handed. */
function capturedConfig(value: unknown): SurfaceInertiaConfig {
  if (!isSurfaceInertiaConfig(value)) {
    throw new Error(`The entrypoint passed createInertiaApp something else: ${String(value)}`);
  }

  return value;
}

type PageModuleFixture = { default: { (): null; layout?: unknown } };

function pageModules(surface: string, names: string[]): Record<string, PageModuleFixture> {
  return Object.fromEntries(
    names.map((name) => [`../../pages/${surface}/${name}.tsx`, { default: () => null }]),
  );
}

const LAYOUT = () => null;

const own = () => null;

describe("surface page resolver", () => {
  test("resolves a page of its own surface from the surface-scoped glob", () => {
    const resolve = surfacePageResolver(
      pageModules("core/app", ["groups/index"]),
      "core/app",
      LAYOUT,
    );

    expect(resolve("core/app/groups/index")).toBeDefined();
  });

  test("attaches the surface layout so no page can render without chrome", () => {
    const resolve = surfacePageResolver(
      pageModules("core/app", ["groups/index"]),
      "core/app",
      LAYOUT,
    );

    expect(resolve("core/app/groups/index").default.layout).toEqual([LAYOUT]);
  });

  test("keeps a layout a page declared for itself", () => {
    const modules = pageModules("core/app", ["groups/index"]);
    present(
      modules["../../pages/core/app/groups/index.tsx"],
      "the globbed groups/index page module",
    ).default.layout = [own];
    const resolve = surfacePageResolver(modules, "core/app", LAYOUT);

    expect(resolve("core/app/groups/index").default.layout).toEqual([own]);
  });

  test("rejects a page belonging to another surface instead of attempting to resolve it", () => {
    const resolve = surfacePageResolver(
      pageModules("core/app", ["groups/index"]),
      "core/app",
      LAYOUT,
    );

    expect(() => resolve("warp/app/groups/index")).toThrow(
      /does not belong to the "core\/app" surface/u,
    );
  });

  test("rejects an unqualified page name so a missing prefix is not silently accepted", () => {
    const resolve = surfacePageResolver(
      pageModules("warp/org", ["groups/index"]),
      "warp/org",
      LAYOUT,
    );

    expect(() => resolve("groups/index")).toThrow(/does not belong to the "warp\/org" surface/u);
  });

  test("rejects a globbed file that is not a page module", () => {
    expect(() =>
      surfacePageResolver(
        { "../../pages/core/app/groups/index.tsx": { named: true } },
        "core/app",
        LAYOUT,
      ),
    ).toThrow(/has no default export/u);
  });

  test("fails loudly when the surface has no component for a page the controller rendered", () => {
    const resolve = surfacePageResolver(
      pageModules("core/app", ["groups/index"]),
      "core/app",
      LAYOUT,
    );

    expect(() => resolve("core/app/groups/show")).toThrow(
      /has no component in src\/pages\/core\/app/u,
    );
  });
});

describe("surface inertia defaults", () => {
  test("visits use bracket array syntax so Rack parses array parameters", () => {
    expect(surfaceInertiaDefaults.visitOptions()).toEqual({ queryStringArrayFormat: "brackets" });
  });
});

describe("reportInertiaBootFailure", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("rethrows the original error when the Inertia root element is present", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const error = new Error("boot failed for an unrelated reason");

    expect(() => reportInertiaBootFailure(error)).toThrow(error);
  });
});

const ENTRYPOINT_IMPORT_TIMEOUT_MS = 30_000;

describe("surface inertia entrypoint", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test(
    "logs a configuration error when loaded from a layout without the Inertia root element",
    async () => {
      document.body.innerHTML = "";
      const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

      await import("../../src/entrypoints/inertia/core_app.tsx");
      await Promise.resolve();

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining("Missing Inertia root element"),
      );
      errorSpy.mockRestore();
    },
    ENTRYPOINT_IMPORT_TIMEOUT_MS,
  );
});

describe.each([
  ["palm/app", "../../src/entrypoints/inertia/palm_app.tsx"],
  ["warp/app", "../../src/entrypoints/inertia/warp_app.tsx"],
  ["warp/org", "../../src/entrypoints/inertia/warp_org.tsx"],
  ["core/app", "../../src/entrypoints/inertia/core_app.tsx"],
  ["core/org", "../../src/entrypoints/inertia/core_org.tsx"],
])("%s inertia entrypoint", (surface, modulePath) => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test(
    "wires createInertiaApp to a resolver scoped to its own surface",
    async () => {
      await import(modulePath);
      await Promise.resolve();

      expect(createInertiaApp).toHaveBeenCalledTimes(1);

      const config = capturedConfig(vi.mocked(createInertiaApp).mock.calls[0]?.[0]);

      expect(config.strictMode).toBe(true);
      expect(config.defaults.visitOptions()).toEqual(surfaceInertiaDefaults.visitOptions());
      // The resolver is built for this surface only, so another surface's page is refused.
      expect(() => config.resolve("other/surface/groups/index")).toThrow(
        new RegExp(`does not belong to the "${surface}" surface`, "u"),
      );
    },
    ENTRYPOINT_IMPORT_TIMEOUT_MS,
  );
});
