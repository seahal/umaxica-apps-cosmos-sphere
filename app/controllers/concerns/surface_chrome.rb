# typed: false
# frozen_string_literal: true

# Builds the shared Inertia props that the React surface layout renders as page chrome.
#
# Before the Inertia migration this data was read straight out of the ERB layout by helpers
# (`current_banner_for`, `t(...)`, `*_url`). A React layout cannot reach any of that, so the chrome
# becomes a serialized prop shared by every Inertia response of the surface. Everything that is a
# server responsibility stays here: translation, route generation, the banner query, and the
# decision about which navigation a visitor is allowed to see.
#
# The shared payload is per surface by construction: each including controller declares its own
# family, surface and banner domain, and `inertia_share` runs in that controller's instance, so one
# surface can never publish another surface's chrome.
module SurfaceChrome
  extend ActiveSupport::Concern

  # Query parameters that carry preference context across hosts. The cookie settings link has to
  # forward them or the destination loses the visitor's region and display preferences.
  PREFERENCE_QUERY_KEYS = %w(ri lx ct tz cu df tf mo dn ps).freeze

  # Sphere owns these families; authority surfaces are separate applications.
  FAMILY_CHROME = {
    "core" => { family_label: "CORE" },
    "warp" => { family_label: "WARP" },
    "palm" => { family_label: "PALM" },
  }.freeze

  # Relying-party surfaces whose header shows the visitor's sign-in state (see
  # chrome_account_navigation).
  ACCOUNT_NAVIGATION_SURFACES = [
    %w(core app), %w(core org), %w(warp app), %w(warp org), %w(palm app),
  ].freeze

  # Controller namespaces under a relying-party surface (`<family>/<surface>/<namespace>/...`) that
  # are the sign-in/sign-out procedure itself; their pages show no account navigation.
  ACCOUNT_PROCEDURE_NAMESPACES = %w(sign sign_outs oidc).freeze

  # The operational surfaces are mounted with a route prefix that does not match their controller
  # module, so route helpers cannot be composed from the module name alone.
  SURFACE_ROUTE_NAMES = { "dev" => "developer", "net" => "network" }.freeze

  private

  def chrome_configuration
    @chrome_configuration ||=
      begin
        family, surface = controller_path.to_s.split("/").first(2)
        defaults =
          FAMILY_CHROME.fetch(family) do
            raise ArgumentError,
                  "#{self.class.name} renders Inertia pages from an unknown family #{family.inspect}; " \
                  "add its chrome to SurfaceChrome::FAMILY_CHROME rather than rendering chromeless pages"
          end

        defaults.merge(family: family, surface: surface).freeze
      end
  end

  def surface_chrome
    configuration = chrome_configuration

    {
      family_label: configuration.fetch(:family_label),
      surface: configuration.fetch(:surface),
      brand: chrome_brand,
      restricted_mode: chrome_restricted_mode,
      account_navigation: chrome_account_navigation,
      copyright: chrome_copyright,
    }
  end

  # Restricted Mode (Emergency Access) is a property of the session, not of a
  # page, so it is published once here and rendered by the persistent layout.
  # No screen can omit the indicator, because no screen supplies it: a page that
  # forgets about Emergency Access still renders inside the same chrome.
  #
  # The decision comes from the session row the request authenticated against --
  # the same authority that mints the `authn_ctx` claim -- never from a request
  # parameter, a cookie the browser can write, or page state.
  #
  # Hiding navigation is not authorization. The banner and the trimmed
  # navigation are there so the operator understands what they are looking at;
  # the server denies the unavailable operations regardless
  # (docs/security/org-emergency-access.md).
  def chrome_restricted_mode
    return nil unless chrome_authentication_context.standby?

    scope = "layouts.shared.restricted_mode"
    {
      label: chrome_t("#{scope}.label"),
      description: chrome_t("#{scope}.description"),
      sign_out: {
        label: chrome_t("#{scope}.sign_out"),
        href: chrome_url(
          "new_#{chrome_configuration.fetch(:family)}_#{chrome_route_surface}_sign_out_path",
          { ri: RequestContextContract.normalize_region(params[:ri]) },
        ),
      },
    }
  end

  # A surface with no authenticated session, and a surface whose sessions cannot
  # carry a context at all, are both Normal by construction rather than by a
  # lookup that could be made to answer otherwise.
  def chrome_authentication_context
    return AuthenticationContextValue.normal unless chrome_logged_in?

    AuthenticationContextValue.from_claims(@current_access_token_payload)
  end

  def chrome_brand
    family = chrome_configuration.fetch(:family)
    destination = (family == "warp" && chrome_logged_in?) ? "dashboard" : "root"
    {
      name: ENV.fetch("BRAND_NAME"),
      href: chrome_url("#{family}_#{chrome_route_surface}_#{destination}_path"),
    }
  end

  def chrome_route_surface
    SURFACE_ROUTE_NAMES.fetch(chrome_configuration.fetch(:surface)) { chrome_configuration.fetch(:surface) }
  end

  # Preferences are displayed from verified state. The authority application owns writes.
  # The relying-party surfaces show the visitor where they stand, in one of three states:
  #   - signed out: a way into the sign-up/sign-in entry (which hands off to the OP);
  #   - signed in: the way to Base and to sign out;
  #   - nothing: on the sign-in, sign-out and OIDC callback pages themselves, which are the
  #     procedure the links would start, so offering it again there only invites a restart.
  # Core dev/net do not render this account navigation because they have no sign-in boundary.
  def chrome_account_navigation
    family = chrome_configuration.fetch(:family)
    surface = chrome_configuration.fetch(:surface)
    return nil unless ACCOUNT_NAVIGATION_SURFACES.include?([family, surface])
    return nil if ACCOUNT_PROCEDURE_NAMESPACES.include?(controller_path.split("/").third)

    # Carry the visitor's region and display context the same way the cookie settings link does;
    # not every controller that renders this chrome resolves a region identifier of its own.
    region = request.query_parameters.slice(*PREFERENCE_QUERY_KEYS).symbolize_keys
    if chrome_logged_in?
      {
        label: chrome_t("layouts.shared.account_navigation.label"),
        signed_in: true,
        links: [
          {
            label: chrome_t("layouts.shared.account_navigation.base"),
            href: chrome_account_base_url(surface, region),
          },
          {
            label: chrome_t("layouts.shared.account_navigation.sign_out"),
            href: chrome_account_sign_out_path(family, surface, region),
          },
        ].compact,
      }
    else
      {
        label: chrome_t("layouts.shared.account_navigation.label"),
        signed_in: false,
        links: [
          {
            label: chrome_t("layouts.shared.account_navigation.sign_up_or_in"),
            href: chrome_account_sign_in_path(family, surface, region),
          },
        ],
      }
    end
  end

  def chrome_account_sign_in_path(family, surface, options)
    case [family, surface]
    when %w(core app) then core_app_sign_show_path(options)
    when %w(core org) then core_org_sign_show_path(options)
    when %w(warp app) then warp_app_sign_show_path(options)
    when %w(warp org) then warp_org_sign_show_path(options)
    when %w(palm app) then palm_app_sign_show_path(options)
    else raise ArgumentError, "no sign-in entry for #{family}/#{surface}"
    end
  end

  def chrome_account_sign_out_path(family, surface, options)
    case [family, surface]
    when %w(core app) then new_core_app_sign_out_path(options)
    when %w(core org) then new_core_org_sign_out_path(options)
    when %w(warp app) then new_warp_app_sign_out_path(options)
    when %w(warp org) then new_warp_org_sign_out_path(options)
    when %w(palm app) then new_palm_app_sign_out_path(options)
    else raise ArgumentError, "no sign-out entry for #{family}/#{surface}"
    end
  end

  def chrome_account_base_url(surface, options)
    case surface
    when "app" then chrome_authority_dashboard_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL"), options)
    when "org" then chrome_authority_dashboard_url(ENV.fetch("PUBLIC_BASE_STAFF_URL"), options)
    else raise ArgumentError, "no Base destination for surface #{surface.inspect}"
    end
  end

  # Base is an external application, so its URL cannot depend on Sphere's route helpers.
  def chrome_authority_dashboard_url(host, options)
    URI::HTTPS.build(host: host, path: "/dashboard", query: options.to_query.presence).to_s
  end

  def chrome_copyright
    "© #{Time.zone.today.year} #{ENV.fetch("BRAND_NAME")}"
  end

  def chrome_logged_in?
    respond_to?(:logged_in?, true) && logged_in?
  end

  # Keys are composed from the surface, so they cannot be literals at the call site; passing the
  # composed key through here keeps every translation lookup in one place.
  def chrome_t(key, **)
    t(key, **)
  end

  def chrome_url(helper, options = nil)
    options.present? ? public_send(helper, options) : public_send(helper)
  end
end
