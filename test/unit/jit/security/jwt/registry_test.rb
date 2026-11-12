# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_registry"

module Jit
  module Security
    module Jwt
      class RegistryTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          @auth_key = OpenSSL::PKey::EC.generate("secp384r1")
          @auth_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_app_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_app_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_org_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_org_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @surface_key = OpenSSL::PKey::EC.generate("secp384r1")
        end

        teardown do
          JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
        end

        test "loads configured keys once into immutable issuer records" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!

            assert_equal "auth-kid", issuers.fetch("auth").current_kid
            assert_equal %w(umaxica-api-client umaxica-api-operator),
                         issuers.fetch("auth").audiences
            assert_equal "pref-app-kid", issuers.fetch("preference_app").current_kid
            assert_equal ["app"], issuers.fetch("preference_app").audiences
            assert_equal "pref-org-kid", issuers.fetch("preference_org").current_kid
            assert_equal ["org"], issuers.fetch("preference_org").audiences
            assert_equal "jump-core-app-kid", issuers.fetch("surface:CORE_APP").current_kid
            assert_predicate issuers.fetch("surface:CORE_APP").jwks.fetch(:keys), :present?
            assert_equal JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.size,
                         issuers.keys.grep(/\Aoidc_client:/).size
            assert JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference_app", "pref-app-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference_org", "pref-org-legacy-kid")
          end
        end

        test "loads configured Core OIDC client assertion issuer" do
          with_registry_inputs(
            "OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID" => "oidc-core-app-kid",
            "OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY" => base64_der(@surface_key),
          ) do
            issuers = JitSecurityJwtRegistry.reload!
            issuer = issuers.fetch("oidc_client:CORE_APP_JP")

            assert_equal "oidc-core-app-kid", issuer.current_kid
            assert_equal "oidc_client:core_app_jp", issuer.issuer
            assert_predicate issuer.jwks.fetch(:keys), :present?
          end
        end

        test "grace public key verifies old tokens without retaining old private key" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            token = JWT.encode(
              {
                "iss" => "issuer",
                "aud" => "audience",
                "sub" => "subject",
                "exp" => 5.minutes.from_now.to_i,
                "iat" => Time.current.to_i,
              },
              @auth_legacy_key,
              JitSecurityJwtRegistry::ALGORITHM,
              { kid: "auth-legacy-kid", typ: "auth-access-token;client" },
            )

            public_key = JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")

            assert_nil JitSecurityJwtRegistry.private_key_for("auth", "auth-legacy-kid")
            assert_not_nil public_key
            assert_nothing_raised do
              JWT.decode(token, public_key, true, algorithms: [JitSecurityJwtRegistry::ALGORITHM])
            end
          end
        end

        test "jwks never exposes private key material" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            JitSecurityJwtRegistry.jwks_for("auth").fetch(:keys).each do |jwk|
              assert_empty JitSecurityJwtRegistry::PRIVATE_JWK_FIELDS & jwk.keys
              assert_equal JitSecurityJwtRegistry::ALGORITHM, jwk.fetch("alg")
              assert_equal "sig", jwk.fetch("use")
              assert_equal "EC", jwk.fetch("kty")
              assert_equal JitSecurityJwtRegistry::CURVE, jwk.fetch("crv")
            end
          end
        end

        test "rejects malformed public jwk json at registry load" do
          with_registry_inputs("JWT_CORE_APP_PUBLIC_KEYSET" => "not-json") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/surface:CORE_APP public JWKS contains invalid JSON/, error.message)
          end
        end

        test "rejects current public jwk that does not match current private key" do
          wrong_key = OpenSSL::PKey::EC.generate("secp384r1")
          wrong_jwk = JitSecurityJwtRegistry.export_public_jwk(wrong_key, kid: "jump-core-app-kid")

          with_registry_inputs("JWT_CORE_APP_PUBLIC_KEYSET" => JSON.generate([wrong_jwk])) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active public JWK does not match active private key/, error.message)
          end
        end

        test "does not expose revoked kids in jwks and refuses their public keys" do
          with_registry_inputs("JWT_CORE_APP_REVOKED_KIDS" => "legacy-kid") do
            JitSecurityJwtRegistry.reload!

            assert_nil JitSecurityJwtRegistry.public_key_for("surface:CORE_APP", "legacy-kid")
            kids = JitSecurityJwtRegistry.jwks_for("surface:CORE_APP").fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_not_includes kids, "legacy-kid"
          end
        end

        test "rejects duplicate non-default kids across issuers" do
          with_registry_inputs("PREFERENCE_APP_JWT_ACTIVE_KID" => "auth-kid") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/duplicate JWT kid/, error.message)
          end
        end

        test "RP registry requires only its own OIDC client signing material" do
          with_registry_inputs(
            "OIDC_CLIENT_WARP_APP_JP_PRIVATE_KEY" => nil,
            "OIDC_CLIENT_WARP_APP_JP_PUBLIC_KEYSET" => JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(@surface_key, kid: "warp-app-kid")],
            ),
          ) do
            RuntimeRole.stub(:current, "rp-core-app-jp") do
              issuers = JitSecurityJwtRegistry.reload!

              assert_equal "core-app-kid", issuers.fetch("oidc_client:CORE_APP_JP").current_kid
              warp_key = issuers.fetch("oidc_client:WARP_APP_JP").keys.fetch("warp-app-kid")

              assert_nil warp_key.private_key
              assert_predicate warp_key.public_key, :present?
            end
          end

          [
            ["OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID", nil, "OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID"],
            ["OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY", nil, "OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY"],
          ].each do |name, value, missing_name|
            with_registry_inputs(name => value) do
              RuntimeRole.stub(:current, "rp-core-app-jp") do
                error =
                  assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                    JitSecurityJwtRegistry.reload!
                  end

                assert_includes error.message, missing_name
              end
            end
          end
        end

        test "allows duplicate default kids only when local policy explicitly enables them" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "PREFERENCE_APP_JWT_ACTIVE_KID" => "default",
            "PREFERENCE_ORG_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => "1",
          ) do
            assert_nothing_raised { JitSecurityJwtRegistry.reload! }
          end
        end

        test "rejects default active kid unless explicitly allowed" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => nil,
          ) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active kid must not be "default"/, error.message)
          end
        end

        test "rejects reserved environment kid markers outside local environments" do
          Rails.env.stub(:local?, false) do
            with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-es384-a") do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/reserved environment markers/, error.message)
            end
          end
        end

        test "allows reserved environment kid markers in local environments" do
          with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-es384-a") do
            assert_nothing_raised { JitSecurityJwtRegistry.reload! }
          end
        end

        test "rejects unknown issuer and namespace identifiers" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            unknown_issuer =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.issuer("missing")
              end
            assert_match(/unknown JWT issuer registry id/, unknown_issuer.message)

            unsupported_surface =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.surface("missing")
              end
            assert_match(/unsupported JWT issuer namespace/, unsupported_surface.message)

            unsupported_client =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.oidc_client("missing")
              end
            assert_match(/unsupported OIDC client JWT namespace/, unsupported_client.message)
          end
        end

        test "does not allow insecure default kid outside local environments" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => "1",
          ) do
            Rails.env.stub(:local?, false) do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/active kid must not be "default"/, error.message)
            end
          end
        end

        test "rejects non-empty records without issuer" do
          record = issuer_record(issuer: nil)

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth issuer is missing/, error.message)
        end

        test "rejects non-empty records without audiences" do
          record = issuer_record(audiences: [])

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth audiences are missing/, error.message)
        end

        test "allows empty optional surface records without issuer or audiences" do
          record = JitSecurityJwtIssuerRecord.new(
            id: "surface:BASE_APP",
            namespace: "BASE_APP",
            issuer: nil,
            audiences: [],
            current_kid: nil,
            keys: {},
            revoked_kids: Set.new,
          )

          assert_nothing_raised { JitSecurityJwtRegistry.validate_record!(record) }
        end

        test "rejects records whose active key is not published in jwks" do
          record = issuer_record(
            key_state: "retired",
          )

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/active key "auth-kid" is missing from JWKS/, error.message)
        end

        test "every Jump issuer record carries the PUBLIC_* issuer origin that Jump RTs sign as" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!

            JumpRtSurface::ISSUER_NAMESPACES.each do |namespace|
              assert_equal JumpRtSurface.issuer_origin(namespace), issuers.fetch("surface:#{namespace}").issuer,
                           namespace
            end
          end
        end

        test "a non-Jump surface record keeps its fixed issuer metadata" do
          with_registry_inputs do
            assert_equal "https://www.umaxica.app", JitSecurityJwtRegistry.reload!.fetch("surface:ACME_APP").issuer
          end
        end

        test "an unsafe Jump issuer origin fails registry configuration at boot instead of at request time" do
          with_registry_inputs("PUBLIC_BASE_SERVICE_URL" => "base.app.localhost") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/PUBLIC_BASE_SERVICE_URL/, error.message)
          end
        end

        test "a missing Jump issuer origin fails registry configuration" do
          Rails.env.stub(:local?, false) do
            with_registry_inputs("PUBLIC_VISA_SERVICE_URL" => nil) do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/PUBLIC_VISA_SERVICE_URL is required/, error.message)
            end
          end
        end

        test "does not retain invalid registry after failed reload" do
          with_registry_inputs do
            valid_records = JitSecurityJwtRegistry.reload!

            with_env("JWT_CORE_APP_PUBLIC_KEYSET" => "not-json") do
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }
            end

            assert_same valid_records, JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          end
        end

        private

        def issuer_record(issuer: "issuer", audiences: ["audience"], key_state: "active")
          JitSecurityJwtIssuerRecord.new(
            id: "auth",
            namespace: "AUTH",
            issuer: issuer,
            audiences: audiences,
            current_kid: "auth-kid",
            keys: {
              "auth-kid" => KeyRecord.new(
                kid: "auth-kid",
                private_key: @auth_key,
                public_key: @auth_key,
                public_jwk: JitSecurityJwtRegistry.export_public_jwk(@auth_key, kid: "auth-kid"),
                state: key_state,
              ),
            },
            revoked_kids: Set.new,
          )
        end

        def with_registry_inputs(extra_env = {})
          env = registry_input_env(extra_env)
          creds = registry_input_creds(env)
          with_env(env) do
            Rails.app.creds.stub(:option, ->(key, default: nil) { creds.fetch(key, default) }) do
              yield
            end
          end
        end

        def registry_input_env(extra_env)
          env = {
            "AUTH_JWT_ACTIVE_KID" => "auth-kid",
            "AUTH_JWT_ISSUER" => "auth-test-issuer",
            "PREFERENCE_APP_JWT_ACTIVE_KID" => "pref-app-kid",
            "PREFERENCE_ORG_JWT_ACTIVE_KID" => "pref-org-kid",
            "OIDC_CLIENT_CORE_APP_JP_ACTIVE_KID" => "core-app-kid",
            "OIDC_CLIENT_CORE_APP_JP_PRIVATE_KEY" => base64_der(@surface_key),
            "OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID" => "core-org-kid",
            "OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY" => base64_der(@surface_key),
            "OIDC_CLIENT_WARP_APP_JP_ACTIVE_KID" => "warp-app-kid",
            "OIDC_CLIENT_WARP_APP_JP_PRIVATE_KEY" => base64_der(@surface_key),
            "OIDC_CLIENT_WARP_ORG_JP_ACTIVE_KID" => "warp-org-kid",
            "OIDC_CLIENT_WARP_ORG_JP_PRIVATE_KEY" => base64_der(@surface_key),
            "OIDC_CLIENT_PALM_APP_JP_ACTIVE_KID" => "palm-app-kid",
            "OIDC_CLIENT_PALM_APP_JP_PRIVATE_KEY" => base64_der(@surface_key),
          }.merge(extra_env)
          JumpRtSurface::ISSUER_NAMESPACES.each do |namespace|
            env["JWT_#{namespace}_ACTIVE_KID"] = "jump-#{namespace.downcase.tr("_", "-")}-kid"
            env["JWT_#{namespace}_PRIVATE_KEY"] = base64_der(@surface_key)
          end
          clear_unused_registry_namespace_env(env)
          env["AUTH_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key))
          env["AUTH_JWT_PUBLIC_KEYSET"] =
            JSON.generate(keys: [JitSecurityJwtRegistry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")])
          configure_preference_jwks!(env)
          env.merge!(extra_env)
          env
        end

        def configure_preference_jwks!(env)
          preference_keysets = {
            "PREFERENCE_APP" => ["pref-app-kid", "pref-app-legacy-kid", @preference_app_key,
                                 @preference_app_legacy_key,],
            "PREFERENCE_ORG" => ["pref-org-kid", "pref-org-legacy-kid", @preference_org_key,
                                 @preference_org_legacy_key,],
          }
          preference_keysets.each do |prefix, (default_kid, legacy_kid, key, legacy_key)|
            active_kid = env.fetch("#{prefix}_JWT_ACTIVE_KID", default_kid)
            env["#{prefix}_JWT_PRIVATE_KEYSET"] = JSON.generate(active_kid => base64_der(key))
            env["#{prefix}_JWT_PUBLIC_KEYSET"] = JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(legacy_key, kid: legacy_kid)],
            )
          end
        end

        def clear_unused_registry_namespace_env(env)
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            next if JumpRtSurface::ISSUER_NAMESPACES.include?(namespace)

            env["JWT_#{namespace}_ACTIVE_KID"] = nil
            env["JWT_#{namespace}_PUBLIC_KEYSET"] = nil
            env["JWT_#{namespace}_REVOKED_KIDS"] = nil
          end
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            next if env.key?("OIDC_CLIENT_#{namespace}_ACTIVE_KID")

            env["OIDC_CLIENT_#{namespace}_ACTIVE_KID"] = nil
            env["OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET"] = nil
            env["OIDC_CLIENT_#{namespace}_REVOKED_KIDS"] = nil
          end
        end

        def registry_input_creds(env)
          credentials = {
            AUTH_JWT_PRIVATE_KEYSET: JSON.generate(
              (env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key),
            ),
            AUTH_JWT_PUBLIC_KEYSET: JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")],
            ),
          }
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            %w(ACTIVE_KID PRIVATE_KEY).each do |suffix|
              name = "OIDC_CLIENT_#{namespace}_#{suffix}"
              credentials[name] = env[name]
            end
          end
          credentials
        end

        def with_env(values)
          previous = {}
          values.each do |key, value|
            previous[key] = ENV[key]
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
          yield
        ensure
          previous.each do |key, value|
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
        end

        def base64_der(key)
          Base64.strict_encode64(key.to_der)
        end
      end
    end
  end
end
