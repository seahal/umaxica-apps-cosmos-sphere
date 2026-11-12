# frozen_string_literal: true

require "test_helper"

class AcmeOriginAuthorityBoundaryTest < ActiveSupport::TestCase
  test "HTTP origins without an authority cannot become an Access destination" do
    ["http://", "https:///", "https:///oauth/authorize"].each do |origin|
      error =
        assert_raises(ArgumentError) do
          Oidc::AcmeServiceOrigin.from(origin, default_scheme: "https")
        end
      assert_equal "invalid origin", error.message
      assert_nil Oidc::AcmeServiceOrigin.host_from(origin)
    end
  end

  test "a request without a host never receives direct same site authorization" do
    origin = Oidc::AcmeServiceOrigin.from("https://acme.example.test", default_scheme: "https")
    request = ActionDispatch::TestRequest.create("HTTP_HOST" => "", "HTTPS" => "on")

    assert_equal "", request.host
    target = origin.authorization_endpoint(query: { client_id: "core-app-jp" })
    decision = origin.decision_for_authorize_url(target, request: request)

    assert_predicate decision, :jump?
    assert_not decision.direct?
    assert_not decision.same_site
    assert_equal "site_mismatch", decision.reason_code
    assert_equal "", decision.request_host
    assert_equal "acme.example.test", decision.target_host
    assert_not origin.same_site_authorize_url?(target, request: request)
    assert_equal "site_mismatch", origin.same_site_rejection_reason(target, request: request)
  end
end
