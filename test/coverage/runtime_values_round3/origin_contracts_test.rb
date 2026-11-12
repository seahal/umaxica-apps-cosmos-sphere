# frozen_string_literal: true

require "test_helper"

class RuntimeValuesRound3OriginContractsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "origin parser rejects credential query fragment path control and unsupported scheme variants" do
    [nil, "", " ", "https://user:secret@issuer.example", "https://issuer.example/oauth/token",
     "https://issuer.example?q=1", "https://issuer.example#fragment",
     "https://[bad", "issuer.exa\nmple",].each do |value|
      assert_raises(ArgumentError) { ConfigValues.build(value) }
    end
    assert_raises(ArgumentError) { ConfigValues.build("http://issuer.example", allow_localhost: true) }
    assert_raises(ArgumentError) { Oidc::AcmeServiceOrigin.from("issuer.example", default_scheme: "ftp") }
    ["https://user:secret@issuer.example", "https://issuer.example?q=1",
     "https://issuer.example#fragment",].each do |value|
      assert_raises(ArgumentError) { Oidc::AcmeServiceOrigin.from(value, default_scheme: "https") }
      assert_nil Oidc::AcmeServiceOrigin.host_from(value)
    end
  end

  test "origin values serialize standard ports implicitly and nonstandard ports explicitly" do
    without_port = ConfigValues::OriginValue.new("https", "issuer.example", nil, "/", nil, URI.parse("https://issuer.example/"))

    assert_equal "https://issuer.example", without_port.to_s
    assert_equal "https://issuer.example", ConfigValues.build("https://ISSUER.EXAMPLE:443/").to_s
    assert_equal "https://issuer.example:8443", ConfigValues.build("https://issuer.example:8443").to_s
    assert_equal "http://app.localhost", ConfigValues.build("http://app.localhost:80", allow_localhost: true).to_s
    assert_equal "http://app.localhost:3000",
                 ConfigValues.build("http://app.localhost:3000", allow_localhost: true).to_s
    value = ConfigValues.build("issuer.example")

    assert_predicate value, :frozen?
    assert_equal "/", value.path
    assert_nil value.query
    assert_equal "https://issuer.example/", value.uri.to_s
  end

  test "strict public identities accept DNS https origins and reject nonpublic or ambiguous endpoints" do
    assert_equal "https://public.example.com", ConfigValues.public_https_origin("HTTPS://PUBLIC.EXAMPLE.COM/")
    [nil, "", "public.example.com", "http://public.example.com", "https://public.example.com:443",
     "https://localhost", "https://127.0.0.1", "https://[::1]", "https://public.example.com.",
     "https://singlelabel",
     "https://issuer.localhost", "https://issuer.internal", "https://issuer.invalid",
     "https://public.example.com\u007f", "https://public.example.com?", "https://public.example.com#",].each do |value|
      assert_raises(ArgumentError) { ConfigValues.public_https_origin(value) }
    end
  end

  test "Acme custom ports remain fixed across endpoint generation" do
    origin = Oidc::AcmeServiceOrigin.from("issuer.example:8443", default_scheme: "https")

    assert_equal "https://issuer.example:8443", origin.origin
    assert_equal "https://issuer.example:8443/oauth/token", origin.token_endpoint
    assert_equal "https://issuer.example:8443/oauth/authorize?scope=openid",
                 origin.authorization_endpoint(query: { scope: "openid" })
    assert_equal "issuer.example", Oidc::AcmeServiceOrigin.host_from("HTTPS://ISSUER.EXAMPLE/")
    assert_nil Oidc::AcmeServiceOrigin.host_from(nil)
  end

  test "Acme decisions distinguish malformed native and unsupported target endpoints" do
    origin = Oidc::AcmeServiceOrigin.from("https://issuer.example", default_scheme: "https")
    request = Struct.new(:host, :scheme).new("rp.example", "https")
    [nil, "/oauth/authorize", "https://[bad"].each do |url|
      result = origin.decision_for_authorize_url(url, request:)

      assert_predicate result, :rejected?
      assert_not_predicate result, :jump?
      assert_not_predicate result, :direct?
      assert_equal "invalid_url", result.reason_code
      assert_nil result.target_host
      assert_nil result.target_scheme
      assert_nil result.target_path
      assert_nil result.target_port
    end
    custom = origin.decision_for_authorize_url("app-native://login/callback", request:)

    assert_predicate custom, :jump?
    assert_equal "native_custom_scheme", custom.reason_code
    assert_equal "login", custom.target_host
    assert_equal "/callback", custom.target_path
    unsupported = origin.decision_for_authorize_url("https://issuer.example/oauth/token", request:)

    assert_equal "not_acme_authorize", unsupported.reason_code
  end

  test "Acme exact origin and site rules return explicit jump reasons" do
    origin = Oidc::AcmeServiceOrigin.from("https://issuer.example:8443", default_scheme: "https")
    request = Struct.new(:host, :scheme).new("rp.example", "https")
    {
      "http://issuer.example:8443/oauth/authorize" => "scheme_mismatch",
      "https://other.example:8443/oauth/authorize" => "host_mismatch",
      "https://issuer.example:8444/oauth/authorize" => "port_mismatch",
    }.each do |url, reason|
      decision = origin.decision_for_authorize_url(url, request:)

      assert_predicate decision, :jump?
      assert_equal reason, decision.reason_code
      assert_equal reason, origin.same_site_rejection_reason(url, request:)
      assert_not origin.same_site_authorize_url?(url, request:)
    end
    unrelated = Struct.new(:host, :scheme).new("", "https")
    decision = origin.decision_for_authorize_url(origin.authorization_endpoint, request: unrelated)

    assert_equal "site_mismatch", decision.reason_code
    single = Oidc::AcmeServiceOrigin.from("https://localhost", default_scheme: "https")
    local_request = Struct.new(:host, :scheme).new("localhost", "https")

    assert single.same_site_authorize_url?(single.authorization_endpoint, request: local_request)
    assert_nil single.same_site_rejection_reason(single.authorization_endpoint, request: local_request)
  end
end
