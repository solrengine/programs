require "base64"

module Solrengine
  module Programs
    class Account
      include ActiveModel::Model if defined?(ActiveModel)

      attr_reader :pubkey, :lamports

      class << self
        def program_id(id = nil)
          if id
            @program_id = id
          else
            @program_id
          end
        end

        # Set the Anchor account name used for discriminator computation.
        # If not set, defaults to the unqualified Ruby class name.
        def account_name(name = nil)
          if name
            @account_name = name
          else
            @account_name || self.name&.split("::")&.last
          end
        end

        def borsh_field(name, type, **options)
          borsh_fields << { name: name.to_sym, type: type, **options }

          # Define attribute accessor
          attr_accessor name
        end

        def borsh_fields
          @borsh_fields ||= []
        end

        def discriminator
          BorshTypes::Discriminator.for_account(account_name)
        end

        # Query program accounts via RPC with memcmp filters.
        # At least one user-provided filter is required to prevent unbounded queries.
        def query(filters: [], commitment: "confirmed")
          if filters.empty?
            raise Error, "At least one memcmp filter is required to prevent unbounded getProgramAccounts queries"
          end

          # Build full filter list: dataSize + discriminator + user filters
          all_filters = build_filters(filters)

          result = Solrengine::Rpc.client.request("getProgramAccounts", [
            program_id,
            {
              "encoding" => "base64",
              "commitment" => commitment,
              "filters" => all_filters
            }
          ])

          accounts = result.dig("result") || []

          accounts.filter_map do |account_data|
            pubkey = account_data["pubkey"]
            data_base64 = account_data.dig("account", "data", 0)
            lamports = account_data.dig("account", "lamports")

            next unless data_base64

            begin
              from_account_data(pubkey, data_base64, lamports: lamports)
            rescue DeserializationError, ArgumentError, RangeError => e
              if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
                Rails.logger.warn("Skipping malformed account #{pubkey}: #{e.message}")
              end
              nil
            end
          end
        end

        # Decode a single account from base64 data
        def from_account_data(pubkey, data_base64, lamports: 0)
          raw = Base64.decode64(data_base64)

          # Skip empty/closed accounts
          if raw.empty? || raw.bytesize < 8
            raise DeserializationError, "Account data too short (#{raw.bytesize} bytes)"
          end

          # Skip 8-byte discriminator
          account_data = raw[8..]
          buffer = Borsh::Buffer.new(account_data)

          instance = new
          instance.instance_variable_set(:@pubkey, pubkey)
          instance.instance_variable_set(:@lamports, lamports)

          borsh_fields.each do |field|
            value = BorshTypes.read_field(buffer, field[:type])
            instance.send(:"#{field[:name]}=", value)
          end

          instance
        end

        private

        def build_filters(user_filters)
          filters = []

          # Add dataSize filter if all fields have known sizes
          data_size = calculate_data_size
          filters << { "dataSize" => data_size } if data_size

          # Add discriminator memcmp filter
          disc = discriminator
          if disc
            disc_base58 = Base58.binary_to_base58(disc, :bitcoin)
            filters << {
              "memcmp" => {
                "offset" => 0,
                "bytes" => disc_base58,
                "encoding" => "base58"
              }
            }
          end

          filters + user_filters
        end

        def calculate_data_size
          total = 8 # discriminator
          borsh_fields.each do |field|
            size = BorshTypes.field_size(field[:type])
            return nil unless size # variable-length field makes total unknown
            total += size
          end
          total
        end
      end

      def initialize(attributes = {})
        attributes.each do |key, value|
          send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end
      end

      # SOL balance of this account
      def sol_balance
        return 0 unless lamports
        lamports.to_f / 1_000_000_000
      end
    end
  end
end
