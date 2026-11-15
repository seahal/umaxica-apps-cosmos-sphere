# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_jwk"

module Jit
  module Security
    module Jwt
      class JwkTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::RSA.generate(3072)
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "exports public jwk without private material" do
          assert_equal "kid-1", @public_jwk.fetch("kid")
          assert_equal JitSecurityJwtJwk::ALGORITHM, @public_jwk.fetch("alg")
          assert_equal "sig", @public_jwk.fetch("use")
          assert_equal "RSA", @public_jwk.fetch("kty")
          assert_empty %w(d p q dp dq qi oth k).select { |field| @public_jwk.key?(field) }
          assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & @public_jwk.keys
        end

        test "normalizes valid public jwk" do
          normalized = JitSecurityJwtJwk.normalize_public(@public_jwk.merge(extra: "ignored"))

          assert_equal @public_jwk, normalized
        end

        test "rejects public jwk with private material" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("d" => "secret"))
            end

          assert_match(/private JWK material/, error.message)
        end

        test "rejects unexpected algorithm" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("alg" => "HS256"))
            end

          assert_match(/alg must be PS256/, error.message)
        end

        test "rejects incomplete public jwk" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.except("n"))
            end

          assert_match(/missing n/, error.message)
        end

        test "imports valid public jwk material" do
          assert_kind_of OpenSSL::PKey::RSA, JitSecurityJwtJwk.import_public_key(@public_jwk)
        end

        test "rejects EC public keys and RSA keys below 3072 bits" do
          ec_key = OpenSSL::PKey::EC.generate("secp384r1")
          ec_jwk = JWT::JWK.new(ec_key, kid: "ec-kid").export.stringify_keys.except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge(
            "alg" => "PS256", "use" => "sig",
          )
          undersized_key = OpenSSL::PKey::RSA.generate(2048)
          undersized_jwk = JWT::JWK.new(undersized_key, kid: "short-rsa").export.stringify_keys.except(
            *JitSecurityJwtJwk::PRIVATE_FIELDS,
          ).merge("alg" => "PS256", "use" => "sig")

          assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public(ec_jwk) }
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(undersized_jwk)
            end
          assert_match(/3072 bits/, error.message)
        end

        test "accepts RSA public keys at 3072 and 4096 bits" do
          [@key, OpenSSL::PKey::RSA.generate(4096)].each do |key|
            jwk = JWT::JWK.new(key, kid: "sized-rsa").export.stringify_keys.except(
              *JitSecurityJwtJwk::PRIVATE_FIELDS,
            ).merge("alg" => "PS256", "use" => "sig")

            imported = JitSecurityJwtJwk.import_public_key(JitSecurityJwtJwk.normalize_public(jwk))

            assert_operator imported.n.num_bits, :>=, 3072
          end
        end
      end
    end
  end
end
