# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_key_material"

module Jit
  module Security
    module Jwt
      class KeyMaterialTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::RSA.generate(3072)
          @encoded_key = Base64.strict_encode64(@key.private_to_der)
        end

        test "decodes base64 der RSA PKCS8 private keys" do
          key = JitSecurityJwtKeyMaterial.decode_private_key(@encoded_key)

          assert_kind_of OpenSSL::PKey::RSA, key
          assert_equal 3072, key.n.num_bits
        end

        test "decodes pem RSA private keys" do
          key = JitSecurityJwtKeyMaterial.decode_private_key(@key.private_to_pem)

          assert_kind_of OpenSSL::PKey::RSA, key
        end

        test "parses private keyset json object" do
          keyset = JitSecurityJwtKeyMaterial.parse_private_keyset(JSON.generate("kid-1" => @encoded_key))

          assert_kind_of OpenSSL::PKey::RSA, keyset.fetch("kid-1")
        end

        test "rejects malformed private keyset json" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.parse_private_keyset("{")
            end

          assert_match(/invalid JSON/, error.message)
        end

        test "rejects non object private keyset json" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.parse_private_keyset(JSON.generate([@encoded_key]))
            end

          assert_match(/JSON object/, error.message)
        end

        test "rejects invalid private key material" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.decode_private_key("not-a-key")
            end

          assert_match(/invalid RSA key material/, error.message)
        end

        test "rejects EC and undersized RSA private keys" do
          ec_key = OpenSSL::PKey::EC.generate("secp384r1")
          undersized_key = OpenSSL::PKey::RSA.generate(2048)

          [ec_key.to_pem, undersized_key.to_pem].each do |material|
            error =
              assert_raises(JitSecurityJwtKeyMaterial::Error) do
                JitSecurityJwtKeyMaterial.decode_private_key(material)
              end
            assert_match(/RSA private key with at least 3072 bits/, error.message)
          end
        end
      end
    end
  end
end
