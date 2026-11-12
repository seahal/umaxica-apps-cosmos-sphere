# typed: false
# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require_relative "../../lib/config_values_origin_value"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Live DOM reloaders mutate forms in-place and break third-party challenge
  # third-party widgets. Keep them opt-in for public dev hosts.
  config.hotwire.spark.enabled = ENV["HOTWIRE_SPARK_ENABLED"] == "true"

  # Do not eager load code on boot.
  config.eager_load = false

  # Detailed error pages and `/rails/info` are served to every request, including requests that
  # arrive through Cloudflare Tunnel. This is an accepted exposure, chosen on 2026-10-07 so errors
  # can be read in the browser on the tunnel hosts: an unmatched path answers a remote scanner
  # with the debug page and the full route table, as recorded in
  # evidence/2026-10-05-dev-detailed-errors-tunnel-exposure-Q4T8.md. Set this to `false` to close
  # it, or put the public hosts behind Cloudflare Access.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails org:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-org.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Cache lives on valkey-cache; rate-limit and auth-state live on valkey-kvs.
  # Logical DB indexes and hosts come from config/valkey.yml via Settings.
  # Neither store is authoritative. Losing the cache costs a refetch; losing the
  # rate-limit counters resets the current windows.
  require_relative "../../lib/umaxica/valkey/settings"
  require_relative "../../lib/umaxica/valkey/store_error_handler"

  valkey = Umaxica::Valkey::Settings.load
  cache_namespace = [valkey.cache.namespace, ENV["CACHE_NAMESPACE_SUFFIX"].presence].compact.join(":")
  config.cache_store = :redis_cache_store, {
    url: valkey.cache.url,
    namespace: cache_namespace,
    error_handler: Umaxica::Valkey::StoreErrorHandler.lambda_for("cache"),
    # Not Marshal: a value written into Valkey must never deserialize into code on read
    # (docs/runbooks/valkey-protection.md).
    serializer: :message_pack,
  }
  rate_limit_namespace = [
    valkey.rate_limit.namespace,
    ENV["RATE_LIMIT_NAMESPACE_SUFFIX"].presence,
  ].compact.join(":")
  config.x.rate_limit.namespace = rate_limit_namespace
  config.x.rate_limit.store =
    ActiveSupport::Cache::RedisCacheStore.new(
      url: valkey.rate_limit.url,
      namespace: rate_limit_namespace,
      error_handler: Umaxica::Valkey::StoreErrorHandler.lambda_for("rate_limit"),
      # Not Marshal: a value written into Valkey must never deserialize into code on read
      # (docs/runbooks/valkey-protection.md).
      serializer: :message_pack,
    )

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Raise on deprecation warnings to catch issues early.
  config.active_support.deprecation = :raise

  # Raise an error on page load if there are pending migrations.
  # The pending-migration page check connects to every configured database. A role process
  # (R5-WU03A) may CONNECT only to its own, so only the shared maintenance role runs the check;
  # migrations are applied with the maintenance login, never from a role process.
  config.active_record.migration_error = RuntimeRole.shared? ? :page_load : false

  # Raise on SQL warnings from PostgreSQL (overrides :log in application.rb).
  config.active_record.db_warnings_action = :raise
  config.active_record.dump_schema_after_migration = false

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Include source location in query log tags for easier debugging
  config.active_record.query_log_tags = %i(application controller action job source_location)

  # Detect N+1 queries and raise errors immediately.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.active_record.action_on_strict_loading_violation = :raise

  # Disallow deprecated .connection usage (must use .with_connection for multi-DB)
  config.active_record.permanent_connection_checkout = :deprecated

  # Raise error for missing translations in controllers, views, and models.
  config.i18n.raise_on_missing_translations = :strict

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # CSRF verification is mandatory here. Pinned explicitly so a Rails defaults change cannot
  # silently relax it, and so the contrast with the test environment is visible in the file.
  # adr/csrf-protection-disabled-in-test-environment.md
  config.action_controller.allow_forgery_protection = true

  # A parameter the permit list does not cover is a Strong Parameters gap, not a note to
  # read later. The default :log lets the gap ship; raise so it stops the request here.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # On by default since load_defaults 7.0 - pinned so a defaults bump cannot silently
  # turn redirect-to-user-input back into a warning.
  config.action_controller.action_on_open_redirect = :raise

  # config/application.rb silences Rails' own CSRF warning so production keeps a single
  # redacted record per event. In development the raw reason is what makes a blocked
  # request diagnosable - which Origin failed to match which base_url - and the log holds
  # no real user data, so turn it back on here.
  config.action_controller.log_warning_on_csrf_failure = true

  # Apply autocorrection by RuboCop to files generated by `bin/rails generate`.
  config.generators.apply_rubocop_autocorrect_after_generate!

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  config.action_dispatch.verbose_redirect_logs = true

  # Use Solid Queue in Development.
  config.active_job.queue_adapter = :solid_queue
  # `reading` is mapped to the same `queue` database, not a replica: the queue database has no
  # replica entry in config/database.yml, and Mission Control Jobs reads the queue through the
  # reading role, which raises ConnectionNotDefined when only `writing` is declared.
  config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }

  # Enable Gzip compression
  config.middleware.use(Rack::Deflater)

  # Enable DNS rebinding protection for the retained application and operator hosts.
  localhost_tunnel_hosts = %w(
    mission.core.dev.localhost:3000 mission.core.dev.localhost:3001
    flipper.core.dev.localhost:3000 flipper.core.dev.localhost:3001
    blazer.core.dev.localhost:3000 blazer.core.dev.localhost:3001
    pghero.core.dev.localhost:3000 pghero.core.dev.localhost:3001
    coverband.core.dev.localhost:3000 coverband.core.dev.localhost:3001
    swagger.core.dev.localhost:3000 swagger.core.dev.localhost:3001
    core.app.localhost core.org.localhost core.net.localhost core.dev.localhost
    warp.app.localhost warp.org.localhost palm.app.localhost
  )

  retained_host_env_keys = %w(
    PRIVATE_MISSION_URL PRIVATE_FLIPPER_URL PRIVATE_BLAZER_URL PRIVATE_PGHERO_URL
    PRIVATE_COVERBAND_URL PRIVATE_SWAGGER_URL PUBLIC_MISSION_URL PUBLIC_FLIPPER_URL
    PUBLIC_BLAZER_URL PUBLIC_PGHERO_URL PUBLIC_COVERBAND_URL PUBLIC_SWAGGER_URL
    PUBLIC_CORE_SERVICE_URL PRIVATE_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PRIVATE_CORE_STAFF_URL
    PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL PUBLIC_PALM_SERVICE_URL
    PRIVATE_PALM_SERVICE_URL
  )
  env_hosts =
    retained_host_env_keys.filter_map do |key|
      value = ENV[key]
      next if value.nil?

      origin = ConfigValues.build(value, allow_localhost: true)
      origin.host
    end

  retained_public_hosts = %w(
    www-jp.umaxica.app www-jp.umaxica.org
    warp-jp.umaxica.app warp-jp.umaxica.org
    palm-jp.umaxica.app
    mission-sphere-jp.umaxica.dev flipper-sphere-jp.umaxica.dev
    blazer-sphere-jp.umaxica.dev pghero-sphere-jp.umaxica.dev
    coverband-sphere-jp.umaxica.dev swagger-sphere-jp.umaxica.dev
  )

  config.hosts.concat((localhost_tunnel_hosts + retained_public_hosts + env_hosts).uniq)

  ## file watcher
  config.file_watcher = ActiveSupport::FileUpdateChecker

  ## Email Settings
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "email-smtp.#{ENV.fetch("AWS_SES_REGION", "ap-northeast-1")}.amazonaws.com",
    user_name: Rails.app.creds.option(:AWS_SES_SMTP_USERNAME),
    password: Rails.app.creds.option(:AWS_SES_SMTP_PASSWORD),
    port: 465,
    tls: true,
    authentication: :login,
    openssl_verify_mode: "peer",
    open_timeout: 5,
    read_timeout: 10,
  }

  # Serve Vite's auto-built files from public/vite-dev when the Vite dev server
  # is not the active asset host for a request.
  config.public_file_server.enabled = true

  # SMS Provider Configuration - Use test provider in development
  config.sms_provider = ENV.fetch("SMS_PROVIDER", "test")
end
