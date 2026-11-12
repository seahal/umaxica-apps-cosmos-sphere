# typed: false
# frozen_string_literal: true

return if Rails.env.test?

# FIXME: Rewrite this initializer to use OpenTelemetry properly (owner, 2026-11-10).
# The current setup gives little usable signal. Known problems include:
# - `service_name` is hardcoded to the pre-split "umaxica-apps-jit" in all four Cosmos repositories,
#   so their traces cannot be told apart; no environment, version or region resource attributes.
# - No explicit sampler; every request is traced whenever OPEN_TELEMETRY is "true".
# - The scrubbing processor is an anonymous class added after the SDK's default export processor;
#   confirm it runs before export, or sensitive attributes may leave the process unscrubbed.
# - Traces only; no metrics or logs.
# Build a staging environment and measure there (latency, error rate, database and outbound calls)
# before deciding the instrumentation set, sampling and exporter for production.
#
# TODO: Adopt an error tracker for Rails, such as Sentry (the external service and its Rails SDK,
# not code of ours with a similar name), so application errors and bugs are captured and counted.
# OpenTelemetry stays the basis for APM (traces, metrics, logs); the error tracker is used
# alongside it for exceptions, not instead of it.

# `.env.container.devcontainer` declares OPEN_TELEMETRY on `core` and sets it to
# "true": the observability group is no longer profile-gated, so `alloy` is
# always running and always able to receive.
#
# There are two endpoints, and they are not interchangeable:
#
#   Compose `core`     OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
#                      Compose DNS on the `observability` network.
#   host-native Rails  OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
#                      the loopback publication of Alloy's OTLP/HTTP receiver.
#                      This is also the opentelemetry-exporter-otlp default, so
#                      host-native development needs OPEN_TELEMETRY=true and
#                      nothing else.
#
# Neither is set here. The endpoint is deployment configuration read by the
# exporter from the environment, so hardcoding a development address would also
# decide it for production. See docs/operations/development-host-port-exposure.md.
#
# The gate stays because `core` also runs outside Compose -- a host `bin/rails`,
# a CI job, a one-off `podman run` -- where no agent exists. Without it the SDK
# would initialise there too and export into a host that does not resolve,
# producing a steady trickle of exporter retry warnings.
#
# This is an optional toggle with an explicit off state. Missing configuration
# keeps no-agent environments quiet; an invalid non-empty value fails closed
# rather than selecting a deployment mode implicitly.
open_telemetry = ENV["OPEN_TELEMETRY"]
return if open_telemetry.nil? || open_telemetry == "false"
raise ArgumentError, "OPEN_TELEMETRY must be \"true\" or \"false\"" unless open_telemetry == "true"

require "opentelemetry/sdk"
# TODO: AUDIT external access: exports traces to the OTLP endpoint.
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/action_mailer"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/action_view"
require "opentelemetry/instrumentation/active_job"
require "opentelemetry/instrumentation/active_record"
require "opentelemetry/instrumentation/active_support"
require "opentelemetry/instrumentation/concurrent_ruby"
require "opentelemetry/instrumentation/faraday"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/instrumentation/rack"
require "opentelemetry/instrumentation/redis"
require Rails.root.join("lib/observability_span_scrubber").to_s

OpenTelemetry::SDK.configure do |c|
  c.service_name = "umaxica-apps-jit"
  c.use("OpenTelemetry::Instrumentation::Rack")
  c.use("OpenTelemetry::Instrumentation::ActionPack")
  c.use("OpenTelemetry::Instrumentation::ActionView")
  c.use("OpenTelemetry::Instrumentation::ActiveSupport")
  c.use("OpenTelemetry::Instrumentation::ActiveRecord")
  c.use(
    "OpenTelemetry::Instrumentation::ActionMailer",
    email_address: :omit,
    notification_payload_transform: lambda { |payload|
      { "email.x_mailer" => payload["email.x_mailer"] }.compact
    },
    process_payload_transform: lambda { |payload|
      { mailer: payload[:mailer], action: payload[:action] }.compact
    },
  )
  c.use("OpenTelemetry::Instrumentation::ActiveJob")
  c.use("OpenTelemetry::Instrumentation::ConcurrentRuby")
  c.use("OpenTelemetry::Instrumentation::Faraday")
  c.use("OpenTelemetry::Instrumentation::Net::HTTP")
  c.use("OpenTelemetry::Instrumentation::Redis")
  c.add_span_processor(
    Class.new do
      def on_start(*)
      end

      def on_finish(span)
        ObservabilitySpanScrubber.scrub(span)
      end

      def force_flush(*)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def shutdown(*)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end
    end.new,
  )
end
