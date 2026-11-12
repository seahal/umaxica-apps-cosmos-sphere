# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Sign
      class InterruptionsController < Warp::App::ApplicationController
        include ::OidcRpSignInterruption

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        # The page never redirects on its own (D-153), not even to add a region.
        helper_method :interruption_sign_path
      end
    end
  end
end
