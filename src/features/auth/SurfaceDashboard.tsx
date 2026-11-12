import Card from "@/components/ui/Card";
import Page, { type PageUpLink } from "@/components/ui/Page";
// The signed-in landing of an auth surface.
//
// It is a directory of the ceremonies the surface owns. Every entry arrives resolved from the
// server: an item with a href is a link the visitor may follow, an item without one is a note about
// a ceremony that has no direct entry point.
export type DashboardItem = {
  label: string;
  href: string | null;
};

export type DashboardGroup = {
  heading: string;
  items: DashboardItem[];
};

export type DashboardSection = {
  heading: string;
  items?: DashboardItem[];
  groups?: DashboardGroup[];
};

export type SurfaceDashboardProps = {
  title: string;
  description?: string;
  sections: DashboardSection[];
  /** Absent on the dashboard itself; identity and similar screens send the parent dashboard. */
  up_link?: PageUpLink | null;
};

function linkList(items: DashboardItem[]) {
  return (
    <ul className="flex flex-col gap-1">
      {items.map((item) => (
        <li
          key={item.label}
          className="text-base"
        >
          {item.href ? (
            <a
              href={item.href}
              className="ui-text-link text-fg underline underline-offset-4 hover:underline"
            >
              {item.label}
            </a>
          ) : (
            <span className="text-fg-muted">{item.label}</span>
          )}
        </li>
      ))}
    </ul>
  );
}

export default function SurfaceDashboard({
  title,
  description,
  sections,
  up_link: upLink = null,
}: SurfaceDashboardProps) {
  return (
    <Page
      title={title}
      {...(description ? { description } : {})}
      up={upLink}
      upVisit="inertia"
    >
      {sections.map((section) => (
        <Card
          key={section.heading}
          heading={section.heading}
        >
          {section.groups?.map((group) => (
            <div
              key={group.heading}
              className="flex flex-col gap-1"
            >
              <h3 className="text-base font-medium text-fg">{group.heading}</h3>
              {linkList(group.items)}
            </div>
          ))}
          {section.items && section.items.length > 0 ? linkList(section.items) : null}
        </Card>
      ))}
    </Page>
  );
}
