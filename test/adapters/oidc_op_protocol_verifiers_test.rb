# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcOpProtocolVerifiersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CLIENT_ID = "core-app-jp"
  REALM = "app"
  ISSUER = "https://base.example/app"
  AUDIENCE = "core-app-jp"

  setup do
    @private_key = OpenSSL::PKey::RSA.generate(3072)
    @rotated_private_key = OpenSSL::PKey::RSA.generate(3072)
  end

  test "id token verifier names the failed check without disclosing token values" do
    {
      "nonce" => id_payload.merge("nonce" => "other-nonce"),
      "act" => id_payload.merge("act" => "operator"),
    }.each do |detail, payload|
      result = id_verifier(token: encode(payload, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)).call

      assert_equal "invalid_id_token", result.error
      assert_equal detail, result.detail
      assert_not_includes result.detail, "other-nonce"
    end

    wrong_issuer = id_payload.merge("iss" => "https://other.example/app")
    result = id_verifier(token: encode(wrong_issuer, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)).call

    assert_equal "issuer", result.detail
  end

  test "a valid id token reports no failed check" do
    assert_nil id_verifier(token: id_token).call.detail
  end

  test "ID Token nonce can be checked against the RP's stored digest" do
    nonce = "rp-step-up-nonce"
    token = encode(id_payload.merge("nonce" => nonce), typ: OidcOpIdTokenVerifier::TOKEN_TYPE)
    verifier = OidcOpIdTokenVerifier.new(
      id_token: token,
      client_id: CLIENT_ID,
      realm: REALM,
      issuer: ISSUER,
      expected_nonce_digest: Digest::SHA256.hexdigest(nonce),
      expected_max_age: 60,
      expected_resource_type: "client",
      jwks_client: jwks_client,
    )

    assert_predicate verifier.call, :success?
    assert_raises(ArgumentError) do
      OidcOpIdTokenVerifier.new(
        id_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER,
        expected_nonce: nonce, expected_nonce_digest: Digest::SHA256.hexdigest(nonce), jwks_client: jwks_client,
      )
    end
    assert_raises(ArgumentError) do
      OidcOpIdTokenVerifier.new(
        id_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER,
        expected_nonce_digest: "A" * 64, jwks_client: jwks_client,
      )
    end
    assert_raises(ArgumentError) do
      OidcOpIdTokenVerifier.new(
        id_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER,
        expected_nonce: "", expected_nonce_digest: Digest::SHA256.hexdigest(nonce), jwks_client: jwks_client,
      )
    end
  end

  test "access verifier accepts a target token using only the fixed public JWKS" do
    result = access_verifier(token: access_token).call

    assert_predicate result, :success?, "error=#{result.error.inspect} fetches=#{@jwks_fetches}"
    assert_equal CLIENT_ID, result.payload.fetch("client_id")
    assert_equal 1, @jwks_fetches
  end

  test "access verifier rejects profile confusion and binding mismatches" do
    valid_payload = access_payload
    cases = {
      "wrong JOSE type" => [valid_payload, { typ: "id-token+jwt" }],
      "wrong issuer" => [valid_payload.merge("iss" => "https://other.example/app"), {}],
      "wrong audience" => [valid_payload.merge("aud" => ["other-client"]), {}],
      "wrong client" => [valid_payload.merge("client_id" => "warp-app-jp"), {}],
      "wrong realm scope" => [valid_payload.merge("scope" => "openid domain:operator"), {}],
      "unknown authentication context" => [valid_payload.merge("authn_ctx" => "standby"), {}],
      "missing session binding" => [valid_payload.except("sid"), {}],
    }

    cases.each do |label, (payload, header_overrides)|
      token = encode(payload, header: { "kid" => "access-a" }.merge(header_overrides))
      result = access_verifier(token: token).call

      assert_not_predicate result, :success?, label
    end
  end

  test "access verifier rejects a token carrying a key or URL header" do
    token = encode(access_payload, header: { "kid" => "access-a", "jku" => "https://attacker.example/jwks" })

    result = access_verifier(token: token).call

    assert_not_predicate result, :success?
    assert_equal 0, @jwks_fetches
  end

  test "HMAC and unsigned OP tokens are refused before fetching keys" do
    cases = [
      [access_payload, OidcOpAccessTokenVerifier::TOKEN_TYPE, :access],
      [id_payload, OidcOpIdTokenVerifier::TOKEN_TYPE, :id],
      [access_payload, OidcOpLogoutTokenVerifier::TOKEN_TYPE, :logout],
    ]

    cases.each do |payload, typ, kind|
      ["HS256", "none"].each do |algorithm|
        secret = (algorithm == "none") ? nil : "untrusted-key"
        token = JWT.encode(payload, secret, algorithm, { kid: "unknown", typ: typ })
        verifier =
          case kind
          when :access then access_verifier(token: token)
          when :id then id_verifier(token: token)
          when :logout
            OidcOpLogoutTokenVerifier.new(
              logout_token: token, client_id: CLIENT_ID, issuer: ISSUER, jwks_client: jwks_client,
            )
          end

        assert_not_predicate verifier.call, :success?, "#{kind} #{algorithm}"
        assert_equal 0, @jwks_fetches, "#{kind} #{algorithm}"
      end
    end
  end

  test "ES384 signed tokens are refused for every OP token family before JWKS lookup" do
    legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
    cases = [
      [access_payload, OidcOpAccessTokenVerifier::TOKEN_TYPE, :access],
      [id_payload, OidcOpIdTokenVerifier::TOKEN_TYPE, :id],
      [access_payload, OidcOpLogoutTokenVerifier::TOKEN_TYPE, :logout],
    ]

    cases.each do |payload, typ, kind|
      token = JWT.encode(payload, legacy_key, "ES384", { kid: "legacy-es384", typ: typ })
      client = jwks_client(fetcher: -> { flunk("legacy algorithm reached JWKS lookup") })
      verifier =
        case kind
        when :access then access_verifier(token: token, fetcher: -> { flunk("legacy algorithm reached JWKS lookup") })
        when :id then id_verifier(token: token)
        when :logout
          OidcOpLogoutTokenVerifier.new(
            logout_token: token, client_id: CLIENT_ID, issuer: ISSUER, jwks_client: client,
          )
        end

      result = verifier.call

      assert_not_predicate result, :success?, kind.to_s
      assert_equal "invalid_header", result.error if kind == :access
    end

    assert_equal 0, @jwks_fetches
  end

  test "RS256 and PS384 signatures and mismatched PS256 headers fail before JWKS lookup" do
    cases = [
      [access_payload, OidcOpAccessTokenVerifier::TOKEN_TYPE, :access],
      [id_payload, OidcOpIdTokenVerifier::TOKEN_TYPE, :id],
      [access_payload, OidcOpLogoutTokenVerifier::TOKEN_TYPE, :logout],
    ]

    cases.each do |payload, typ, kind|
      ["RS256", "PS384"].each do |algorithm|
        token = JWT.encode(payload, @private_key, algorithm, { kid: "rsa-#{algorithm.downcase}", typ: typ })
        fetcher = -> { flunk("#{algorithm} reached JWKS lookup") }
        verifier =
          case kind
          when :access then access_verifier(token: token, fetcher:)
          when :id then id_verifier(token: token)
          when :logout
            OidcOpLogoutTokenVerifier.new(
              logout_token: token, client_id: CLIENT_ID, issuer: ISSUER,
              jwks_client: jwks_client(fetcher:),
            )
          end

        assert_not_predicate verifier.call, :success?, "#{kind} #{algorithm}"
      end

      signed = JWT.encode(payload, @private_key, "PS256", { kid: "mismatched-header", typ: typ })
      segments = signed.split(".")
      header = JSON.parse(Base64.urlsafe_decode64(segments.fetch(0)))
      header["alg"] = "RS256"
      segments[0] = Base64.urlsafe_encode64(JSON.generate(header), padding: false)
      mismatched = segments.join(".")
      fetcher = -> { flunk("mismatched algorithm header reached JWKS lookup") }
      verifier =
        case kind
        when :access then access_verifier(token: mismatched, fetcher:)
        when :id then id_verifier(token: mismatched)
        when :logout
          OidcOpLogoutTokenVerifier.new(
            logout_token: mismatched, client_id: CLIENT_ID, issuer: ISSUER,
            jwks_client: jwks_client(fetcher:),
          )
        end

      assert_not_predicate verifier.call, :success?, "#{kind} mismatched header"
    end

    assert_equal 0, @jwks_fetches
  end

  test "every OP token family rejects a valid PS256 signature from a 2048-bit JWKS key" do
    undersized_key = OpenSSL::PKey::RSA.generate(2048)
    undersized_jwk = JWT::JWK.new(undersized_key, kid: "undersized-rsa").export.stringify_keys.except(
      *JitSecurityJwtJwk::PRIVATE_FIELDS,
    ).merge("alg" => "PS256", "use" => "sig")
    fetcher = -> { { "keys" => [undersized_jwk] } }
    cases = [
      [encode(access_payload, key: undersized_key, kid: "undersized-rsa"), :access],
      [encode(id_payload, key: undersized_key, kid: "undersized-rsa", typ: OidcOpIdTokenVerifier::TOKEN_TYPE), :id],
      [encode(access_payload, key: undersized_key, kid: "undersized-rsa", typ: OidcOpLogoutTokenVerifier::TOKEN_TYPE),
       :logout,],
    ]

    cases.each do |token, kind|
      verifier =
        case kind
        when :access then access_verifier(token:, fetcher:)
        when :id then id_verifier(token:, fetcher:)
        when :logout
          OidcOpLogoutTokenVerifier.new(
            logout_token: token, client_id: CLIENT_ID, issuer: ISSUER,
            jwks_client: jwks_client(fetcher:),
          )
        end

      assert_not_predicate verifier.call, :success?, kind.to_s
    end
  end

  # D-144: a kid absent from a fresh fetch is invalid without another fetch inside the window;
  # after the window a new lease may fetch again.
  test "an unknown kid absent from a fresh fetch is refused until the refetch window passes" do
    first_jwk = public_jwk(@private_key, kid: "access-a")
    rotated_jwk = public_jwk(@rotated_private_key, kid: "access-b")
    documents = [{ "keys" => [first_jwk] }, { "keys" => [rotated_jwk] }]
    now = [Time.current]
    fetcher =
      lambda do
        @jwks_fetches += 1
        documents.fetch(@jwks_fetches - 1, documents.last)
      end
    client = jwks_client(fetcher:, limiter: local_limiter(-> { now.first }))
    token = encode(access_payload, key: @rotated_private_key, kid: "access-b")

    assert_equal "invalid_token", verify_with(client, token).error
    assert_equal "invalid_token", verify_with(client, token).error
    assert_equal 1, @jwks_fetches

    now[0] += OidcJwksRefetchLimiter::WINDOW + 1.second

    assert_predicate verify_with(client, token), :success?
    assert_equal 2, @jwks_fetches
  end

  test "a known key can use a briefly stale cache but an unknown key cannot" do
    @jwks_fetches = 0
    clock = [Time.current]
    fetcher =
      lambda do
        @jwks_fetches += 1
        raise OidcOpJwksClient::FetchError, "JWKS unavailable" if @jwks_fetches > 1

        { "keys" => [public_jwk(@private_key, kid: "access-a")] }
      end
    client = jwks_client(fetcher: fetcher, clock: -> { clock.first })

    assert_predicate client.lookup("access-a"), :found?
    clock[0] += OidcOpJwksClient::CACHE_TTL + 1.minute

    assert_predicate client.lookup("access-a"), :found?

    clock[0] += OidcOpJwksClient::MAX_STALE_TTL + 1.second

    assert_not_predicate client.lookup("access-a"), :found?
  end

  test "JWKS client rejects duplicate, private and oversized key documents" do
    jwk = public_jwk(@private_key, kid: "access-a")
    invalid_documents = [
      { "keys" => [jwk, jwk] },
      { "keys" => [jwk.merge("d" => "private")] },
      { "keys" => Array.new(OidcOpJwksClient::MAXIMUM_KEYS + 1) { jwk } },
    ]

    invalid_documents.each do |document|
      client = jwks_client(fetcher: -> { document })

      assert_not_predicate client.lookup("access-a"), :found?
    end
  end

  test "ID verifier accepts exact client nonce and resource bindings" do
    result = id_verifier(token: id_token).call

    assert_predicate result, :success?
    assert_equal CLIENT_ID, result.payload.fetch("aud").first
  end

  test "a successful JWKS rotation removing a known key cannot restore its stale trust" do
    now = Time.current
    fetch_count = 0
    old_jwk = JitSecurityJwtJwk.export_public(@private_key, kid: "old")
    new_jwk = JitSecurityJwtJwk.export_public(@rotated_private_key, kid: "new")
    client = OidcOpJwksClient.new(
      jwks_uri: "https://base.example/.well-known/jwks.json", clock: -> { now },
      fetcher: -> {
        fetch_count += 1
        { "keys" => [(fetch_count == 1) ? old_jwk : new_jwk] }
      },
    )

    assert_predicate client.lookup("old"), :found?
    now += OidcOpJwksClient::CACHE_TTL + 1.second

    assert_not_predicate client.lookup("old"), :found?
    assert_predicate client.lookup("new"), :found?
    assert_equal 2, fetch_count
  end

  test "JWKS outage obeys fresh and final stale trust boundaries and never trusts an unknown kid" do
    base = Time.current
    [OidcOpJwksClient::CACHE_TTL, OidcOpJwksClient::CACHE_TTL + OidcOpJwksClient::MAX_STALE_TTL].each do |limit|
      [-0.001, 0, 0.001].each do |offset|
        now = base
        fetch_count = 0
        client = OidcOpJwksClient.new(
          jwks_uri: "https://base.example/.well-known/jwks.json", clock: -> { now },
          fetcher: -> {
            fetch_count += 1
            raise OidcOpJwksClient::FetchError, "unavailable" if fetch_count > 1

            { "keys" => [JitSecurityJwtJwk.export_public(@private_key, kid: "known")] }
          },
        )

        assert_predicate client.lookup("known"), :found?
        now = base + limit + offset
        if limit + offset <= OidcOpJwksClient::CACHE_TTL + OidcOpJwksClient::MAX_STALE_TTL
          assert_predicate client.lookup("known"), :found?, "age=#{limit + offset}"
        else
          assert_not_predicate client.lookup("known"), :found?
        end

        assert_not_predicate client.lookup("unknown"), :found?
      end
    end
  end

  test "an OP key rotation during a JWKS outage is unavailable, not invalid, until a successful fetch" do
    old_jwk = public_jwk(@private_key, kid: "access-a")
    new_jwk = public_jwk(@rotated_private_key, kid: "access-b")
    outage = true
    fetch_count = 0
    now = [Time.current]
    client = jwks_client(
      fetcher: -> {
        fetch_count += 1
        next { "keys" => [old_jwk] } if fetch_count == 1
        raise OidcOpJwksClient::FetchError, "unavailable" if outage

        { "keys" => [old_jwk, new_jwk] }
      },
      limiter: local_limiter(-> { now.first }),
    )
    old_token = encode(access_payload)
    new_token = encode(access_payload, key: @rotated_private_key, kid: "access-b")
    forged_token = encode(access_payload, key: OpenSSL::PKey::RSA.generate(3072), kid: "access-a")

    assert_predicate verify_with(client, old_token), :success?
    now[0] += OidcJwksRefetchLimiter::WINDOW + 1.second

    assert_equal "key_unavailable", verify_with(client, new_token).error
    assert_equal 2, fetch_count, "a kid miss during the outage makes exactly one refetch"
    assert_predicate verify_with(client, old_token), :success?, "a failed refetch keeps the fresh cached key"
    assert_not_predicate verify_with(client, forged_token), :success?
    assert_equal "key_unavailable", verify_with(client, new_token).error, "the failed outcome holds the window"
    assert_equal 2, fetch_count

    outage = false
    now[0] += OidcJwksRefetchLimiter::WINDOW + 1.second

    assert_predicate verify_with(client, new_token), :success?
    assert_equal 3, fetch_count
  end

  test "ID verifier rejects nonce, audience, type and max-age mismatches" do
    cases = {
      "wrong nonce" => id_payload.merge("nonce" => "other-nonce"),
      "wrong audience" => id_payload.merge("aud" => ["other-client"]),
      "wrong payload type" => id_payload.merge("typ" => "at+jwt"),
      "wrong resource" => id_payload.merge("act" => "operator"),
      "stale authentication" => id_payload.merge("auth_time" => 1),
    }

    cases.each do |label, payload|
      result = id_verifier(token: encode(payload, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)).call

      assert_not_predicate result, :success?, label
    end
  end

  private

  def access_verifier(token:, fetcher: nil, clock: -> { Time.current })
    @jwks_fetches ||= 0
    OidcOpAccessTokenVerifier.new(
      access_token: token,
      client_id: CLIENT_ID,
      realm: REALM,
      issuer: ISSUER,
      audience: AUDIENCE,

      jwks_client: jwks_client(fetcher: fetcher, clock: clock),
      expected_authentication_context: "normal",
    )
  end

  def id_verifier(token:, fetcher: nil)
    OidcOpIdTokenVerifier.new(
      id_token: token,
      client_id: CLIENT_ID,
      realm: REALM,
      issuer: ISSUER,
      expected_nonce: "nonce-1",
      expected_max_age: 60,
      expected_resource_type: "client",
      jwks_client: jwks_client(fetcher:),
    )
  end

  # The Valkey half of the limiter is replaced by a connection that is always unavailable, so the
  # process-local window (same length, never "no limit") decides with the injected clock.
  class UnavailableValkey
    def key(suffix) = "test:#{suffix}"

    def call(*) = raise(Umaxica::Valkey::Unavailable, "unavailable")
  end

  def local_limiter(clock)
    OidcJwksRefetchLimiter.new(connection: UnavailableValkey.new, clock:)
  end

  def verify_with(client, token)
    OidcOpAccessTokenVerifier.new(
      access_token: token, client_id: CLIENT_ID, realm: REALM, issuer: ISSUER, audience: AUDIENCE,
      jwks_client: client, expected_authentication_context: "normal",
    ).call
  end

  def jwks_client(fetcher: nil, clock: -> { Time.current }, limiter: OidcJwksRefetchLimiter.shared)
    @jwks_fetches ||= 0
    fetcher ||=
      lambda do
        @jwks_fetches += 1
        { "keys" => [public_jwk(@private_key, kid: "access-a")] }
      end
    OidcOpJwksClient.new(
      jwks_uri: "https://base.example/.well-known/jwks.json",
      fetcher: fetcher,
      clock: clock,
      limiter: limiter,
    )
  end

  def access_token
    encode(access_payload)
  end

  def access_payload
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => [AUDIENCE],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 5,
      "sub" => "principal-1",
      "sid" => "sid-1",
      "client_id" => CLIENT_ID,
      "jti" => "jti-1",
      "scope" => "openid domain:client read:self",
      "authn_ctx" => "normal",
    }
  end

  def id_token
    encode(id_payload, typ: OidcOpIdTokenVerifier::TOKEN_TYPE)
  end

  def id_payload
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => [CLIENT_ID],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 5,
      "sub" => "principal-1",
      "nonce" => "nonce-1",
      "jti" => "jti-1",
      "sid" => "sid-1",
      "typ" => OidcOpIdTokenVerifier::TOKEN_TYPE,
      "act" => "client",
      "auth_time" => now - 5,
    }
  end

  def encode(payload, key: @private_key, kid: "access-a", typ: OidcOpAccessTokenVerifier::TOKEN_TYPE,
             header: {})
    JWT.encode(
      payload, key, OidcOpAccessTokenVerifier::ALGORITHM,
      { "kid" => kid, "alg" => OidcOpAccessTokenVerifier::ALGORITHM, "typ" => typ }.merge(header),
    )
  end

  def public_jwk(key, kid:)
    JitSecurityJwtJwk.export_public(key, kid: kid)
  end
end
