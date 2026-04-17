require "digest"
require "base58"

module Solrengine
  module Programs
    module Pda
      # Ed25519 curve order
      ED25519_ORDER = 2**252 + 27742317777372353535851937790883648493

      # Find a valid Program Derived Address by iterating bump seeds from 255 down to 0.
      # Returns [address_base58, bump].
      def self.find_program_address(seeds, program_id)
        255.downto(0) do |bump|
          address = create_program_address(seeds + [ bump.chr ], program_id)
          return [ address, bump ] if address
        end

        raise Error, "Could not find a valid PDA for the given seeds"
      end

      # Create a program address from seeds. Returns nil if the address is on the Ed25519 curve.
      def self.create_program_address(seeds, program_id)
        program_id_bytes = Base58.base58_to_binary(program_id, :bitcoin)

        hash_input = seeds.map { |s| seed_bytes(s) }.join
        hash_input += program_id_bytes
        hash_input += "ProgramDerivedAddress"

        hash = Digest::SHA256.digest(hash_input)

        # Reject if the hash is a valid Ed25519 point (on-curve)
        return nil if on_curve?(hash)

        Base58.binary_to_base58(hash, :bitcoin)
      end

      # Map an IDL-declared argument type string to the symbol to_seed expects.
      # Unknown or composite types fall back to :raw.
      IDL_SEED_TYPES = {
        "u8" => :u8,
        "u16" => :u16,
        "u32" => :u32,
        "u64" => :u64,
        "string" => :string,
        "pubkey" => :pubkey,
        "publicKey" => :pubkey,
        "bytes" => :raw
      }.freeze

      def self.seed_type_for_idl(idl_type)
        IDL_SEED_TYPES[idl_type] || :raw
      end

      # Convert a value to seed bytes based on type
      def self.to_seed(value, type = :raw)
        case type
        when :string
          value.encode("UTF-8").b
        when :pubkey
          Base58.base58_to_binary(value, :bitcoin)
        when :u8
          [ value ].pack("C")
        when :u16
          [ value ].pack("v")
        when :u32
          [ value ].pack("V")
        when :u64
          [ value ].pack("Q<")
        when :raw
          value.is_a?(String) ? value.b : value
        else
          raise Error, "Unknown seed type: #{type}"
        end
      end

      # Check if a 32-byte hash is on the Ed25519 curve (matches Solana's
      # is_on_curve check for PDA rejection).
      #
      # Ed25519 compressed-Edwards-Y encoding uses the top bit of byte 31 as
      # the x-sign, leaving 255 bits for y. The sign bit MUST be stripped
      # before interpreting y, otherwise the on-curve check diverges from
      # curve25519-dalek's decompression for ~50% of inputs.
      def self.on_curve?(bytes)
        bytes_arr = bytes.unpack("C*")
        bytes_arr[31] &= 0x7F # strip Ed25519 sign bit
        y = bytes_arr.each_with_index.sum { |byte, i| byte << (8 * i) }

        p = 2**255 - 19
        return false if y >= p # non-canonical y

        y_squared = y * y

        # x² = (y² - 1) / (d·y² + 1) mod p, where d = -121665/121666 mod p
        d = (-121665 * mod_inverse(121666, p)) % p
        numerator = (y_squared - 1) % p
        denominator = (d * y_squared + 1) % p
        return false if denominator == 0

        x_squared = (numerator * mod_inverse(denominator, p)) % p
        return true if x_squared == 0 # x = 0 is trivially on-curve

        # Euler's criterion: x² is a quadratic residue iff x²^((p-1)/2) ≡ 1 (mod p)
        x_squared.pow((p - 1) / 2, p) == 1
      end
      private_class_method :on_curve?

      def self.mod_inverse(a, m)
        a.pow(m - 2, m)
      end
      private_class_method :mod_inverse

      def self.seed_bytes(seed)
        if seed.is_a?(String)
          seed.b
        elsif seed.is_a?(Array)
          seed.pack("C*")
        else
          seed.to_s.b
        end
      end
      private_class_method :seed_bytes
    end
  end
end
