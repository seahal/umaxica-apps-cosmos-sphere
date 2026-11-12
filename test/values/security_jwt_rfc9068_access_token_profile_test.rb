# typed: false
# frozen_string_literal: true

require "test_helper"

class SecurityJwtRfc9068AccessTokenProfileTest < ActiveSupport::TestCase
  test "structural claim validation accepts scalar audiences and rejects invalid audience shapes" do
    payload = {
      "iss" => "https://issuer.example",
      "exp" => 1.hour.from_now.to_i,
      "aud" => "client-audience",
      "sub" => "subject",
      "client_id" => "client-id",
      "iat" => Time.current.to_i,
      "jti" => "token-id",
      "scope" => "domain:client",
    }

    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
    assert SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => ["client-audience"]))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => []))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => ["client", 1]))
    assert_not SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload.merge("aud" => 1))
  end
end
