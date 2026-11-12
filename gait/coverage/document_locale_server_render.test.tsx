import { renderToStaticMarkup } from "react-dom/server";
import { expect, test, vi } from "vitest";

import DocumentLocale from "@/components/ui/DocumentLocale";

test("a server render without a browser document preserves the localized content", () => {
  vi.stubGlobal("document", undefined);
  try {
    expect(
      renderToStaticMarkup(
        <DocumentLocale>
          <p>Server content</p>
        </DocumentLocale>,
      ),
    ).toContain("Server content");
  } finally {
    vi.unstubAllGlobals();
  }
});
