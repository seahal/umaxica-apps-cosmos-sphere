# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"

class SecurityJwtPreferenceTokenCodecClaimsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PREFERENCES = {
    "theme" => "dark",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  test "a genuine app realm token carries only the current closed claims" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    public_id = PublicId.generate
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: public_id,
                   jti: SecureRandom.uuid, jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)

    assert_equal "JWT", header.fetch("typ")
    assert_equal "ES384", header.fetch("alg")
    assert_equal %w(aud exp iat iss jti preferences sub), claims.keys.sort
    assert_equal "app", claims.fetch("aud")
    assert_equal public_id, claims.fetch("sub")
    assert_equal PREFERENCES, claims.fetch("preferences")
    assert_operator token.bytesize, :<=, SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
    assert_equal claims, PreferenceToken.decode(token, host: host, jwt_issuer_id: "preference_app")
    assert_equal public_id, PreferenceToken.extract_public_id(claims)
    assert_nil PreferenceToken.extract_public_id({ "public_id" => "retired-row-id" })
  end

  test "legacy app and org claim shapes have no reader" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row-id",
                   jti: "app-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    old_claim_shapes = [
      claims.merge("preference_type" => "AppPreference"),
      claims.merge("client_id" => "legacy-client"),
      claims.merge("scope" => "preference"),
      claims.merge("public_id" => "legacy-row-id"),
    ]

    old_claim_shapes.each do |old_claims|
      legacy_token = JWT.encode(old_claims, key, header.fetch("alg"), header.except("alg"))

      assert_nil PreferenceToken.decode(legacy_token, host: host, jwt_issuer_id: "preference_app")
    end
  end

  test "a token signed by another realm key is reported as a signature failure" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row-id",
                   jti: "app-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    forged = JWT.encode(
      claims, OpenSSL::PKey::EC.generate("secp384r1"), header.fetch("alg"), header.except("alg"),
    )
    reported_reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**event) { reported_reasons << event.fetch(:reason) }) do
      assert_nil PreferenceToken.decode(forged, host: host, jwt_issuer_id: "preference_app")
    end

    assert_includes reported_reasons, "SIGNATURE_INVALID"
  end

  test "unsupported preference models and snapshots are refused without logging their values" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    errors = []
    invalid_preferences = PREFERENCES.merge("unknown_option" => "private-preference-value")

    Rails.logger.stub(:error, ->(event) { errors << event }) do
      assert_nil SecurityJwtPreferenceTokenCodec.encode(
        PREFERENCES, host: host, preference_type: "UnknownPreference", public_id: "app-row",
                     jti: "generation", issued_at: Time.current,
      )
      assert_nil SecurityJwtPreferenceTokenCodec.encode(
        invalid_preferences, host: host, preference_type: "AppPreference", public_id: "app-row",
                             jti: "generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
      )
    end

    assert_equal 2, errors.length
    errors.each do |event|
      record = JSON.parse(event)

      assert_equal "preference.token.encoding_failed", record.fetch("event")
      assert_equal "ArgumentError", record.dig("data", "error_class")
      assert_not_includes event, "private-preference-value"
    end
  end

  test "preference snapshots encode and decode for the COM and ORG realms" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    [
      ["ComPreference", hosts.base_corporate.host, "preference_com", "com"],
      ["OrgPreference", hosts.base_staff.host, "preference_org", "org"],
    ].each do |preference_type, host, issuer_id, realm|
      token = SecurityJwtPreferenceTokenCodec.encode(
        PREFERENCES, host: host, preference_type: preference_type, public_id: "#{realm}-row",
                     jti: "#{realm}-generation", jwt_issuer_id: issuer_id, issued_at: Time.current,
      )

      assert_predicate token, :present?, realm
      payload = SecurityJwtPreferenceTokenCodec.decode(token, host: host, jwt_issuer_id: issuer_id)

      assert_equal realm, payload.fetch("aud")
      assert_equal "#{realm}-row", payload.fetch("sub")
      assert_equal PREFERENCES, payload.fetch("preferences")
    end
  end

  test "public snapshot and extraction helpers preserve only the anonymous realm contract" do
    assert SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(PREFERENCES)
    assert_not SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(PREFERENCES.except("theme"))
    assert_not SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(PREFERENCES.merge("theme" => "unknown"))
    assert_not SecurityJwtPreferenceTokenCodec.valid_display_snapshot?(PREFERENCES.merge("extra" => "value"))

    payload = { "aud" => "app", "sub" => "app-row", "jti" => "generation", "preferences" => PREFERENCES }

    assert_equal PREFERENCES, SecurityJwtPreferenceTokenCodec.extract_preferences(payload)
    assert_equal({}, SecurityJwtPreferenceTokenCodec.extract_preferences({ "preferences" => false }))
    assert_equal({}, SecurityJwtPreferenceTokenCodec.extract_preferences(nil))
    assert_equal "app-row", SecurityJwtPreferenceTokenCodec.extract_public_id(payload)
    assert_nil SecurityJwtPreferenceTokenCodec.extract_public_id({ "aud" => "other", "sub" => "row" })
    assert_nil SecurityJwtPreferenceTokenCodec.extract_public_id(nil)
    assert_equal "generation", SecurityJwtPreferenceTokenCodec.extract_jti(payload)
    assert_nil SecurityJwtPreferenceTokenCodec.extract_jti(nil)
  end

  test "wrong realm issuers and ambiguous or oversized tokens are rejected" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                   jti: "generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )

    assert_nil SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: "org.localhost", preference_type: "AppPreference", public_id: "app-row",
                   jti: "generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "org.localhost")
    [nil, "", "not-a-jwt", "e30.%%%.signature", "e30.e30.AAA"].each do |malformed_token|
      assert_nil SecurityJwtPreferenceTokenCodec.decode(malformed_token, host: host)
    end

    maximum = SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
    jti = "x" * 1750
    accepted_token = nil
    oversized_token = nil
    while accepted_token.nil? || accepted_token.bytesize <= maximum
      candidate = SecurityJwtPreferenceTokenCodec.encode(
        PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                     jti: jti, jwt_issuer_id: "preference_app", issued_at: Time.current,
      )
      if candidate && candidate.bytesize <= maximum
        accepted_token = candidate
        jti << "x"
      else
        oversized_token = candidate
        break
      end
    end

    assert_operator accepted_token.bytesize, :<=, maximum
    assert_operator accepted_token.bytesize, :>=, maximum - 2
    assert_nil oversized_token
    assert_nil SecurityJwtPreferenceTokenCodec.decode("x" * (maximum + 1), host: host)
  end

  test "audience mismatches can be returned or raised through the public decoder" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                   jti: "generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    claims["aud"] = "com"
    mismatched = JWT.encode(claims, key, header.fetch("alg"), header.except("alg"))

    assert_nil SecurityJwtPreferenceTokenCodec.decode(mismatched, host: host)
    assert_raises(SecurityJwtPreferenceTokenCodec::AudienceMismatchError) do
      SecurityJwtPreferenceTokenCodec.decode(mismatched, host: host, raise_on_audience_mismatch: true)
    end
  end

  test "expired tokens and unknown key identifiers are rejected with classified anomaly events" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    expired = SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                   jti: "expired-generation", jwt_issuer_id: "preference_app",
                   issued_at: Time.current - SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL - 1.day,
    )
    valid = SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                   jti: "unknown-kid-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(valid, nil, false)
    signing_key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    unknown_kid = JWT.encode(
      claims, signing_key, header.fetch("alg"), header.except("alg").merge("kid" => "unknown-kid"),
    )
    reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**event) { reasons << event.fetch(:reason) }) do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(expired, host: host)
      assert_nil SecurityJwtPreferenceTokenCodec.decode(unknown_kid, host: host)
      assert_nil SecurityJwtPreferenceTokenCodec.decode(valid, host: host, jwt_issuer_id: "preference_com")
    end

    assert_includes reasons, "EXPIRED"
    assert_includes reasons, "UNKNOWN_KID"
  end

  test "missing required claims and future time claims are rejected with anomaly reasons" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = SecurityJwtPreferenceTokenCodec.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row",
                   jti: "claims-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    signing_key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    jwt_header = header.except("alg")
    missing_jti = JWT.encode(claims.except("jti"), signing_key, header.fetch("alg"), jwt_header)
    now = Time.current.to_i
    future_iat = JWT.encode(
      claims.merge("iat" => now + 300, "exp" => now + 300 + SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL.to_i),
      signing_key,
      header.fetch("alg"),
      jwt_header,
    )
    future_nbf = JWT.encode(claims.merge("nbf" => now + 300), signing_key, header.fetch("alg"), jwt_header)
    reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**event) { reasons << event.fetch(:reason) }) do
      [missing_jti, future_iat, future_nbf].each do |invalid_token|
        assert_nil SecurityJwtPreferenceTokenCodec.decode(invalid_token, host: host)
      end
    end

    assert_equal %w(OTHER IAT_INVALID IMMATURE), reasons
  end
end
