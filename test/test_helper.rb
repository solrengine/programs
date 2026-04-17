# frozen_string_literal: true

require "minitest/autorun"
require "solrengine/programs"

# Stub Solrengine::Rpc for tests
module Solrengine
  module Rpc
    class StubClient
      attr_accessor :responses

      def initialize
        @responses = {}
      end

      def request(method, params = [])
        @responses[method] || {}
      end

      def get_latest_blockhash(commitment: "finalized")
        {
          blockhash: "EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N",
          last_valid_block_height: 100_000
        }
      end
    end

    @stub_client = StubClient.new

    def self.client(rpc_url: nil)
      @stub_client
    end

    def self.stub_client
      @stub_client
    end

    def self.configuration
      @configuration ||= Struct.new(:rpc_url, :network).new(
        "https://api.devnet.solana.com",
        "devnet"
      )
    end
  end
end

# Test helpers
module TestFixtures
  def fixture_path(name)
    File.join(File.dirname(__FILE__), "fixtures", name)
  end

  def piggy_bank_idl_json
    File.read(fixture_path("piggy_bank_idl.json"))
  end

  def piggy_bank_idl
    @piggy_bank_idl ||= Solrengine::Programs::IdlParser.parse(piggy_bank_idl_json)
  end

  def voting_idl_json
    File.read(fixture_path("voting_idl.json"))
  end

  def voting_idl
    @voting_idl ||= Solrengine::Programs::IdlParser.parse(voting_idl_json)
  end

  # Generate a mock Lock account data (8-byte discriminator + 32-byte pubkey + 8-byte u64)
  def mock_lock_account_data(dst_pubkey: "11111111111111111111111111111111", exp: 1700000000)
    discriminator = Solrengine::Programs::BorshTypes::Discriminator.for_account("Lock")
    dst_bytes = Base58.base58_to_binary(dst_pubkey, :bitcoin)
    exp_bytes = [ exp ].pack("Q<")
    Base64.strict_encode64(discriminator + dst_bytes + exp_bytes)
  end
end
