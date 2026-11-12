# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "production-like ssl middleware emits conservative hsts header" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    ssl = ActionDispatch::SSL.new(
      app,
      hsts: {
        expires: 365.days,
        subdomains: false,
        preload: false,
      },
    )

    response = Rack::MockRequest.new(ssl).get("https://example.test/health")

    assert_equal "max-age=31536000", response["Strict-Transport-Security"]
  end

  # Rails resolves a dynamic CSP source with `context.instance_exec`, where the context is
  # `request.controller_instance || request`. Only the controller answers `request`, so a lambda
  # that calls it raises NameError while building the header for every response no controller
  # handled: an exception page, a middleware reply, a static file. The one lambda that needs the
  # host is development-only, so no request in this suite reaches it; this reads the initializer
  # instead.
  test "dynamic content security policy sources do not assume a controller context" do
    initializer = Rails.root.join("config/initializers/content_security_policy.rb").read
    sources = initializer.scan(/->\s*\{[^}]*\}/)

    assert_predicate sources, :any?, "expected the policy to declare dynamic sources"

    sources.grep(/\brequest\b/).each do |source|
      assert_includes source, "respond_to?(:request)",
                      "#{source.strip} must resolve the request for both context types"
    end
  end
end
