# frozen_string_literal: true

require "test_helper"

class OidcAssertionRecoveryContractTest < ActiveSupport::TestCase
  test "a local assertion retries once after the key provider repairs available material" do
    calls = 0
    installations = 0
    reloads = 0
    records = JitSecurityJwtRegistry.issuers
    encode =
      lambda do |payload, **options|
        calls += 1
        raise JitSecurityJwtRegistry::ConfigurationError, "key provider unavailable" if calls == 1

        assert_equal "core-app-jp", payload.fetch("iss")
        assert_equal "oidc_client:CORE_APP_JP", options.fetch(:issuer_id)
        "issued-by-repaired-key-provider"
      end
    JitSecurityJwtKeyring.stub(:encode, encode) do
      JitSecurityJwtLocalKeysetInstaller.stub(:install!, -> { installations += 1 }) do
        JitSecurityJwtRegistry.stub(
          :reload!, -> {
                      reloads += 1
                      records
                    },
        ) do
          token = OidcClientAssertionJwt.issue(
            client_id: "core-app-jp",
            token_url: "https://visa.umaxica.app/oauth/token",
          )

          assert_equal "issued-by-repaired-key-provider", token
        end
      end
    end

    assert_equal 2, calls
    assert_equal 1, installations
    assert_equal 1, reloads
  end

  test "a second key provider failure returns no assertion instead of looping" do
    calls = 0
    records = JitSecurityJwtRegistry.issuers
    encode =
      lambda do |*|
        calls += 1
        raise JitSecurityJwtRegistry::ConfigurationError, "key provider unavailable"
      end
    JitSecurityJwtKeyring.stub(:encode, encode) do
      JitSecurityJwtLocalKeysetInstaller.stub(:install!, true) do
        JitSecurityJwtRegistry.stub(:reload!, records) do
          assert_nil OidcClientAssertionJwt.issue(
            client_id: "core-app-jp",
            token_url: "https://visa.umaxica.app/oauth/token",
          )
        end
      end
    end

    assert_equal 2, calls
  end

  test "unavailable local private material prevents retrying the key provider" do
    calls = 0
    records = JitSecurityJwtRegistry.issuers
    encode =
      lambda do |*|
        calls += 1
        raise JitSecurityJwtRegistry::ConfigurationError, "key provider unavailable"
      end
    JitSecurityJwtKeyring.stub(:encode, encode) do
      JitSecurityJwtLocalKeysetInstaller.stub(:install!, true) do
        JitSecurityJwtRegistry.stub(:reload!, records) do
          JitSecurityJwtRegistry.stub(:private_key_for, nil) do
            assert_nil OidcClientAssertionJwt.issue(
              client_id: "core-app-jp",
              token_url: "https://visa.umaxica.app/oauth/token",
            )
          end
        end
      end
    end

    assert_equal 1, calls
  end

  test "production assertion failures never invoke the local development key installer" do
    installer = Minitest::Mock.new
    JitSecurityJwtKeyring.stub(:encode, ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "missing key" }) do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        JitSecurityJwtLocalKeysetInstaller.stub(:install!, -> { installer.install! }) do
          assert_nil OidcClientAssertionJwt.issue(
            client_id: "core-app-jp",
            token_url: "https://visa.umaxica.app/oauth/token",
          )
        end
      end
    end
    installer.verify
  end
end
