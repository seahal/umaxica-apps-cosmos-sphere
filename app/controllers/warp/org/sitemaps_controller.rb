# typed: false
# frozen_string_literal: true

module Warp
  module Org
    class SitemapsController < BareController
      include ::Sitemap

      AUTHENTICATION_MODE = :bare

      public

      def show
        show_xml
      end
    end
  end
end
