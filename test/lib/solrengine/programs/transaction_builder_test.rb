require "test_helper"

class Solrengine::Programs::TransactionBuilderTest < Minitest::Test
  def setup
    @keypair = generate_test_keypair
  end

  def test_build_produces_valid_bytes
    builder = Solrengine::Programs::TransactionBuilder.new
    builder.add_signer(@keypair)
    builder.set_recent_blockhash("EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N")

    instruction = {
      program_id: "11111111111111111111111111111111",
      accounts: [
        { pubkey: pubkey_from_keypair(@keypair), is_signer: true, is_writable: true }
      ],
      data: "\x00" * 8
    }
    builder.add_instruction(instruction)

    tx_bytes = builder.build

    # First byte should be compact-u16 for signature count (1 = 0x01)
    assert_equal 1, tx_bytes.bytes[0]
    # Next 64 bytes should be the signature
    assert tx_bytes.bytesize > 65
  end

  def test_build_with_instruction_object
    ix_class = Class.new(Solrengine::Programs::Instruction) do
      program_id "11111111111111111111111111111111"
      instruction_name "test"
      argument :value, "u64"
      account :owner, signer: true, writable: true
    end

    ix = ix_class.new(value: 42, owner: pubkey_from_keypair(@keypair))

    builder = Solrengine::Programs::TransactionBuilder.new
    builder.add_signer(@keypair)
    builder.set_recent_blockhash("EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N")
    builder.add_instruction(ix)

    tx_bytes = builder.build
    assert tx_bytes.bytesize > 0
  end

  def test_fee_payer_defaults_to_first_signer
    builder = Solrengine::Programs::TransactionBuilder.new
    builder.add_signer(@keypair)
    builder.set_recent_blockhash("EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N")
    builder.add_instruction({
      program_id: "11111111111111111111111111111111",
      accounts: [],
      data: ""
    })

    # Should not raise — fee payer resolved from signer
    tx = builder.build
    assert tx.bytesize > 0
  end

  def test_no_signer_raises_on_sign_and_send
    # Clear any configured keypair
    Solrengine::Programs.configuration.instance_variable_set(:@server_keypair, nil)
    original_env = ENV["SOLANA_KEYPAIR"]
    ENV["SOLANA_KEYPAIR"] = nil

    builder = Solrengine::Programs::TransactionBuilder.new
    builder.set_recent_blockhash("EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N")
    builder.add_instruction({
      program_id: "11111111111111111111111111111111",
      accounts: [],
      data: ""
    })

    assert_raises(Solrengine::Programs::ConfigurationError) do
      builder.sign_and_send
    end
  ensure
    ENV["SOLANA_KEYPAIR"] = original_env
  end

  def test_chain_methods
    builder = Solrengine::Programs::TransactionBuilder.new
    result = builder.add_signer(@keypair)
      .set_fee_payer(pubkey_from_keypair(@keypair))
      .set_recent_blockhash("EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N")
      .add_instruction({
        program_id: "11111111111111111111111111111111",
        accounts: [],
        data: ""
      })

    assert_kind_of Solrengine::Programs::TransactionBuilder, result
  end

  private

  def generate_test_keypair
    signing_key = Ed25519::SigningKey.generate
    {
      secret_key: signing_key.to_bytes,
      public_key: signing_key.verify_key.to_bytes
    }
  end

  def pubkey_from_keypair(keypair)
    Base58.binary_to_base58(keypair[:public_key], :bitcoin)
  end
end
