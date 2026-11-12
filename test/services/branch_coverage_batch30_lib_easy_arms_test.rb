# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJwk normalize_public and validate_public arms" do
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.normalize_public(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
        "d" => "private",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "RSA",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => "P-256",
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => "ES256",
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "enc",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
  end
end
