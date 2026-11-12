# typed: false
# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src(:self)
    policy.base_uri(:self)
    # connect-src is the directive that decides where injected or compromised
    # script can send data. A bare `:https` emits the `https:` scheme source,
    # which permits every HTTPS origin on the internet and removes CSP's value
    # as an exfiltration control. `ws:` additionally permitted a plaintext
    # scheme on an HTTPS-only application.
    #
    # Every fetch in src/controllers/ targets a same-origin endpoint supplied
    # through a data attribute. The app defines no ActionCable channels and no
    # browser WebSocket client, so no ws/wss source is needed.
    connect_sources = [:self]

    # `@vite/client` opens an HMR WebSocket to the Vite dev server, which listens on its own port of
    # the requested host. The sources are lambdas so the host is the one the browser actually used
    # rather than a hardcoded origin, and the port is the single dev-server port and nothing else.
    # Development only: no other environment runs a dev server, and production keeps `connect-src`
    # to same-origin so an injected script has nowhere to send data.
    #
    # Rails resolves a dynamic source with `context.instance_exec`, where the context is
    # `request.controller_instance || request` (ContentSecurityPolicy::Middleware#call). Only the
    # controller answers `request`; when no controller handled the response -- an exception page, a
    # middleware reply, a static file -- the context is the `ActionDispatch::Request` itself, and
    # calling `request` there raises NameError while the header is being built.
    if Rails.env.development?
      vite_dev_port = ViteRuby.config.port
      connect_sources += [
        -> { "ws://#{respond_to?(:request) ? request.host : host}:#{vite_dev_port}" },
        -> { "wss://#{respond_to?(:request) ? request.host : host}:#{vite_dev_port}" },
      ]
    end

    policy.connect_src(*connect_sources)

    policy.font_src(:self, :https, :data)
    policy.form_action(:self)
    policy.frame_ancestors(:self)
    policy.frame_src(:self)
    policy.img_src(:self, :https, :data)
    policy.manifest_src(:self)
    policy.object_src(:none)
    policy.script_src(:self, :strict_dynamic)
    # Allow @vite/client to hot reload javascript changes in development
    #    policy.script_src *policy.script_src, :unsafe_eval, "http://#{ ViteRuby.config.host_with_port }" if Rails.env.development?

    # You may need to enable this in production as well depending on your setup.
    #    policy.script_src *policy.script_src, :blob if Rails.env.test?

    # Allow @vite/client to hot reload javascript changes in development
    # policy.script_src *policy.script_src, :unsafe_eval,
    #   "http://#{ViteRuby.config.host_with_port}" if Rails.env.development?

    # You may need to enable this in production as well depending on your setup.
    #    policy.script_src *policy.script_src, :blob if Rails.env.test?

    policy.style_src(:self, :https)
    # Allow @vite/client to hot reload style changes in development
    #    policy.style_src *policy.style_src, :unsafe_inline if Rails.env.development?

    # Allow @vite/client to hot reload style changes in development
    #    policy.style_src *policy.style_src, :unsafe_inline if Rails.env.development?

    policy.style_src_elem(:self, :https)
    # No cross-origin worker source is admitted for the operator tools.
    policy.worker_src(:self)
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src style-src style-src-elem)
  config.content_security_policy_nonce_auto = true
  config.content_security_policy_report_only = false
end
