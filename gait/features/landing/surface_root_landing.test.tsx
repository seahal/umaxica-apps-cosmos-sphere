import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import RootLanding, { type RootLandingProps } from "@/features/landing/RootLanding";
import CoreAppRootsIndex from "@/pages/core/app/roots/index";
import CoreOrgRootsIndex from "@/pages/core/org/roots/index";
import PalmAppRootsIndex from "@/pages/palm/app/roots/index";
import WarpAppRootsIndex from "@/pages/warp/app/roots/index";
import WarpOrgRootsIndex from "@/pages/warp/org/roots/index";

const props: RootLandingProps = {
  title: null,
  heading: "Warp App",
  description: "Thin landing endpoint.",
};

describe("RootLanding extra destinations", () => {
  it("renders the RP sign-in action supplied by the surface", () => {
    const markup = renderToStaticMarkup(
      <RootLanding
        {...props}
        sign_in={{ label: "Sign in", action: "/sign/in/new", authenticity_token: "csrf-proof" }}
      />,
    );
    expect(markup).toContain('action="/sign/in/new"');
    expect(markup).toContain('value="csrf-proof"');
    expect(markup).toContain("Sign in");
  });

  it("renders the heading a surface without a page title of its own still shows", () => {
    const markup = renderToStaticMarkup(<RootLanding {...props} />);

    expect(markup).toContain("Warp App");
    expect(markup).toContain("Thin landing endpoint.");
  });

  it("renders no destinations when the surface offers none", () => {
    const markup = renderToStaticMarkup(<RootLanding {...props} />);

    expect(markup).not.toContain("<a href");
  });
});

describe("Core, Warp, and Palm root pages", () => {
  // Each surface resolves pages only from its own directory, so every surface needs its own module
  // for the shared landing.
  it.each([
    ["core/app", CoreAppRootsIndex],
    ["core/org", CoreOrgRootsIndex],
    ["warp/app", WarpAppRootsIndex],
    ["warp/org", WarpOrgRootsIndex],
    ["palm/app", PalmAppRootsIndex],
  ])("%s renders the shared landing", (_surface, Page) => {
    expect(Page).toBe(RootLanding);
  });
});
