# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RobotsController < BareController
      include ::Robots

      AUTHENTICATION_MODE = :bare

      public

      def index
        show_plain_text
      end
    end
  end
end
