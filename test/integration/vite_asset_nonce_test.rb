# typed: false
# frozen_string_literal: true

require "test_helper"

# `script-src` uses strict-dynamic, so each Vite asset tag needs the response nonce. Vite's
# development server emits no built-asset preload links; pin the probe to exercise the built path.
class ViteAssetNonceTest < ActionDispatch::IntegrationTest
  test "every Vite asset tag on a Core page carries the response nonce" do
    host! Rails.configuration.x.boot_config.fetch(:hosts).core_service.host

    ViteRuby.instance.stub(:dev_server_running?, false) do
      get "/", params: { ri: "jp" }
    end

    assert_response :success

    nonce = response.headers["Content-Security-Policy"][/script-src[^;]*'nonce-([^']+)'/, 1]

    assert_predicate nonce, :present?

    tags = response.parsed_body.css("script[src], link[rel='modulepreload'], link[rel='stylesheet']").to_a

    assert_operator tags.count { |tag| tag["rel"] == "modulepreload" }, :>=, 1,
                    "expected the entrypoint to emit modulepreload links, otherwise this test proves nothing"

    tags.each do |tag|
      assert_equal nonce, tag["nonce"],
                   "#{tag.name} tag for #{tag["src"] || tag["href"]} does not carry the response CSP nonce"
    end
  end
end
