# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  # The Rails-side Jump contract is a reviewable data table. `issuer_namespace` is the signing
  # identity, `destination_namespace` is the origin named by the signed URL, and `purpose` explains
  # why the edge exists. Origins are resolved only through JumpRtSurface; host spelling never
  # changes the graph.
  EDGE_CATALOG = [
    %w(BASE_APP VISA_APP authorization_start),
    %w(BASE_ORG VISA_ORG authorization_start),
    %w(VISA_APP BASE_APP authorization_response),
    %w(VISA_ORG BASE_ORG authorization_response),
  ].map do |issuer_namespace, destination_namespace, purpose|
    {
      issuer_namespace: issuer_namespace,
      destination_namespace: destination_namespace,
      purpose: purpose,
    }.freeze
  end.freeze

  # Frozen directed graph derived from the table above. Keep this projection because the runtime
  # verifier needs only the pair, while the catalog remains available to audits and handoffs.
  ALLOWED_EDGES = EDGE_CATALOG.map do |edge|
    [edge.fetch(:issuer_namespace), edge.fetch(:destination_namespace)].freeze
  end.freeze

  def allowed_source?(destination_origin:, source:)
    destination = namespace_for_origin(normalize_origin(destination_origin))
    source_namespace = namespace_for_origin(normalize_origin(source))
    return false if destination.nil? || source_namespace.nil?

    ALLOWED_EDGES.include?([source_namespace, destination])
  end

  # Configured origins must be pairwise distinct; an ambiguous identity is a configuration error,
  # not a reason to pick one namespace.
  def namespace_for_origin(origin)
    return nil if origin.nil?

    matches = JumpRtSurface::ISSUER_NAMESPACES.select { |namespace| JumpRtSurface.issuer_origin(namespace) == origin }
    raise JumpRtConfigurationError,
          "Jump issuer origin #{origin} is configured for #{matches.join(", ")}" if matches.size > 1

    matches.first
  end

  def normalize_origin(value)
    uri = URI.parse(value.to_s)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless %w(http https).include?(uri.scheme)
    return nil if uri.host.blank?
    return nil if uri.userinfo.present?
    return nil unless uri.path.empty? && uri.query.nil? && uri.fragment.nil?

    port = (uri.port && uri.port != default_port_for(uri.scheme)) ? ":#{uri.port}" : ""
    "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  def default_port_for(scheme)
    scheme.to_s.casecmp("https").zero? ? 443 : 80
  end
end
