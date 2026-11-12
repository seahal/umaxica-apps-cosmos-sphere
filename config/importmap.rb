# frozen_string_literal: true

# Rails-first JavaScript is deliberately independent from the Vite graph.
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
