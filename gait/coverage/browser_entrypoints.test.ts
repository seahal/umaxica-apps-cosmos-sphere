import { expect, test, vi } from "vitest";

const boundaries = vi.hoisted(() => ({
  registerIslands: vi.fn(),
  registerOffline: vi.fn(() => Promise.resolve()),
}));

vi.mock("@hotwired/turbo-rails", () => ({}));
vi.mock("@/controllers", () => ({}));
vi.mock("@/entrypoints/react_islands", () => ({
  registerReactIslands: boundaries.registerIslands,
}));
vi.mock("@/pwa/register", () => ({ registerOfflineServiceWorker: boundaries.registerOffline }));

test("application and developer entrypoints register the island lifecycle once", async () => {
  await import("@/entrypoints/application");
  await import("@/entrypoints/core/dev");
  expect(boundaries.registerIslands).toHaveBeenCalledTimes(1);
});

test("each standalone RP entrypoint requests the offline worker for its own document", async () => {
  await import("@/entrypoints/palm/app");
  await import("@/entrypoints/warp/app");
  await import("@/entrypoints/warp/org");
  expect(boundaries.registerOffline).toHaveBeenCalledTimes(3);
});
