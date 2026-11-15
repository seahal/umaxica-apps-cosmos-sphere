# frozen_string_literal: true

require "test_helper"

class OidcRegistryAndMcpPublicContractTest < ActiveSupport::TestCase
  test "registered RP clients expose their own callbacks logout destinations and issuer endpoints" do
    assert_equal %w(core-app-jp core-org-jp palm-app-jp warp-app-jp warp-org-jp), OidcClientRegistry.client_ids.sort
    OidcClientRegistry.client_ids.each do |id|
      client = OidcClientRegistry.find!(id)

      assert_predicate client, :confidential_client?
      assert_predicate client, :private_key_jwt_client?
      assert_not client.public_client?
      assert OidcClientRegistry.valid_redirect_uri?(id, client.redirect_uris.first, resource_type: client.resource_type)
      assert OidcClientRegistry.valid_post_logout_redirect_uri?(
        client_id: id,
        uri: client.post_logout_redirect_uris.first, resource_type: client.resource_type,
      )
      assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
        client_id: id,
        uri: "https://unregistered.example/sign/out/completion", resource_type: client.resource_type,
      )
      assert_equal client.jwt_namespace, OidcClientRegistry.jwt_namespace_for(id)
      issuer = OidcIssuer.for_client(client)

      assert_equal "#{issuer}/oauth/authorize", OidcIssuer.authorization_endpoint(client.resource_type)
      assert_equal "#{issuer}/oauth/token", OidcIssuer.token_endpoint(client.resource_type)
      assert_equal "#{issuer}/oauth/userinfo", OidcIssuer.userinfo_endpoint(client.resource_type)
      assert_equal "#{issuer}/oauth/revoke", OidcIssuer.revocation_endpoint(client.resource_type)
      assert_equal "#{issuer}/oidc/logout", OidcIssuer.end_session_endpoint(client.resource_type)
      assert_equal "#{issuer}/.well-known/jwks.json", OidcIssuer.jwks_uri(client.resource_type)
      assert_equal OidcIssuer.host_for_resource_type(client.resource_type), OidcIssuer.host_for_client(client)
      assert_equal OidcIssuer.jwt_issuer_id_for_resource_type(client.resource_type),
                   OidcIssuer.jwt_issuer_id_for_client(client)
      backchannel = URI.parse(OidcClientStoresStaticClientStore.backchannel_logout_uri(id))

      assert_equal "/oidc/closures", backchannel.path
      assert_includes client.domains, backchannel.host
    end
    assert_nil OidcClientRegistry.find("unregistered")
    assert_nil OidcClientRegistry.jwt_namespace_for("unregistered")
    assert_raises(OidcClientRegistry::ClientNotFound) { OidcClientRegistry.find!("unregistered") }
    assert_raises(KeyError) { OidcClientStoresStaticClientStore.backchannel_logout_uri("unregistered") }
    assert_raises(ArgumentError) { OidcIssuer.for_resource_type("unknown") }
    assert_raises(ArgumentError) { OidcIssuer.host_for_resource_type("unknown") }
    assert_raises(ArgumentError) { OidcIssuer.jwt_issuer_id_for_resource_type("unknown") }
    assert_equal OidcIssuer.for_resource_type("operator"), OidcIssuer.for_resource_type("staff")
    assert_equal "https://example.com", OidcIssuer.absolute_url(" https://example.com/ ")
    assert_equal "http://localhost:3000", OidcIssuer.absolute_url("localhost")
    assert_equal "http://localhost:4000", OidcIssuer.absolute_url("localhost:4000")
  end

  test "client assertions sign the local RP subject and optional step up expectation" do
    expectation = OidcClientAssertionStepUpExpectationValue.new(grant: "grant", subject: "opaque-subject")
    now = Time.current.change(usec: 0)
    token = OidcClientAssertionJwt.issue(
      client_id: "core-app-jp", token_url: "https://visa.umaxica.app/oauth/token",
      now: now, jti: "assertion-id", step_up_expectation: expectation,
    )

    assert_predicate token, :present?
    payload, header = JWT.decode(token, nil, false)

    assert_equal "core-app-jp", payload["iss"]
    assert_equal "core-app-jp", payload["sub"]
    assert_equal "grant", payload["step_up_grant"]
    assert_equal "opaque-subject", payload["step_up_sub"]
    assert_equal now.to_i + 300, payload["exp"]
    assert_equal "oidc-client-assertion+jwt", header["typ"]
    assert_equal "PS256", header["alg"]
    assert_equal header, JitSecurityJwtRegistry.parse_header(token)
    assert_empty JitSecurityJwtRegistry.parse_header("malformed")
    issuer = JitSecurityJwtRegistry.oidc_client("CORE_APP_JP")

    assert_equal issuer.public_key_for(header["kid"]), JitSecurityJwtRegistry.public_key_for(issuer.id, header["kid"])
    assert_equal issuer.jwks, JitSecurityJwtRegistry.jwks_for(issuer.id)
    assert_nil JitSecurityJwtRegistry.private_key_for(issuer.id, "missing-key")
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.issuer("unknown") }
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.surface("unknown") }
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.oidc_client("unknown") }
    assert_nil OidcClientAssertionJwt.issue(
      client_id: "unregistered",
      token_url: "https://visa.umaxica.app/oauth/token",
    )
    assert_raises(ArgumentError) {
      OidcClientAssertionJwt.issue(
        client_id: "core-app-jp",
        token_url: "https://visa.umaxica.app/oauth/token",
        step_up_expectation: Object.new,
      )
    }
  end

  test "MCP tools require an explicit surface and disclose identity or liveness only" do
    identity = McpSurfaceIdentity.new(realm: "warp", surface: "app")
    response = McpServiceInfoTool.call(server_context: { surface_identity: identity })

    assert_equal({ "realm" => "warp", "surface" => "app" }, JSON.parse(response.content.fetch(0).fetch(:text)))
    response = McpLivenessTool.call(server_context: { surface_identity: identity })

    assert_equal({ "status" => "ok" }, JSON.parse(response.content.fetch(0).fetch(:text)))
    assert_raises(KeyError) { McpServiceInfoTool.call(server_context: {}) }
    assert_raises(KeyError) { McpLivenessTool.call(server_context: {}) }
  end
end
