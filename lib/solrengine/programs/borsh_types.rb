require "digest"
require "base58"

module Solrengine
  module Programs
    module BorshTypes
      # Solana PublicKey: 32-byte fixed array, exposed as Base58 string
      module PublicKey
        def self.decode(buffer)
          bytes = buffer.read(32)
          Base58.binary_to_base58(bytes, :bitcoin)
        end

        def self.encode(buffer, value)
          bytes = Base58.base58_to_binary(value, :bitcoin)
          raise DeserializationError, "PublicKey must be 32 bytes (got #{bytes.bytesize})" unless bytes.bytesize == 32
          buffer.write(bytes)
        end

        def self.size
          32
        end
      end

      # Anchor discriminator: first 8 bytes of SHA256
      module Discriminator
        def self.for_account(name)
          Digest::SHA256.digest("account:#{name}")[0, 8]
        end

        def self.for_instruction(name)
          Digest::SHA256.digest("global:#{name}")[0, 8]
        end
      end

      # Maps IDL type strings to borsh gem read/write operations
      TYPE_REGISTRY = {
        "bool"   => { read: :read_bool,   write: :write_bool,   size: 1 },
        "u8"     => { read: :read_u8,     write: :write_u8,     size: 1 },
        "u16"    => { read: :read_u16,    write: :write_u16,    size: 2 },
        "u32"    => { read: :read_u32,    write: :write_u32,    size: 4 },
        "u64"    => { read: :read_u64,    write: :write_u64,    size: 8 },
        "u128"   => { read: :read_u128,   write: :write_u128,   size: 16 },
        "i8"     => { read: :read_i8,     write: :write_i8,     size: 1 },
        "i16"    => { read: :read_i16,    write: :write_i16,    size: 2 },
        "i32"    => { read: :read_i32,    write: :write_i32,    size: 4 },
        "i64"    => { read: :read_i64,    write: :write_i64,    size: 8 },
        "i128"   => { read: :read_i128,   write: :write_i128,   size: 16 },
        "f32"    => { read: :read_f32,    write: :write_f32,    size: 4 },
        "f64"    => { read: :read_f64,    write: :write_f64,    size: 8 },
        "string" => { read: :read_string, write: :write_string, size: nil },
        "pubkey" => { read: :read_pubkey, write: :write_pubkey, size: 32 }
      }.freeze

      # Read a value from a Borsh::Buffer based on IDL type
      def self.read_field(buffer, type)
        case type
        when String
          if type == "pubkey"
            PublicKey.decode(buffer)
          elsif TYPE_REGISTRY.key?(type)
            buffer.send(TYPE_REGISTRY[type][:read])
          else
            raise DeserializationError, "Unknown type: #{type}"
          end
        when Hash
          read_complex_type(buffer, type)
        else
          raise DeserializationError, "Unsupported type spec: #{type.inspect}"
        end
      end

      # Write a value to a Borsh::Buffer based on IDL type
      def self.write_field(buffer, type, value)
        case type
        when String
          if type == "pubkey"
            PublicKey.encode(buffer, value)
          elsif TYPE_REGISTRY.key?(type)
            buffer.send(TYPE_REGISTRY[type][:write], value)
          else
            raise DeserializationError, "Unknown type: #{type}"
          end
        when Hash
          write_complex_type(buffer, type, value)
        else
          raise DeserializationError, "Unsupported type spec: #{type.inspect}"
        end
      end

      # Calculate the fixed byte size for a type (nil if variable-length)
      def self.field_size(type)
        case type
        when String
          TYPE_REGISTRY.dig(type, :size)
        when Hash
          nil # complex types are variable-length
        else
          nil
        end
      end

      def self.read_complex_type(buffer, type_hash)
        if type_hash.key?("vec")
          element_type = type_hash["vec"]
          count = buffer.read_u32
          Array.new(count) { read_field(buffer, element_type) }
        elsif type_hash.key?("option")
          inner_type = type_hash["option"]
          present = buffer.read_bool
          present ? read_field(buffer, inner_type) : nil
        elsif type_hash.key?("array")
          element_type, count = type_hash["array"]
          Array.new(count) { read_field(buffer, element_type) }
        elsif type_hash.key?("defined")
          raise DeserializationError, "Custom defined types must be resolved before decoding: #{type_hash["defined"]}"
        else
          raise DeserializationError, "Unknown complex type: #{type_hash.inspect}"
        end
      end
      private_class_method :read_complex_type

      def self.write_complex_type(buffer, type_hash, value)
        if type_hash.key?("vec")
          element_type = type_hash["vec"]
          buffer.write_u32(value.size)
          value.each { |v| write_field(buffer, element_type, v) }
        elsif type_hash.key?("option")
          inner_type = type_hash["option"]
          if value.nil?
            buffer.write_bool(false)
          else
            buffer.write_bool(true)
            write_field(buffer, inner_type, value)
          end
        elsif type_hash.key?("array")
          element_type, _count = type_hash["array"]
          value.each { |v| write_field(buffer, element_type, v) }
        else
          raise DeserializationError, "Unknown complex type: #{type_hash.inspect}"
        end
      end
      private_class_method :write_complex_type

      # Encode compact-u16 (Solana's variable-length encoding for array lengths in transactions)
      def self.encode_compact_u16(value)
        bytes = []
        val = value
        loop do
          byte = val & 0x7F
          val >>= 7
          byte |= 0x80 if val > 0
          bytes << byte
          break if val == 0
        end
        bytes.pack("C*")
      end
    end
  end
end
