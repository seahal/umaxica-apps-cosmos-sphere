# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdOidcEdgesTest < ActiveSupport::TestCase
  def service(**attrs)
    defaults = { grant_type: "authorization_code", code: "code", redirect_uri: "https://client/cb", client_id: "client", client_secret: nil, code_verifier: "v" * 43, client_assertion_type: nil, client_assertion: nil, dpop_proof: nil, token_endpoint_uri: nil, expected_resource_type: "client" }
    OidcTokenExchangeCoordinator.new(**defaults.merge(attrs))
  end

  test "public token exchange maps missing and atomic consume outcomes" do
    client = Struct.new(
      :registered_token_endpoint_auth_method, :allowed_scopes, :required_operator_capability,
    ).new("none", %w(openid profile), nil)
    payload = {
      "state" => "issued",
      "redirect_uri" => "https://client/cb",
      "client_id" => "client",
      "resource_type" => "client",
      "scope" => "openid",
      "auth_time" => Time.current.iso8601,
      "issued_at" => Time.current.iso8601,
      "code_challenge" => "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      "code_challenge_method" => "S256",
      "subject" => OidcSubject.for(clients(:one), resource_type: "client"),
      "base_session_ref" => client_tokens(:one).public_id,
    }

    OidcClientRegistry.stub(:find, client) do
      OidcClientRegistry.stub(:valid_redirect_uri?, true) do
        OidcClientRegistry.stub(:find!, client) do
          OidcPkce.stub(:verify, true) do
            missing_code = service(code: nil).call

            assert_equal "invalid_grant", missing_code.error

            missing_store = Object.new
            missing_store.define_singleton_method(:read) { |_| nil }
            missing_record = service(code_store: missing_store).call

            assert_equal "invalid_grant", missing_record.error

            {
              missing: ["invalid_grant", "Authorization code not found"],
              expired: ["invalid_grant", "Authorization code expired"],
              replay: ["invalid_grant", "Authorization code already consumed"],
              mismatch: ["invalid_grant", "Authorization code mismatch"],
              corrupt: ["server_error", "authorization code consume failed"],
            }.each do |status, (error, description)|
              store = Object.new
              store.define_singleton_method(:read) { |_| payload }
              store.define_singleton_method(:consume!) do |**|
                Valkey::AuthState::AuthorizationCodeStore::ConsumeResult.new(
                  status: status,
                  payload: payload,
                )
              end
              store.define_singleton_method(:mark_replay!) do |**|
                Valkey::AuthState::AuthorizationCodeStore::ConsumeResult.new(status: :marked, payload: payload)
              end

              result = service(code_store: store).call

              assert_equal error, result.error, status
              assert_equal description, result.error_description, status
            end
          end
        end
      end
    end
  end

  test "public refresh grant rejects missing credentials and unsafe session state" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("none")
    OidcClientRegistry.stub(:find, client) do
      missing = service(
        grant_type: "refresh_token",
        code: nil,
        refresh_token: nil,
        expected_resource_type: "client",
      ).call

      assert_equal "invalid_grant", missing.error
      assert_equal "refresh_token is required", missing.error_description
    end
  end

  test "public token exchange rejects unsupported grant and missing realm before reading credentials" do
    unused_store = Object.new

    unused_store.define_singleton_method(:read) { |_| flunk("invalid requests must not read an authorization code") }

    unsupported = service(grant_type: "client_credentials", code_store: unused_store).call

    assert_equal "invalid_request", unsupported.error
    assert_equal "grant_type must be 'authorization_code' or 'refresh_token'", unsupported.error_description

    missing_realm = service(expected_resource_type: nil, code_store: unused_store).call

    assert_equal "invalid_request", missing_realm.error
    assert_equal "token endpoint realm is required", missing_realm.error_description
  end

  test "public authorization code validation rejects malformed and mismatched grants before consuming" do
    client = Struct.new(:registered_token_endpoint_auth_method, :allowed_scopes).new("none", %w(openid profile))
    payload = {
      "state" => "issued",
      "redirect_uri" => "https://client/cb",
      "client_id" => "client",
      "resource_type" => "client",
      "scope" => "openid",
      "auth_time" => Time.current.iso8601,
      "issued_at" => Time.current.iso8601,
      "code_challenge" => "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      "code_challenge_method" => "S256",
      "subject" => OidcSubject.for(clients(:one), resource_type: "client"),
      "base_session_ref" => client_tokens(:one).public_id,
    }
    cases = [
      {
        payload: { "expires_at" => 1.second.ago.iso8601 },
        options: {},
        error: "Authorization code expired",
        error_code: "invalid_grant",
      },
      {
        payload: { "expires_at" => "not-a-time" },
        options: {},
        error: "Authorization code expired",
        error_code: "invalid_grant",
      },
      {
        payload: { "redirect_uri" => "https://foreign.example.test/cb" },
        options: {},
        error: "redirect_uri mismatch",
        error_code: "invalid_grant",
      },
      { payload: { "client_id" => "foreign-client" },
        options: {},
        error: "client_id mismatch",
        error_code: "invalid_grant", },
      { payload: {},
        options: { code_verifier: nil },
        error: "code_verifier is required",
        error_code: "invalid_request", },
      { payload: {},
        options: { code_verifier: "short" },
        error: "code_verifier is malformed",
        error_code: "invalid_request", },
      {
        payload: { "code_challenge_method" => "plain" },
        options: {},
        error: "code_challenge_method must be S256",
        error_code: "invalid_request",
      },
      { payload: {}, options: {}, pkce_valid: false, error: "PKCE verification failed", error_code: "invalid_grant" },
      {
        payload: { "scope" => "openid admin" },
        options: {},
        error: "Authorization code scope is invalid",
        error_code: "invalid_grant",
      },
      {
        payload: {},
        options: {},
        registered_redirect: false,
        error: "redirect_uri is not registered for this authorization code's realm",
        error_code: "invalid_grant",
      },
      {
        payload: { "issued_at" => "not-a-time" },
        options: {},
        error: "authorization code predates OIDC connection revocation",
        error_code: "invalid_grant",
      },
      {
        payload: { "auth_time" => nil },
        options: {},
        error: "Authorization code authentication time missing",
        error_code: "invalid_grant",
      },
    ]

    OidcClientRegistry.stub(:find, client) do
      cases.each do |boundary|
        OidcClientRegistry.stub(:valid_redirect_uri?, boundary.fetch(:registered_redirect, true)) do
          OidcPkce.stub(:verify, boundary.fetch(:pkce_valid, true)) do
            store = Object.new
            store.define_singleton_method(:read) { |_| payload.merge(boundary.fetch(:payload)) }

            store.define_singleton_method(:consume!) { |**| flunk("rejected authorization codes must not be consumed") }
            result = service(code_store: store, **boundary.fetch(:options)).call

            assert_not result.success?, boundary.inspect
            assert_equal boundary.fetch(:error_code), result.error, boundary.inspect
            assert_equal boundary.fetch(:error), result.error_description, boundary.inspect
          end
        end
      end
    end
  end

  test "a replayed authorization code is marked before the coordinator returns invalid_grant" do
    client = Struct.new(:registered_token_endpoint_auth_method, :allowed_scopes).new("none", %w(openid profile))
    payload = {
      "state" => "consumed",
      "redirect_uri" => "https://client/cb",
      "client_id" => "client",
      "resource_type" => "client",
      "scope" => "openid",
      "auth_time" => Time.current.iso8601,
      "issued_at" => Time.current.iso8601,
      "code_challenge" => "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      "code_challenge_method" => "S256",
      "subject" => OidcSubject.for(clients(:one), resource_type: "client"),
      "base_session_ref" => client_tokens(:one).public_id,
    }
    store = Object.new
    store.define_singleton_method(:read) { |_| payload }
    store.define_singleton_method(:mark_replay!) do |**|
      Valkey::AuthState::AuthorizationCodeStore::ConsumeResult.new(status: :marked, payload: payload)
    end

    OidcClientRegistry.stub(:find, client) do
      OidcClientRegistry.stub(:valid_redirect_uri?, true) do
        OidcPkce.stub(:verify, true) do
          result = service(code_store: store).call

          assert_equal "invalid_grant", result.error
          assert_equal "Authorization code already consumed", result.error_description
        end
      end
    end
  end

  test "private-key client authentication refuses a secret and an invalid assertion" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("private_key_jwt")
    invalid_assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: false, client: nil, step_up_claims_state: :none, step_up_expectation: nil,
    )

    OidcClientRegistry.stub(:find, client) do
      secret_result = service(
        code: nil,
        client_secret: "unexpected-secret",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "assertion",
        token_endpoint_uri: "https://issuer.example.test/oauth/token",
      ).call

      assert_equal "invalid_client", secret_result.error

      OidcClientRegistry.stub(:verify_client_assertion, invalid_assertion) do
        assertion_result = service(
          code: nil,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "invalid-assertion",
          token_endpoint_uri: "https://issuer.example.test/oauth/token",
        ).call

        assert_equal "invalid_client", assertion_result.error
        assert_nil assertion_result.token_response
      end
    end
  end
end
