require "ed25519"
require "base58"
require "base64"

module Solrengine
  module Programs
    class TransactionBuilder
      def initialize
        @instructions = []
        @signers = [] # Array of { secret_key:, public_key: } hashes
        @fee_payer = nil
        @recent_blockhash = nil
      end

      def add_instruction(instruction)
        if instruction.is_a?(Instruction)
          @instructions << instruction.to_instruction
        elsif instruction.is_a?(Hash)
          @instructions << instruction
        else
          raise Error, "Instruction must be a Solrengine::Programs::Instruction or Hash"
        end
        self
      end

      def add_signer(keypair)
        @signers << keypair
        self
      end

      def set_fee_payer(pubkey)
        @fee_payer = pubkey
        self
      end

      def set_recent_blockhash(blockhash)
        @recent_blockhash = blockhash
        self
      end

      # Build the serialized transaction (signatures + message)
      def build
        resolve_blockhash! unless @recent_blockhash
        resolve_fee_payer! unless @fee_payer

        message = build_message
        signatures = sign_message(message)

        # Serialize: compact-u16 signature count + signatures + message
        result = BorshTypes.encode_compact_u16(signatures.size)
        signatures.each { |sig| result += sig }
        result += message
        result
      end

      # Build, sign, and send the transaction
      def sign_and_send(commitment: "confirmed")
        ensure_signers!

        tx_bytes = build
        tx_base64 = Base64.strict_encode64(tx_bytes)

        result = Solrengine::Rpc.client.request("sendTransaction", [
          tx_base64,
          {
            "encoding" => "base64",
            "skipPreflight" => false,
            "preflightCommitment" => commitment
          }
        ])

        if result["error"]
          raise TransactionError, "Transaction failed: #{result["error"].inspect}"
        end

        result["result"] # Returns the transaction signature
      end

      private

      def resolve_blockhash!
        bh = Solrengine::Rpc.client.get_latest_blockhash
        raise TransactionError, "Failed to fetch blockhash" unless bh
        @recent_blockhash = bh[:blockhash]
      end

      def resolve_fee_payer!
        if @signers.any?
          @fee_payer = Base58.binary_to_base58(@signers.first[:public_key], :bitcoin)
        else
          raise ConfigurationError, "Fee payer must be set or a signer must be added"
        end
      end

      def ensure_signers!
        if @signers.empty?
          keypair = Solrengine::Programs.configuration.server_keypair
          raise ConfigurationError, "Server keypair not configured. Set SOLANA_KEYPAIR environment variable." unless keypair
          @signers << keypair
        end
      end

      def build_message
        # Collect all unique account keys, ordered:
        # 1. Fee payer (always first, signer + writable)
        # 2. Other signers (writable first, then read-only)
        # 3. Non-signers (writable first, then read-only)
        account_metas = collect_account_metas
        ordered_keys = order_account_keys(account_metas)

        # Build key index lookup
        key_index = ordered_keys.each_with_index.to_h { |k, i| [ k[:pubkey], i ] }

        # Count categories
        num_required_signatures = ordered_keys.count { |k| k[:is_signer] }
        num_readonly_signed = ordered_keys.count { |k| k[:is_signer] && !k[:is_writable] }
        num_readonly_unsigned = ordered_keys.count { |k| !k[:is_signer] && !k[:is_writable] }

        # Message header (3 bytes)
        message = [ num_required_signatures, num_readonly_signed, num_readonly_unsigned ].pack("CCC")

        # Account keys (compact-u16 count + 32 bytes each)
        message += BorshTypes.encode_compact_u16(ordered_keys.size)
        ordered_keys.each do |key|
          message += Base58.base58_to_binary(key[:pubkey], :bitcoin)
        end

        # Recent blockhash (32 bytes)
        message += Base58.base58_to_binary(@recent_blockhash, :bitcoin)

        # Instructions (compact-u16 count + each instruction)
        message += BorshTypes.encode_compact_u16(@instructions.size)
        @instructions.each do |ix|
          # Program ID index (1 byte)
          prog_index = key_index[ix[:program_id]]
          message += [ prog_index ].pack("C")

          # Account indices (compact-u16 count + 1 byte each)
          acct_indices = ix[:accounts].map { |a| key_index[a[:pubkey]] }
          message += BorshTypes.encode_compact_u16(acct_indices.size)
          message += acct_indices.pack("C*")

          # Instruction data (compact-u16 length + data)
          data = ix[:data] || ""
          message += BorshTypes.encode_compact_u16(data.bytesize)
          message += data
        end

        message
      end

      def sign_message(message)
        @signers.map do |signer|
          signing_key = Ed25519::SigningKey.new(signer[:secret_key])
          signing_key.sign(message)
        end
      end

      def collect_account_metas
        metas = {}

        # Fee payer is always signer + writable
        metas[@fee_payer] = { pubkey: @fee_payer, is_signer: true, is_writable: true }

        @instructions.each do |ix|
          # Program ID is a non-signer, read-only account
          unless metas.key?(ix[:program_id])
            metas[ix[:program_id]] = { pubkey: ix[:program_id], is_signer: false, is_writable: false }
          end

          ix[:accounts].each do |acct|
            if metas.key?(acct[:pubkey])
              # Merge: upgrade to signer/writable if needed
              metas[acct[:pubkey]][:is_signer] ||= acct[:is_signer]
              metas[acct[:pubkey]][:is_writable] ||= acct[:is_writable]
            else
              metas[acct[:pubkey]] = acct.dup
            end
          end
        end

        metas.values
      end

      def order_account_keys(metas)
        # Sort order:
        # 1. Signer + writable
        # 2. Signer + read-only
        # 3. Non-signer + writable
        # 4. Non-signer + read-only
        # Fee payer is always first
        fee_payer_meta = metas.find { |m| m[:pubkey] == @fee_payer }
        others = metas.reject { |m| m[:pubkey] == @fee_payer }

        sorted = others.sort_by do |m|
          [
            m[:is_signer] ? 0 : 1,
            m[:is_writable] ? 0 : 1,
            m[:pubkey] # deterministic ordering within category
          ]
        end

        [ fee_payer_meta ] + sorted
      end
    end
  end
end
