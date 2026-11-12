# frozen_string_literal: true

require "test_helper"
require "chain_seal"

class RuntimePrimitivesRound4PublicRuntimePrimitivesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only a registered RP role can resolve a cell or its signing key names" do
    [nil, "", "shared", "rp-base-app-ww", "unknown"].each do |role|
      assert_raises(RuntimeRole::UnknownRole) { RuntimeRole.cell_connection(role) }
      assert_raises(RuntimeRole::UnknownRole) { RuntimeRole.rp_private_env_names(role) }
    end
    assert_equal "rp_palm_app", RuntimeRole.cell_connection("rp-palm-app-jp")
    keys = RuntimeRole.rp_private_env_names("rp-palm-app-jp")

    assert_equal %w(OIDC_CLIENT_PALM_APP_JP_PRIVATE_KEY JWT_PALM_APP_PRIVATE_KEY), keys
    assert_predicate keys, :frozen?
  end

  test "chain verification converts an unusable EC verification key into the public verification error" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = { "action" => "runtime-boundary" }
    seal = ChainSeal.seal(payload:, kid: "audit-key", private_key: key)
    unusable_key = OpenSSL::PKey::EC.new("secp384r1")

    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(compact: seal.compact, payload:, public_key: unusable_key)
    end
  end

  test "raw signature decoding enforces the nearest byte boundaries" do
    [95, 97].each do |length|
      assert_raises(ChainSeal::FormatError) { ChainSeal.raw_to_asn1_signature("\x01" * length) }
    end
    der = ChainSeal.raw_to_asn1_signature("\x01" * 96)
    values = OpenSSL::ASN1.decode(der).value

    assert_equal 2, values.length
    assert values.all? { |value| value.value.is_a?(OpenSSL::BN) }
  end

  test "signature wire parser rejects blank padded illegal and impossible base64 encodings" do
    [nil, "", "AA=", "+/", "x"].each do |signature|
      assert_raises(ChainSeal::FormatError) { ChainSeal.decode_signature(signature) }
    end
    assert_equal "abc=", ChainSeal.pad_base64("abc")
    assert_equal "abcd", ChainSeal.pad_base64("abcd")
    assert_not ChainSeal.secure_compare("short", "longer")
  end

  test "a signer public point on a different curve cannot verify the audit chain" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = { "action" => "curve-boundary" }
    seal = ChainSeal.seal(payload:, kid: "audit-key", private_key: key)
    foreign_point = OpenSSL::PKey::EC.generate("prime256v1").public_key

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.verify(compact: seal.compact, payload:, public_key: foreign_point)
    end
  end
end
