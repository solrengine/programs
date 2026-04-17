require "test_helper"

class TestLockInstruction < Solrengine::Programs::Instruction
  program_id "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
  instruction_name "lock"

  argument :amt, "u64"
  argument :exp, "u64"

  account :payer, signer: true, writable: true
  account :dst
  account :lock, signer: true, writable: true
  account :system_program, address: "11111111111111111111111111111111"
end

class TestUnlockInstruction < Solrengine::Programs::Instruction
  program_id "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
  instruction_name "unlock"

  account :lock, writable: true
  account :dst, writable: true
end

class TestInitializeCandidateInstruction < Solrengine::Programs::Instruction
  program_id "2F1Z4eTmFqbjAnNWaDXXScoBYLMFn1gTasVy2mfPTeJx"
  instruction_name "initialize_candidate"

  argument :poll_id, "u64"
  argument :candidate, "string"

  account :signer, signer: true, writable: true
  account :poll_account, writable: true, pda: [
    { const: [ 112, 111, 108, 108 ] },
    { arg: :poll_id, type: :u64 }
  ]
  account :candidate_account, writable: true, pda: [
    { arg: :poll_id, type: :u64 },
    { arg: :candidate, type: :string }
  ]
  account :system_program, address: "11111111111111111111111111111111"
end

class Solrengine::Programs::InstructionTest < Minitest::Test
  def test_program_id
    assert_equal "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN", TestLockInstruction.program_id
  end

  def test_arguments_list
    args = TestLockInstruction.arguments_list
    assert_equal 2, args.size
    assert_equal :amt, args[0][:name]
    assert_equal "u64", args[0][:type]
  end

  def test_accounts_list
    accts = TestLockInstruction.accounts_list
    assert_equal 4, accts.size
    assert_equal :system_program, accts[3][:name]
    assert_equal "11111111111111111111111111111111", accts[3][:address]
  end

  def test_discriminator
    disc = TestLockInstruction.discriminator
    assert_equal 8, disc.bytesize

    # Should match IDL lock discriminator
    expected = [ 21, 19, 208, 43, 237, 62, 255, 87 ].pack("C*")
    assert_equal expected, disc
  end

  def test_instruction_name
    assert_equal "lock", TestLockInstruction.anchor_instruction_name
    assert_equal "unlock", TestUnlockInstruction.anchor_instruction_name
  end

  def test_instruction_data_encodes_discriminator_and_args
    ix = TestLockInstruction.new(
      amt: 100_000_000,
      exp: 1700000000,
      payer: "PayerPubkey",
      dst: "DstPubkey",
      lock: "LockPubkey"
    )

    data = ix.instruction_data

    # Should be 8 (discriminator) + 8 (u64 amt) + 8 (u64 exp) = 24 bytes
    assert_equal 24, data.bytesize

    # First 8 bytes should be the lock discriminator
    disc = data[0, 8]
    assert_equal TestLockInstruction.discriminator, disc

    # Next 8 bytes: amt as u64 LE
    amt = data[8, 8].unpack("Q<").first
    assert_equal 100_000_000, amt

    # Next 8 bytes: exp as u64 LE
    exp = data[16, 8].unpack("Q<").first
    assert_equal 1700000000, exp
  end

  def test_to_instruction
    ix = TestLockInstruction.new(
      amt: 100,
      exp: 200,
      payer: "PayerKey",
      dst: "DstKey",
      lock: "LockKey"
    )

    result = ix.to_instruction

    assert_equal "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN", result[:program_id]
    assert_equal 4, result[:accounts].size
    assert result[:data].is_a?(String)

    # Verify account metas
    payer_meta = result[:accounts][0]
    assert_equal "PayerKey", payer_meta[:pubkey]
    assert payer_meta[:is_signer]
    assert payer_meta[:is_writable]

    system_meta = result[:accounts][3]
    assert_equal "11111111111111111111111111111111", system_meta[:pubkey]
    refute system_meta[:is_signer]
    refute system_meta[:is_writable]
  end

  def test_valid_with_all_fields
    ix = TestLockInstruction.new(
      amt: 100,
      exp: 200,
      payer: "PayerKey",
      dst: "DstKey",
      lock: "LockKey"
    )

    assert ix.valid?
    assert_empty ix.errors
  end

  def test_invalid_missing_argument
    ix = TestLockInstruction.new(
      exp: 200,
      payer: "PayerKey",
      dst: "DstKey",
      lock: "LockKey"
    )

    refute ix.valid?
    assert ix.errors.any? { |e| e.include?("amt") }
  end

  def test_invalid_missing_account
    ix = TestLockInstruction.new(
      amt: 100,
      exp: 200,
      payer: "PayerKey"
    )

    refute ix.valid?
    assert ix.errors.any? { |e| e.include?("dst") }
  end

  def test_pda_account_has_no_attr_accessor
    refute TestInitializeCandidateInstruction.instance_methods.include?(:poll_account)
    refute TestInitializeCandidateInstruction.instance_methods.include?(:candidate_account)
    assert TestInitializeCandidateInstruction.instance_methods.include?(:signer)
  end

  def test_pda_account_skips_validation
    ix = TestInitializeCandidateInstruction.new(
      poll_id: 1,
      candidate: "alpha",
      signer: "SignerPubkey"
    )
    assert ix.valid?, "expected PDA-only accounts not to require explicit addresses; errors: #{ix.errors}"
  end

  def test_pda_derivation_is_deterministic
    ix1 = TestInitializeCandidateInstruction.new(
      poll_id: 1,
      candidate: "alpha",
      signer: "11111111111111111111111111111111"
    )
    ix2 = TestInitializeCandidateInstruction.new(
      poll_id: 1,
      candidate: "alpha",
      signer: "11111111111111111111111111111111"
    )
    metas1 = ix1.to_instruction[:accounts]
    metas2 = ix2.to_instruction[:accounts]
    assert_equal metas1[1][:pubkey], metas2[1][:pubkey]
    assert_equal metas1[2][:pubkey], metas2[2][:pubkey]
  end

  def test_pda_derivation_changes_with_seed_value
    ix1 = TestInitializeCandidateInstruction.new(
      poll_id: 1, candidate: "alpha",
      signer: "11111111111111111111111111111111"
    )
    ix2 = TestInitializeCandidateInstruction.new(
      poll_id: 2, candidate: "alpha",
      signer: "11111111111111111111111111111111"
    )
    poll_acct_1 = ix1.to_instruction[:accounts][1][:pubkey]
    poll_acct_2 = ix2.to_instruction[:accounts][1][:pubkey]
    refute_equal poll_acct_1, poll_acct_2
  end

  def test_pda_derivation_produces_base58_address
    ix = TestInitializeCandidateInstruction.new(
      poll_id: 42, candidate: "alpha",
      signer: "11111111111111111111111111111111"
    )
    metas = ix.to_instruction[:accounts]
    poll_pubkey = metas[1][:pubkey]
    assert_kind_of String, poll_pubkey
    assert poll_pubkey.length.between?(32, 44)
    refute_equal "", poll_pubkey
  end

  def test_unlock_instruction_no_args
    ix = TestUnlockInstruction.new(
      lock: "LockKey",
      dst: "DstKey"
    )

    data = ix.instruction_data
    # Only discriminator, no args
    assert_equal 8, data.bytesize
  end
end
