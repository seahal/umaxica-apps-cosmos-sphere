import { render, screen, within } from "@testing-library/react";
import { describe, expect, test } from "vitest";

import Card from "@/components/ui/Card";
import Table from "@/components/ui/Table";
import SignOutConfirmation from "@/features/auth/session/SignOutConfirmation";
import SurfaceDashboard from "@/features/auth/SurfaceDashboard";
import RootLanding from "@/features/landing/RootLanding";

const landing = { title: null, heading: "Core", description: "RP entry" };

describe("RP landing destinations", () => {
  test("a document destination remains a navigable link", () => {
    render(
      <RootLanding
        {...landing}
        sign_in={{ label: "Continue", href: "/sign/in" }}
      />,
    );
    expect(screen.getByRole("link", { name: "Continue" }).getAttribute("href")).toBe("/sign/in");
  });

  test("a fully specified sign-in action carries intent and CSRF without query leakage", () => {
    const { container } = render(
      <RootLanding
        {...landing}
        sign_in={{
          label: "Continue",
          action: "/sign/in",
          method: "post",
          intent: "login",
          authenticity_token: "csrf-proof",
        }}
      />,
    );
    expect(container.querySelector("form")?.getAttribute("method")).toBe("post");
    expect(container.querySelector('input[name="intent"]')?.getAttribute("value")).toBe("login");
    expect(container.querySelector('input[name="authenticity_token"]')?.getAttribute("value")).toBe(
      "csrf-proof",
    );
  });

  test("an action without optional fields renders neither hidden value", () => {
    const { container } = render(
      <RootLanding
        {...landing}
        sign_in={{ label: "Continue", action: "/sign/in" }}
      />,
    );
    expect(screen.getByRole("button", { name: "Continue" })).toBeTruthy();
    expect(container.querySelectorAll("input")).toHaveLength(0);
  });
});

describe("local RP dashboard", () => {
  test("groups and standalone items preserve links and unavailable ceremony labels", () => {
    render(
      <SurfaceDashboard
        title="Dashboard"
        description="Local state"
        up_link={{ label: "Home", href: "/" }}
        sections={[
          {
            heading: "Sessions",
            groups: [
              {
                heading: "Current",
                items: [
                  { label: "Inspect", href: "/sessions" },
                  { label: "No direct action", href: null },
                ],
              },
            ],
            items: [{ label: "End session", href: "/sign/out" }],
          },
          { heading: "No actions", items: [] },
          { heading: "No entries" },
        ]}
      />,
    );
    expect(screen.getByRole("heading", { name: "Dashboard" })).toBeTruthy();
    expect(screen.getByText("Local state")).toBeTruthy();
    expect(screen.getByRole("heading", { name: "Current" })).toBeTruthy();
    expect(screen.getByRole("link", { name: "Inspect" }).getAttribute("href")).toBe("/sessions");
    expect(screen.getByText("No direct action").tagName).toBe("SPAN");
    expect(screen.getByRole("link", { name: "End session" }).getAttribute("href")).toBe(
      "/sign/out",
    );
    expect(screen.getByRole("link", { name: "Home" })).toBeTruthy();
  });

  test("a dashboard without optional prose or navigation renders its title", () => {
    render(
      <SurfaceDashboard
        title="Local dashboard"
        sections={[]}
      />,
    );
    expect(screen.getByRole("heading", { name: "Local dashboard" })).toBeTruthy();
    expect(screen.queryByRole("link")).toBeNull();
  });
});

test("an action-only card carries its control without an empty heading", () => {
  render(<Card actions={<button type="button">Inspect</button>}>Body</Card>);
  expect(screen.getByRole("button", { name: "Inspect" })).toBeTruthy();
  expect(screen.queryByRole("heading")).toBeNull();
});

test("a named dense table retains its scroll region and real table semantics", () => {
  render(
    <Table
      label="Sessions"
      density="dense"
    >
      <tbody>
        <tr>
          <td>Current</td>
        </tr>
      </tbody>
    </Table>,
  );
  const region = screen.getByRole("region", { name: "Sessions" });
  expect(within(region).getByRole("table", { name: "Sessions" }).className).toContain("text-sm");
  expect(region.getAttribute("tabindex")).toBe("0");
});

test("active sign-out without a cancellation action renders only the authorized submission", () => {
  const { container } = render(
    <SignOutConfirmation
      title="Sign out"
      heading="End session"
      active_context
      confirm_description="Confirm"
      already_signed_out="Already ended"
      submit_label="End"
      form={{ action: "/sign/out" }}
      cancel={null}
      home_link={{ label: "Home", href: "/" }}
    />,
  );
  expect(container.querySelectorAll("form")).toHaveLength(1);
  expect(screen.getByRole("button", { name: "End" })).toBeTruthy();
  expect(container.querySelector('input[name="_method"]')).toBeNull();
});

test("a plain card contains only its content without an invented header", () => {
  const { container } = render(<Card>Unheaded content</Card>);
  expect(screen.getByText("Unheaded content")).toBeTruthy();
  expect(screen.queryByRole("heading")).toBeNull();
  expect(container.querySelector("section")).toBeNull();
});
