# typed: false
# frozen_string_literal: true

# Edit sign-out completion is rendered in ERB.
#
# A signed-in session on the same origin may have left an authenticated page in browser history.
# `Clear-Site-Data: "storage"` drops the tab's
# sessionStorage (and localStorage, IndexedDB and service worker registrations) for this origin, so
# the history can no longer be restored without asking the server; `"cache"` drops the HTTP cache
# alongside it. A browser that does not support the header falls back to the existing controls:
# authenticated responses are `no-store` and every re-fetch is authenticated server-side.
#
# Include it only on a surface that registers no service worker it must keep: "storage" also
# unregisters service workers, and Edit registers none.
module SignOutClearSiteData
  CLEAR_SITE_DATA = '"cache", "storage"'

  private

  def render_oidc_rp_logout_completion
    response.set_header("Clear-Site-Data", CLEAR_SITE_DATA)
    super
  end
end
