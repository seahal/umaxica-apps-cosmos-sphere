# frozen_string_literal: true

# The single trusted execution role of this process (docs/security/role-secret-isolation.md).
#
# A role decides which controllers this process serves and which private signing keys it requires.
# It is read once from the process environment at boot and is never derived from request input
# (Host, `ri`, token claims). An unknown role aborts boot.
#
# A role does not select credentials or a database login: every process reads the Rails-standard
# config/credentials/<env>.yml.enc and the same database.yml (user decision 2026-10-19,
# adr/runtime-secret-isolation-deferred.md).
module RuntimeRole
  # `shared` serves retained operator mounts in development.
  SHARED = "shared"

  # Core, Warp and Palm keep their own relying-party process boundaries.
  RP_ROLES = %w(
    rp-core-app-jp rp-core-org-jp
    rp-warp-app-jp rp-warp-org-jp
    rp-palm-app-jp
  ).freeze

  ALL = ([SHARED] + RP_ROLES).freeze

  class UnknownRole < ArgumentError; end

  module_function

  # Required: a process without an explicit role must not boot (no silent default to `shared`).
  def current
    name = ENV.fetch("UMAXICA_RUNTIME_ROLE")
    raise UnknownRole, "unknown runtime role: #{name.inspect}" unless ALL.include?(name)

    name
  end

  def shared?(name = current)
    name == SHARED
  end

  # The cell store connection of an RP role, e.g. rp-core-app-jp -> rp_core_app.
  def cell_connection(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    name.delete_prefix("rp-").split("-").first(2).unshift("rp").join("_")
  end

  # An RP process holds its own client assertion and Jump RT keys; it never holds an OP signer.
  def rp_private_env_names(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    family, realm, region = name.delete_prefix("rp-").split("-")
    client_namespace = "#{family}_#{realm}_#{region}"
    surface_namespace = "#{family}_#{realm}"
    [
      "OIDC_CLIENT_#{client_namespace.upcase}_PRIVATE_KEY",
      "JWT_#{surface_namespace.upcase}_PRIVATE_KEY",
    ].freeze
  end

  BROWSER_ADMISSION_STATES = %w(open closed).freeze
  # RP cells keep health and their back-channel logout receiver available while closed.
  CLOSED_CELL_PATHS = %r{/(oidc/closures|health|healths|revisions)\z}

  def rp_browser_admission_open?
    state = ENV.fetch("UMAXICA_RP_BROWSER_ADMISSION")
    raise UnknownRole, "UMAXICA_RP_BROWSER_ADMISSION must be open or closed" unless
      BROWSER_ADMISSION_STATES.include?(state)

    state == "open"
  end

  class UnownedRoute < ArgumentError; end

  # Unknown-host responses disclose no application state and can be served by any role.
  ANY_ROLE = "*"
  # Rails controllers in the retained operator tools run in the shared application process. Rack
  # mounts that do not use Action Controller remain governed by their own mount middleware.
  SHARED_CONTROLLER_PREFIXES = %w(
    mission_control/jobs
    blazer
    pg_hero
    rswag/api
    rswag/ui
  ).freeze
  # Every application-owned controller must have an owner. An unclassified controller is refused.
  def route_owner(controller_path)
    path = controller_path.to_s
    return ANY_ROLE if path == "unknown_hosts"
    return SHARED if SHARED_CONTROLLER_PREFIXES.any? { |prefix| path.start_with?("#{prefix}/") }
    return SHARED if %w(core/dev core/net warp/dev warp/net).any? { |prefix| path.start_with?("#{prefix}/") }
    return "rp-core-app-jp" if path.start_with?("core/app/")
    return "rp-core-org-jp" if path.start_with?("core/org/")
    return "rp-warp-app-jp" if path.start_with?("warp/app/")
    return "rp-warp-org-jp" if path.start_with?("warp/org/")
    return "rp-palm-app-jp" if path.start_with?("palm/app/")

    raise UnownedRoute, "no runtime role owns #{path.inspect}"
  end

  # True when this process may serve the controller; the shared process serves every retained tool.
  def serves?(controller_path, name = current)
    owner = route_owner(controller_path)
    return true if owner == ANY_ROLE
    return true if shared?(name)
    return false unless owner == name
    return true unless RP_ROLES.include?(name)

    rp_browser_admission_open? || CLOSED_CELL_PATHS.match?(controller_path)
  rescue UnownedRoute
    false
  end
end
