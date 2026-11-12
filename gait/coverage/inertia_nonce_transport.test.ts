import { createInertiaApp } from "@inertiajs/react";
import { afterEach, expect, test, vi } from "vitest";

import { bootSurfaceInertiaApp } from "@/inertia/surface";

vi.mock("@inertiajs/react", () => ({ createInertiaApp: vi.fn(() => Promise.resolve()) }));

afterEach(() => {
  document.querySelector('meta[property="csp-nonce"]')?.remove();
});

test("an empty nonce attribute is omitted from the Inertia bootstrap contract", async () => {
  const meta = document.createElement("meta");
  meta.setAttribute("property", "csp-nonce");
  meta.nonce = "";
  document.head.append(meta);
  await bootSurfaceInertiaApp({}, "core/app");
  expect(vi.mocked(createInertiaApp).mock.lastCall?.[0]).not.toHaveProperty("nonce");
});

test("the response nonce reaches the Inertia bootstrap for its runtime style elements", async () => {
  const meta = document.createElement("meta");
  meta.setAttribute("property", "csp-nonce");
  meta.nonce = "response-style-nonce";
  document.head.append(meta);
  await bootSurfaceInertiaApp({}, "core/app");
  expect(createInertiaApp).toHaveBeenCalledWith(
    expect.objectContaining({ nonce: "response-style-nonce" }),
  );
});
