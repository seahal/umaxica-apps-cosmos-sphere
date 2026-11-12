import { act, screen } from "@testing-library/react";
import { afterEach, describe, expect, test } from "vitest";

import {
  mountReactIslands,
  parseReactIslandProps,
  registerReactIslands,
} from "@/entrypoints/react_islands";

afterEach(async () => {
  await act(() => document.dispatchEvent(new Event("turbo:before-cache")));
  document.body.replaceChildren();
});

describe("public island property parser", () => {
  test.each([undefined, null, "", "malformed", "null", "[]", "true", "1", '"text"'])(
    "non-object %s carries no component properties",
    (raw) => {
      expect(parseReactIslandProps(raw)).toEqual({});
    },
  );

  test("object properties preserve their JSON values", () => {
    expect(
      parseReactIslandProps('{"label":"Preview","count":0,"enabled":false,"nested":{"id":1}}'),
    ).toEqual({ label: "Preview", count: 0, enabled: false, nested: { id: 1 } });
  });
});

test("Turbo mounts each recognized island once, ignores unknown names, and unmounts before caching", async () => {
  document.body.innerHTML =
    '<div data-react-component=""></div><div data-react-component="Unknown"></div><div data-react-component="UiGallery" data-react-props="{}"></div>';
  act(() => registerReactIslands());
  expect(screen.getAllByRole("heading", { name: "UI primitives" })).toHaveLength(1);
  const mountedHeading = screen.getByRole("heading", { name: "UI primitives" });
  act(() => {
    registerReactIslands();
    document.dispatchEvent(new Event("turbo:load"));
    mountReactIslands(document);
  });
  expect(screen.getByRole("heading", { name: "UI primitives" })).toBe(mountedHeading);
  expect(document.querySelector('[data-react-component="Unknown"]')?.childElementCount).toBe(0);
  await act(() => document.dispatchEvent(new Event("turbo:before-cache")));
  expect(screen.queryByRole("heading", { name: "UI primitives" })).toBeNull();
  await act(() => document.dispatchEvent(new Event("turbo:load")));
  expect(screen.getByRole("heading", { name: "UI primitives" })).toBeTruthy();
});
