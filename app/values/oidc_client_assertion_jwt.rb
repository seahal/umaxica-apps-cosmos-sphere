# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes
  def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid, step_up_expectation: nil)
    validate_step_up_expectation!(step_up_expectation)
    issue_with_configured_key(
      client_id: client_id,
      token_url: token_url,
      now: now,
      jti: jti,
      step_up_expectation: step_up_expectation,
    )
  rescue JitSecurityJwtRegistry::ConfigurationError
    return nil unless refresh_local_key_material!(client_id: client_id)

    begin
      issue_with_configured_key(
        client_id: client_id,
        token_url: token_url,
        now: now,
        jti: jti,
        step_up_expectation: step_up_expectation,
      )
    rescue JitSecurityJwtRegistry::ConfigurationError
      nil
    end
  end

  def issue_with_configured_key(client_id:, token_url:, now:, jti:, step_up_expectation:)
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return nil if namespace.blank?

    issuer_id = "oidc_client:#{namespace}"
    payload = {
      "iss" => client_id.to_s,
      "sub" => client_id.to_s,
      "aud" => token_url.to_s,
      "jti" => jti,
      "iat" => now.to_i,
      "exp" => (now + TTL).to_i,
      "typ" => TOKEN_TYPE,
    }
    if step_up_expectation
      payload["step_up_grant"] = step_up_expectation.grant
      payload["step_up_sub"] = step_up_expectation.subject
    end

    JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id: issuer_id)
  end

  def refresh_local_key_material!(client_id:)
    return false unless Rails.env.local?
    return false unless defined?(JitSecurityJwtLocalKeysetInstaller)

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return false if namespace.blank?

    JitSecurityJwtLocalKeysetInstaller.install!
    JitSecurityJwtRegistry.reload!
    JitSecurityJwtRegistry.private_key_for("oidc_client:#{namespace}").present?
  end

  def validate_step_up_expectation!(expectation)
    return if expectation.nil? || expectation.is_a?(OidcClientAssertionStepUpExpectationValue)

    raise ArgumentError, "step_up_expectation must be an OIDC client assertion value"
  end

  private_class_method :issue_with_configured_key, :refresh_local_key_material!,
                       :validate_step_up_expectation!
end
