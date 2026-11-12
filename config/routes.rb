# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Mission owns the Solid Queue job-monitoring surface (Mission Control Jobs), staff-only.
  draw :mission

  # Flipper owns the feature-flag control surface (Flipper::UI), staff-only.
  draw :flipper

  # Blazer owns the SQL exploration dashboard (Blazer::Engine), staff-only, development-only.
  draw :blazer

  # PgHero owns the PostgreSQL monitoring dashboard (PgHero::Engine), staff-only, development-only.
  draw :pghero

  # Swagger owns the rendered view of the bundled OpenAPI descriptions and the authenticated
  # endpoint that serves them (Rswag::Ui and Rswag::Api engines), staff-only, development-only.
  draw :swagger

  # Coverband owns the runtime code-execution report (Coverband::Reporters::Web), staff-only,
  # development-only, and only in the process that serves requests.
  draw :coverband

  # Sphere owns the independent Core, Warp and Palm surfaces.
  draw :core
  draw :warp
  draw :palm

  # Any host that reaches the app without matching a retained surface is unknown.
  get "/", to: "unknown_hosts#show"
end
