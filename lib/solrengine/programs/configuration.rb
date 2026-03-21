require "base58"
require "json"

module Solrengine
  module Programs
    class Configuration
      attr_accessor :keypair_format

      def initialize
        @keypair_format = :base58
      end

      def server_keypair
        @server_keypair ||= load_keypair
      end

      def server_keypair?
        !ENV["SOLANA_KEYPAIR"].nil? && !ENV["SOLANA_KEYPAIR"].empty?
      end

      private

      def load_keypair
        raw = ENV["SOLANA_KEYPAIR"]
        return nil if raw.nil? || raw.empty?

        bytes = case keypair_format
        when :base58
                  Base58.base58_to_binary(raw, :bitcoin)
        when :json_array
                  JSON.parse(raw).pack("C*")
        else
                  raise ConfigurationError, "Unsupported keypair format: #{keypair_format}"
        end

        unless bytes.bytesize == 64
          raise ConfigurationError, "Keypair must be 64 bytes (got #{bytes.bytesize})"
        end

        { secret_key: bytes[0, 32], public_key: bytes[32, 32] }
      end
    end
  end
end
