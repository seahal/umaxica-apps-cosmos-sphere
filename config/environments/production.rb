# typed: false
# frozen_string_literal: true

# Environment files are evaluated before autoloading is set up, so this is required explicitly rather
# than resolved from lib/ by Zeitwerk.
require_relative "../../lib/health_probe_paths"
require_relative "../../lib/config_values_origin_value"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  # config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  #
  # `PUBLIC_ASSET_URL` is the preferred name (adr/public-private-url-boundaries.md);
  # `ASSET_URL` stays a supported compatibility input because CI sets it
  # (.github/workflows/ci.yml). There is deliberately no literal default: a hardcoded
  # asset host silently served every production asset from one environment's CDN if the
  # variable was ever missing. Fail at boot and name what is missing instead.
  config.asset_host =
    ENV["PUBLIC_ASSET_URL"].presence || ENV["ASSET_URL"].presence ||
    raise(KeyError, "PUBLIC_ASSET_URL must be set in production (legacy alias: ASSET_URL)")

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL and use secure cookies.
  config.force_ssl = true

  # Rails emits HSTS as a safe default; the CDN may override or replace this header.
  # includeSubDomains is enabled so every subdomain is HTTPS-only. preload stays off:
  # preload-list registration is effectively irreversible and requires every subdomain to
  # serve HTTPS, so it is deferred until a deliberate review (see
  # adr/session-token-hardening-baseline.md).
  config.ssl_options = {
    hsts: {
      expires: 365.days,
      subdomains: true,
      preload: false,
    },
  }

  # Log application output to STDOUT for Cloud Run visibility.
  STDOUT.sync = true
  STDERR.sync = true
  primary_logger = ActiveSupport::Logger.new($stdout)
  primary_logger.formatter = config.log_formatter if config.log_formatter

  # Use BroadcastLogger (Rails 8 standard) to allow multiple log sinks if needed.
  config.logger = ActiveSupport::BroadcastLogger.new(
    ActiveSupport::TaggedLogging.new(primary_logger),
  )
  config.log_tags = [:request_id]

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/health"

  # Keep deprecations observable through the bounded Rails application-log subscriber.
  config.active_support.report_deprecations = true
  config.active_support.deprecation = :notify

  # Treat PostgreSQL warnings as errors (same strict setting as dev/test)
  config.active_record.db_warnings_action = :raise

  # Cache query log tags for performance
  config.active_record.cache_query_log_tags = true

  # Enumerate columns in SELECT to avoid prepared statement cache errors on column changes
  config.active_record.enumerate_columns_in_select_statements = true

  # Require --no-sandbox flag to run destructive console operations
  config.sandbox_by_default = true

  # Production URLs are explicit credentials in config/valkey.yml (`url_key`).
  # A missing URL stops the boot. The nonprod logical DB map is not consulted.
  require_relative "../../lib/umaxica/valkey/settings"
  require_relative "../../lib/umaxica/valkey/store_error_handler"

  valkey = Umaxica::Valkey::Settings.load
  cache_namespace = ["cache", Rails.env, ENV["CACHE_NAMESPACE_SUFFIX"].presence].compact.join(":")
  config.cache_store = :redis_cache_store, {
    url: valkey.cache.url,
    namespace: cache_namespace,
    error_handler: Umaxica::Valkey::StoreErrorHandler.lambda_for("cache"),
    # Not Marshal: a value written into Valkey must never deserialize into code on read
    # (docs/runbooks/valkey-protection.md).
    serializer: :message_pack,
  }
  rate_limit_namespace = [
    "rate_limit",
    Rails.env,
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

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

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

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Admit the configured retained surfaces and operator tools only.
  retained_host_env_keys = %w(
    PUBLIC_MISSION_URL PRIVATE_MISSION_URL
    PUBLIC_FLIPPER_URL PRIVATE_FLIPPER_URL
    PUBLIC_BLAZER_URL PRIVATE_BLAZER_URL
    PUBLIC_PGHERO_URL PRIVATE_PGHERO_URL
    PUBLIC_SWAGGER_URL PRIVATE_SWAGGER_URL
    PUBLIC_COVERBAND_URL PRIVATE_COVERBAND_URL
    PUBLIC_CORE_SERVICE_URL PRIVATE_CORE_SERVICE_URL
    PUBLIC_CORE_STAFF_URL PRIVATE_CORE_STAFF_URL
    PUBLIC_WARP_SERVICE_URL PRIVATE_WARP_SERVICE_URL
    PUBLIC_WARP_STAFF_URL PRIVATE_WARP_STAFF_URL
    PUBLIC_PALM_SERVICE_URL PRIVATE_PALM_SERVICE_URL
  )
  retained_public_hosts = %w(
    www-jp.umaxica.app www-jp.umaxica.org
    warp-jp.umaxica.app warp-jp.umaxica.org palm-jp.umaxica.app
    mission-sphere-jp.umaxica.dev flipper-sphere-jp.umaxica.dev
    blazer-sphere-jp.umaxica.dev pghero-sphere-jp.umaxica.dev
    swagger-sphere-jp.umaxica.dev coverband-sphere-jp.umaxica.dev
  )
  config.hosts =
    retained_public_hosts + retained_host_env_keys.filter_map do |key|
      value = ENV[key]
      next if value.nil?

      ConfigValues.build(value).host
    end
  ### Added by owner
  # We've configured this production environment to prevent the delivery of public static content.
  config.public_file_server.enabled = false

  # Gzip compression, restricted to content types that carry no secret alongside
  # attacker-influenced text.
  #
  # Compressing HTML is the BREACH precondition: every authenticated page embeds
  # the CSRF authenticity token, and the sign-in and identity surfaces reflect
  # submitted input back into the same response. An attacker who can trigger
  # requests and observe compressed response sizes can recover the token a byte
  # at a time, and Rails adds no length randomization. text/html is therefore
  # excluded here rather than compressed.
  config.middleware.use(
    Rack::Deflater,
    include: %w(
      application/javascript
      application/json
      application/xml
      image/svg+xml
      text/css
      text/javascript
      text/plain
      text/xml
    ),
  )

  # Additional security headers
  config.action_dispatch.default_headers.merge!(
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "X-Permitted-Cross-Domain-Policies" => "none",
  )

  # Default SameSite for cookies that do not set the attribute themselves (e.g. CSRF authenticity).
  # Strict by default: the Rails session cookie keeps SameSite=Lax via its explicit option in
  # config/initializers/session_store.rb (it must carry OIDC/email cross-site inbound flow state),
  # so this stricter default does not affect it. See plans/backlog for the session-cookie Strict
  # migration that would remove the remaining Lax dependency.
  config.action_dispatch.cookies_same_site_protection = :strict

  # Raise on missing callback actions (same as dev/test)
  config.action_controller.raise_on_missing_callback_actions = true

  # CSRF verification is mandatory here. Pinned explicitly so a Rails defaults change cannot
  # silently relax it, and so the contrast with the test environment is visible in the file.
  # adr/csrf-protection-disabled-in-test-environment.md
  config.action_controller.allow_forgery_protection = true

  # Raise on email delivery errors (immediate detection of SES failures)
  config.action_mailer.raise_delivery_errors = true

  # Render Rails' normal missing-translation output in production and log the key and locale.
  # Development and test keep raising so missing copy is caught before deployment.
  config.i18n.raise_on_missing_translations = false
end
