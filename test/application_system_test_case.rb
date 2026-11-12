# frozen_string_literal: true

# Check before test_helper installs the shared database cloner and parallel executor.
raise ArgumentError, "System tests require PARALLEL_WORKERS=1" unless ENV.fetch("PARALLEL_WORKERS") == "1"

require "test_helper"
require "capybara-playwright-driver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Select the surface explicitly; Chromium resolves only that host to the local Rails server.
  browser_options = {
    browser_type: :chromium,
    headless: true,
    playwright_cli_executable_path: ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH"),
    args: ["--host-resolver-rules=MAP #{ENV.fetch("SYSTEM_TEST_HOST")} 127.0.0.1"],
  }
  executable_path = ENV["PLAYWRIGHT_CHROMIUM_EXECUTABLE"]
  unless executable_path.nil?
    browser_options[:executablePath] = executable_path
    browser_options[:chromiumSandbox] = true
  end

  driven_by :playwright, screen_size: [1400, 900], options: browser_options

  setup do
    Capybara.app_host = "http://#{ENV.fetch("SYSTEM_TEST_HOST")}"
    Capybara.always_include_port = true
  end
end
