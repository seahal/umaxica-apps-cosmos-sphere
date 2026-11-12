# typed: false
# frozen_string_literal: true

module AuthenticationJwksRendering
  extend ActiveSupport::Concern

  public

  def show
    expires_in(1.hour, public: true)
    namespace = JitSecurityJwtRegistry.normalize_namespace(self.class::JWT_KEY_NAMESPACE)
    render json: JitSecurityJwtRegistry.jwks_for("surface:#{namespace}")
  end

  private

  def skip_jwks_session!
    request.session_options[:skip] = true
  end
end
