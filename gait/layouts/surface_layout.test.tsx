import { router } from "@inertiajs/react";
import { render as renderTree, screen, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import type { SurfaceChrome } from "@/types/inertia";

// The layout renders only what SurfaceChrome assembled on the server, so the page object is the
// single input. The chrome components have their own specs; here they are replaced by markers so
// the layout's own structure is what is asserted.
//
// The assertions query by role and accessible name rather than by markup. The layout's contract is
// its document structure — landmarks, headings, lists and link targets — and that has to survive
// the styling it carries, which exact-markup assertions did not.
vi.mock("@inertiajs/react", () => ({
  usePage: () => page,
  router: { clearHistory: vi.fn() },
}));

const { default: SurfaceLayout } = await import("@/layouts/SurfaceLayout");

const minimalChrome: SurfaceChrome = {
  family_label: null,
  surface: "app",
  brand: { name: "Umaxica", href: "https://umaxica.app/" },
  restricted_mode: null,
  account_navigation: null,
  copyright: "(c) Umaxica",
};

const page: {
  props: { chrome: SurfaceChrome; clear_history?: boolean; errors: Record<string, string> };
} = {
  props: { chrome: minimalChrome, errors: {} },
};

const render = (chrome: SurfaceChrome) => {
  page.props.chrome = chrome;
  return renderTree(
    <SurfaceLayout>
      <p>page body</p>
    </SurfaceLayout>,
  );
};

beforeEach(() => {
  vi.mocked(router.clearHistory).mockClear();
  document.head.insertAdjacentHTML(
    "beforeend",
    '<meta name="ui-footer" content="Footer navigation"><meta name="ui-information" content="Information">',
  );
});
afterEach(() => {
  page.props.chrome = minimalChrome;
  delete page.props.clear_history;
  document.documentElement.lang = "en";
  document
    .querySelectorAll('meta[name="ui-footer"], meta[name="ui-information"]')
    .forEach((meta) => meta.remove());
});

describe("SurfaceLayout", () => {
  test("app page metadata does not change the document language", () => {
    document.documentElement.lang = "ja";
    render({ ...minimalChrome, locale: "en" });

    expect(document.documentElement.lang).toBe("ja");
  });

  test("shows a signed-out relying party the way into sign-in in the header", () => {
    render({
      ...minimalChrome,
      account_navigation: {
        label: "Account",
        signed_in: false,
        links: [{ label: "Sign in", href: "/sign?ri=jp" }],
      },
    });

    const account = within(screen.getByRole("banner")).getByRole("navigation", { name: "Account" });
    expect(within(account).getByRole("link", { name: "Sign in" }).getAttribute("href")).toBe(
      "/sign?ri=jp",
    );
    expect(within(account).getAllByRole("link")).toHaveLength(1);
  });

  test("shows a signed-in relying party the way to Base and to sign out in the header", () => {
    render({
      ...minimalChrome,
      account_navigation: {
        label: "Account",
        signed_in: true,
        links: [
          { label: "Go to BASE", href: "https://www.umaxica.app/dashboard?ri=jp" },
          { label: "Sign out", href: "/sign/out/new?ri=jp" },
        ],
      },
    });

    const account = within(screen.getByRole("banner")).getByRole("navigation", { name: "Account" });
    expect(
      within(account)
        .getAllByRole("link")
        .map((link) => [link.textContent, link.getAttribute("href")]),
    ).toEqual([
      ["Go to BASE", "https://www.umaxica.app/dashboard?ri=jp"],
      ["Sign out", "/sign/out/new?ri=jp"],
    ]);
  });

  test("renders no account navigation where the server sent none", () => {
    render(minimalChrome);

    expect(
      within(screen.getByRole("banner")).queryByRole("navigation", { name: "Account" }),
    ).toBeNull();
  });

  test("renders the page inside the main landmark", () => {
    render(minimalChrome);

    const main = screen.getByRole("main");
    expect(main.id).toBe("main");
    expect(within(main).getByText("page body")).toBeTruthy();
  });

  test("clears encrypted history when the server marks a terminal ceremony page", () => {
    page.props.clear_history = true;

    render(minimalChrome);

    expect(router.clearHistory).toHaveBeenCalledTimes(1);
  });

  test("renders the brand, surface and copyright the server resolved", () => {
    const { container } = render(minimalChrome);

    expect(screen.getByRole("link", { name: "Umaxica" }).getAttribute("href")).toBe(
      "https://umaxica.app/",
    );
    expect(container.textContent).toContain("(app)");
    expect(container.textContent).toContain("(c) Umaxica");
  });

  test("renders the family label only when the surface carries one", () => {
    expect(render(minimalChrome).container.textContent).not.toContain("Base");
    expect(render({ ...minimalChrome, family_label: "Base" }).container.textContent).toContain(
      "Base",
    );
  });

  test("omits the banner and footer navigation when absent", () => {
    render(minimalChrome);

    expect(screen.queryByRole("region", { name: "Information" })).toBeNull();
    expect(screen.queryByRole("navigation", { name: "Footer navigation" })).toBeNull();
    // The surface layout carries no primary/header navigation at all.
    expect(screen.queryByRole("navigation", { name: "Primary" })).toBeNull();
  });

  // Restricted Mode is session state, published once by the server and rendered here for the whole
  // life of the session. A page cannot supply it and therefore cannot drop it.
  test("renders no restricted mode indicator for an ordinary session", () => {
    render(minimalChrome);

    expect(screen.queryByRole("region", { name: "制限モード — Emergency Access" })).toBeNull();
  });

  test("renders the restricted mode indicator above everything else in the header", () => {
    render({
      ...minimalChrome,
      restricted_mode: {
        label: "制限モード — Emergency Access",
        description: "段階的認証は利用できません。",
        sign_out: { label: "サインアウトして通常モードでサインインし直す", href: "/sign/out/new" },
      },
    });

    const indicator = screen.getByRole("region", { name: "制限モード — Emergency Access" });
    expect(within(indicator).getByText("段階的認証は利用できません。")).toBeTruthy();

    // The only way back to a normal session is to end this one; there is no in-place switch.
    const signOut = within(indicator).getByRole("link", {
      name: "サインアウトして通常モードでサインインし直す",
    });
    expect(signOut.getAttribute("href")).toBe("/sign/out/new");
    expect(indicator.textContent).not.toContain("解除");
  });
});
