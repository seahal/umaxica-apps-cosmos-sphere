# typed: false
# frozen_string_literal: true

# Supplies shared implementation for controllers that render Inertia pages. Each host declares its
# own surface layout so the controller's presentation contract stays visible in the class.
#
# Including this concern remains the marker for "this controller renders Inertia". The layout is
# declared in each host class using its own surface name. It pairs with
# `render inertia: true`, which derives the component name from the same controller_path.
#
# It also brings in the surface chrome, because a page rendered into the slim Inertia shell has no
# header or footer of its own: those are React components fed by the shared `chrome` prop.
module SurfaceInertiaPage
  extend ActiveSupport::Concern

  include SurfaceChrome
end
