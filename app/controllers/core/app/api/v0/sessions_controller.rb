# typed: false
# frozen_string_literal: true

module Core
  module App
    module Api
      module V0
        class SessionsController < BaseController
          AUTHENTICATION_MODE = :bare
          rescue_from SphereOwnerDataUnavailableError, with: :render_owner_data_unavailable

          public

          def show
            authenticated = authenticate_core_browser_cookie!
            return if performed?

            payload = {
              authenticated: authenticated,
              csrf_token: form_authenticity_token,
            }
            payload[:actor] = actor_payload if authenticated

            render json: payload, status: :ok
          end

          private

          def render_owner_data_unavailable(_exception)
            render_problem(:service_unavailable)
          end

          def actor_payload
            raise SphereOwnerDataUnavailableError, "Governance profile data is unavailable in Sphere"
          end
        end
      end
    end
  end
end
