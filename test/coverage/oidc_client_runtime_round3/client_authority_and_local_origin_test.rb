# frozen_string_literal: true

require "test_helper"

class ClientAuthorityAndLocalOriginTest < ActiveSupport::TestCase
  test "an RP process requires only its own client assertion signing authority" do
    checked_ids = []
    key_provider =
      lambda do |id|
        checked_ids << id
        nil
      end
    RuntimeRole.stub(:current, "rp-core-app-jp") do
      JitSecurityJwtRegistry.stub(:private_key_for, key_provider) do
        error =
          assert_raises(OidcClientRegistry::ClientAuthenticationConfigurationError) do
            OidcClientRegistry.validate_private_key_jwt_configuration!
          end
        assert_includes error.message, "core-app-jp(CORE_APP_JP)"
        assert_not_includes error.message, "warp-app-jp"
      end
      assert OidcClientRegistry.validate_private_key_jwt_configuration!
    end
    assert_equal ["oidc_client:CORE_APP_JP"], checked_ids
  end

  test "a shared process reports every unavailable registered signer without accepting another cell key" do
    checked_ids = []
    key_provider =
      lambda do |id|
        checked_ids << id
        nil
      end
    RuntimeRole.stub(:current, "shared") do
      JitSecurityJwtRegistry.stub(:private_key_for, key_provider) do
        error =
          assert_raises(OidcClientRegistry::ClientAuthenticationConfigurationError) do
            OidcClientRegistry.validate_private_key_jwt_configuration!
          end
        OidcClientRegistry.client_ids.each do |id|
          assert_includes error.message, id
        end
      end
    end

    assert_equal OidcClientRegistry.client_ids.map { |id|
      "oidc_client:#{OidcClientRegistry.find!(id).jwt_namespace}"
    }.sort, checked_ids.sort
  end

  test "client authentication classifications keep public clients distinct from private key clients" do
    original = OidcClientRegistry.find!("core-app-jp")
    public_client = original.with(registered_token_endpoint_auth_method: "none")

    assert_predicate public_client, :public_client?
    assert_not public_client.confidential_client?
    assert_not public_client.private_key_jwt_client?
    secret_client = original.with(registered_token_endpoint_auth_method: "client_secret_basic")

    assert_predicate secret_client, :confidential_client?
    assert_not secret_client.public_client?
    assert_not secret_client.private_key_jwt_client?
    assert_predicate original, :private_key_jwt_client?
  end

  test "private-key configuration validation does not require a signer for a public client" do
    registered = OidcClientRegistry.find!("core-app-jp")
    public_client = registered.class.new(
      **registered.to_h.merge(registered_token_endpoint_auth_method: "none"),
    )

    RuntimeRole.stub(:current, "shared") do
      OidcClientRegistry.stub(:client_ids, [public_client.client_id]) do
        OidcClientRegistry.stub(:find, public_client) do
          JitSecurityJwtRegistry.stub(:private_key_for, ->(*) { flunk("public clients have no signer") }) do
            assert OidcClientRegistry.validate_private_key_jwt_configuration!
          end
        end
      end
    end
  end

  test "client lookup and static destinations consume a valid loopback origin without promoting it to public TLS" do
    config = Rails.configuration.x.boot_config
    localhost = ConfigValues.build("http://localhost", allow_localhost: true)
    local_config = config.merge(hosts: config.fetch(:hosts).with(core_service: localhost))
    Rails.configuration.x.stub(:boot_config, local_config) do
      client = OidcClientRegistry.find!("core-app-jp")

      assert_equal ["http://localhost:3000/oidc/callback"], client.redirect_uris
      assert_equal ["localhost"], client.domains
      assert_equal "http://localhost:3000/oidc/closures",
                   OidcClientStoresStaticClientStore.backchannel_logout_uri("core-app-jp")
      assert_equal RequestContextContract.allowed_regions.map { |region|
        "http://localhost:3000/sign/out/completion?ri=#{region}"
      }, client.post_logout_redirect_uris
      assert OidcClientRegistry.valid_redirect_uri?("core-app-jp", client.redirect_uris.first, resource_type: "client")
      assert_not OidcClientRegistry.valid_redirect_uri?(
        "core-app-jp", "http://localhost:3001/oidc/callback",
        resource_type: "client",
      )
    end
    assert_not_equal ["localhost"], OidcClientRegistry.find!("core-app-jp").domains
  end

  test "issuer host components normalize optional values while unsupported resources remain explicit" do
    assert_equal "", OidcIssuer.host_component(nil)
    assert_equal "", OidcIssuer.host_component(" ")
    assert_equal "visa.example.com", OidcIssuer.host_component("https://visa.example.com/")
    assert_equal "visa.example.com", OidcIssuer.host_component("//visa.example.com")
    [nil, "", "visitor"].each do |resource|
      assert_raises(ArgumentError) { OidcIssuer.host_for_resource_type(resource) }
      assert_raises(ArgumentError) { OidcIssuer.jwt_issuer_id_for_resource_type(resource) }
    end
  end
  test "concurrent client lookups publish one metadata snapshot for a new origin signature" do
    config = Rails.configuration.x.boot_config
    loopback = ConfigValues.build("http://coverage.localhost", allow_localhost: true)
    local_config = config.merge(hosts: config.fetch(:hosts).with(core_service: loopback))
    started = Queue.new
    release = Queue.new
    builds = 0
    first = nil
    second = nil
    Rails.configuration.x.stub(:boot_config, local_config) do
      registered = OidcClientStoresStaticClientStore.clients
      provider =
        lambda do
          builds += 1
          started << true
          release.pop
          registered
        end
      OidcClientStoresStaticClientStore.stub(:clients, provider) do
        begin
          first = Thread.new { OidcClientRegistry.find!("core-app-jp") }
          Timeout.timeout(2) { started.pop }
          second = Thread.new { OidcClientRegistry.find!("core-app-jp") }
          Timeout.timeout(2) { Thread.pass until second.status == "sleep" }
          release << true
          first_result = first.value
          second_result = second.value

          assert_equal ["http://coverage.localhost:3000/oidc/callback"], first_result.redirect_uris
          assert_equal first_result, second_result
          assert_equal 1, builds
        ensure
          release << true
          first&.kill if first&.alive?
          second&.kill if second&.alive?
        end
      end
    end
  end

  test "logout return registration never crosses a realm and rejects unsupported realm names" do
    client = OidcClientRegistry.find!("core-app-jp")
    target = client.post_logout_redirect_uris.first

    assert OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id, uri: target,
      resource_type: "client",
    )
    assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id, uri: target,
      resource_type: "operator",
    )
    [nil, "", "visitor"].each do |resource|
      assert_raises(ArgumentError) do
        OidcClientRegistry.valid_post_logout_redirect_uri?(
          client_id: client.client_id, uri: target,
          resource_type: resource,
        )
      end
    end
    [nil, "", "unknown-client"].each do |client_id|
      assert_nil OidcClientRegistry.find(client_id)
      assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
        client_id: client_id, uri: target,
        resource_type: "client",
      )
    end
  end
end
