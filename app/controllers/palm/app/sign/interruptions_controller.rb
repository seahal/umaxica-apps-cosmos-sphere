# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      class InterruptionsController < Palm::App::ApplicationController
        include ::OidcRpSignInterruption

        ensure_fqdn_gate_first!

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        # The page never redirects on its own (D-153), not even to add a region.
        helper_method :interruption_sign_path
      end
    end
  end
end
