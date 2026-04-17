module Solrengine
  module Programs
    class Instruction
      attr_reader :errors

      class << self
        def program_id(id = nil)
          if id
            @program_id = id
          else
            @program_id
          end
        end

        def argument(name, type)
          arguments_list << { name: name.to_sym, type: type }
          attr_accessor name
        end

        def account(name, signer: false, writable: false, address: nil, pda: nil)
          accounts_list << {
            name: name.to_sym,
            signer: signer,
            writable: writable,
            address: address,
            pda: pda
          }
          attr_accessor name unless address || pda
        end

        def arguments_list
          @arguments_list ||= []
        end

        def accounts_list
          @accounts_list ||= []
        end

        def discriminator
          BorshTypes::Discriminator.for_instruction(anchor_instruction_name)
        end

        # Set the Anchor instruction name used for discriminator computation.
        # If not set, derives from class name: "LockInstruction" -> "lock"
        def instruction_name(name_override = nil)
          if name_override
            @instruction_name = name_override
          else
            @instruction_name
          end
        end

        def anchor_instruction_name
          @instruction_name || begin
            short_name = name&.split("::")&.last || ""
            short_name.sub(/Instruction$/, "").gsub(/([a-z])([A-Z])/, '\1_\2').downcase
          end
        end
      end

      def initialize(attributes = {})
        @errors = []
        attributes.each do |key, value|
          send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end
      end

      def valid?
        @errors = []
        validate_arguments
        validate_accounts
        @errors.empty?
      end

      # Build the instruction data: 8-byte discriminator + Borsh-encoded arguments
      def instruction_data
        data = Borsh::Buffer.open do |buf|
          # Write discriminator
          buf.write(self.class.discriminator)

          # Write each argument
          self.class.arguments_list.each do |arg|
            value = send(arg[:name])
            BorshTypes.write_field(buf, arg[:type], value)
          end
        end

        data
      end

      # Build the instruction hash suitable for TransactionBuilder
      def to_instruction
        {
          program_id: self.class.program_id,
          accounts: build_account_metas,
          data: instruction_data
        }
      end

      private

      def validate_arguments
        self.class.arguments_list.each do |arg|
          value = send(arg[:name])
          if value.nil?
            @errors << "#{arg[:name]} is required"
          end
        end
      end

      def validate_accounts
        self.class.accounts_list.each do |acct|
          next if acct[:address] # static addresses don't need to be set
          next if acct[:pda]     # PDA-derived accounts are computed, not set
          value = send(acct[:name])
          if value.nil?
            @errors << "Account #{acct[:name]} is required"
          end
        end
      end

      def build_account_metas
        self.class.accounts_list.map do |acct|
          pubkey = if acct[:address]
            acct[:address]
          elsif acct[:pda]
            derive_pda(acct[:pda])
          else
            send(acct[:name])
          end

          {
            pubkey: pubkey,
            is_signer: acct[:signer],
            is_writable: acct[:writable]
          }
        end
      end

      def derive_pda(seed_specs)
        seeds = seed_specs.map { |spec| resolve_seed(spec) }
        address, _bump = Pda.find_program_address(seeds, self.class.program_id)
        address
      end

      def resolve_seed(spec)
        if spec.key?(:const)
          spec[:const].pack("C*")
        elsif spec.key?(:arg)
          value = send(spec[:arg])
          Pda.to_seed(value, spec[:type] || :raw)
        else
          raise Error, "Unknown PDA seed spec: #{spec.inspect}"
        end
      end
    end
  end
end
