# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageControllerUnroutedMcpActionsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "withdrawn MCP actions retain a stateless read-only protocol at the Rails Rack action boundary" do
    # Routes remain withdrawn. This exercises the existing public Rails Rack action directly;
    # it neither registers a test route nor adds a controller wrapper or exposes a private method.
    [
      [Warp::App::McpsController, "PUBLIC_WARP_SERVICE_URL"],
      [Warp::Org::McpsController, "PUBLIC_WARP_STAFF_URL"],
    ].each do |controller, host_setting|
      [
        { jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: {
            protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "protocol-client", version: "1" },
          }, },
        { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} },
        { jsonrpc: "2.0", method: "notifications/initialized" },
        { jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "system_liveness", arguments: {} } },
        { jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "system_version", arguments: {} } },
        { jsonrpc: "2.0", id: 5, method: "tools/call", params: { name: "service_info", arguments: {} } },
      ].each do |message|
        environment = Rack::MockRequest.env_for(
          "https://#{ENV.fetch(host_setting)}/mcp", {
            :method => "POST",
            :input => JSON.generate(message),
            "CONTENT_TYPE" => "application/json",
            "HTTP_ACCEPT" => "application/json, text/event-stream",
            "REMOTE_ADDR" => "127.0.0.1",
          },
        )
        status, headers, body = controller.action(:create).call(environment)
        content = body.each.to_a.join

        assert_equal "no-store", headers.fetch("cache-control")
        if message.key?(:id)
          assert_equal 200, status
          parsed = JSON.parse(content)

          assert_equal message.fetch(:id), parsed.fetch("id")
          assert parsed.key?("result")
          if message.fetch(:method) == "tools/list"
            tool_names = parsed.fetch("result").fetch("tools").map { |tool| tool.fetch("name") }.sort

            assert_equal %w(service_info system_liveness system_version), tool_names
          end
        else
          assert_equal 202, status
          assert_empty content
        end
        body.close
      end
    end
  end
end
