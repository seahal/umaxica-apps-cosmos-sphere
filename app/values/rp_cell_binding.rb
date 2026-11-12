# typed: false
# frozen_string_literal: true

# Fixed process-to-cell bindings for R5. A request may carry a client identifier, but it never
# selects the database connection; callers resolve this value from trusted boot configuration.
class RpCellBinding
  Cell = Data.define(:connection, :client_id, :realm, :region, :record_prefix)

  CELLS = {
    "rp_core_app" => Cell.new(
      connection: "rp_core_app", client_id: "core-app-jp", realm: "app", region: "jp",
      record_prefix: "RpCoreApp",
    ),
    "rp_warp_app" => Cell.new(
      connection: "rp_warp_app", client_id: "warp-app-jp", realm: "app", region: "jp",
      record_prefix: "RpWarpApp",
    ),
    "rp_palm_app" => Cell.new(
      connection: "rp_palm_app", client_id: "palm-app-jp", realm: "app", region: "jp",
      record_prefix: "RpPalmApp",
    ),
    "rp_core_org" => Cell.new(
      connection: "rp_core_org", client_id: "core-org-jp", realm: "org", region: "jp",
      record_prefix: "RpCoreOrg",
    ),
    "rp_warp_org" => Cell.new(
      connection: "rp_warp_org", client_id: "warp-org-jp", realm: "org", region: "jp",
      record_prefix: "RpWarpOrg",
    ),
  }.freeze

  class UnknownCell < KeyError; end

  class << self
    public

    def fetch(connection)
      CELLS.fetch(connection.to_s) { raise UnknownCell, "unknown RP cell connection: #{connection.inspect}" }
    end

    def for_client(client_id)
      cell = CELLS.values.find { |candidate| candidate.client_id == client_id.to_s }
      return cell if cell

      raise UnknownCell, "unknown RP client binding: #{client_id.inspect}"
    end

    def connections
      CELLS.keys
    end
  end
end
