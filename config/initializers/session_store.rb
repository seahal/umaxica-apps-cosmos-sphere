# typed: false
# frozen_string_literal: true

# Operator tools use host-only sessions. Each hostname receives its own cookie with no shared
# parent-domain state.
Rails.application.config.session_store(
  :cookie_store,
  key: "_cosmos_sphere_operator_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
)
