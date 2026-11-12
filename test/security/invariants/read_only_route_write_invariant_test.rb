# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class ReadOnlyRouteWriteInvariantTest < ActionDispatch::IntegrationTest
      test "Sphere public-root GET and HEAD navigation does not write authentication or preference state" do
        observed_writes = []

        callback =
          lambda do |_name, _started, _finished, _unique_id, payload|
            sql = payload[:sql].to_s.squish
            next unless sql.match?(/\A(?:INSERT|UPDATE|DELETE)\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?ar_internal_metadata"?\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?schema_migrations"?\b/i)

            observed_writes << sql
          end

        hosts = Rails.configuration.x.boot_config.fetch(:hosts)
        surfaces = {
          "core app" => hosts.core_service.host,
          "core org" => hosts.core_staff.host,
          "warp app" => hosts.warp_service.host,
          "warp org" => hosts.warp_staff.host,
          "palm app" => hosts.palm_service.host,
        }
        methods = [
          "GET",
          "HEAD",
        ]

        surfaces.each do |surface, host|
          methods.each do |method_name|
            reset!
            host! host
            observed_writes.clear

            ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
              if method_name == "GET"
                get "/?ri=jp"
              else
                head "/?ri=jp"
              end
            end

            assert_response :success, "#{surface} #{method_name} / response"
            assert_empty observed_writes,
                         "#{surface} #{method_name} / must not persist preference or auth state"
          end
        end
      end
    end
  end
end
