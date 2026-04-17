require "test_helper"

class Solrengine::Programs::IdlParserTest < Minitest::Test
  include TestFixtures

  def test_parse_piggy_bank_idl
    idl = piggy_bank_idl

    assert_equal "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN", idl.program_id
    assert_equal "piggy_bank", idl.name
    assert_equal "0.1.0", idl.version
  end

  def test_parse_instructions
    idl = piggy_bank_idl

    assert_equal 2, idl.instructions.size

    lock = idl.instructions.find { |ix| ix.name == "lock" }
    assert lock
    assert_equal 8, lock.discriminator.bytesize
    assert_equal 4, lock.accounts.size
    assert_equal 2, lock.args.size

    # Verify lock args
    assert_equal "amt", lock.args[0].name
    assert_equal "u64", lock.args[0].type
    assert_equal "exp", lock.args[1].name
    assert_equal "u64", lock.args[1].type

    # Verify lock accounts
    payer = lock.accounts.find { |a| a.name == "payer" }
    assert payer.signer
    assert payer.writable

    system_prog = lock.accounts.find { |a| a.name == "system_program" }
    assert_equal "11111111111111111111111111111111", system_prog.address

    unlock = idl.instructions.find { |ix| ix.name == "unlock" }
    assert unlock
    assert_equal 0, unlock.args.size
    assert_equal 2, unlock.accounts.size
  end

  def test_parse_accounts
    idl = piggy_bank_idl

    assert_equal 1, idl.accounts.size

    lock = idl.accounts.first
    assert_equal "Lock", lock.name
    assert_equal 8, lock.discriminator.bytesize
    assert_equal 2, lock.fields.size
    assert_equal "dst", lock.fields[0].name
    assert_equal "pubkey", lock.fields[0].type
    assert_equal "exp", lock.fields[1].name
    assert_equal "u64", lock.fields[1].type
  end

  def test_parse_errors
    idl = piggy_bank_idl

    assert_equal 3, idl.errors.size

    invalid_amount = idl.errors.find { |e| e.name == "InvalidAmount" }
    assert_equal 6000, invalid_amount.code
    assert_equal "Amount must be greater than 0", invalid_amount.message

    lock_not_expired = idl.errors.find { |e| e.name == "LockNotExpired" }
    assert_equal 6002, lock_not_expired.code
  end

  def test_parse_types
    idl = piggy_bank_idl

    assert_equal 1, idl.types.size

    lock_type = idl.types.first
    assert_equal "Lock", lock_type.name
    assert_equal "struct", lock_type.kind
    assert_equal 2, lock_type.fields.size
  end

  def test_unsupported_version_raises
    bad_idl = '{"metadata": {"name": "test", "version": "1.0.0", "spec": "0.0.0"}}'

    assert_raises(Solrengine::Programs::IdlParser::UnsupportedVersionError) do
      Solrengine::Programs::IdlParser.parse(bad_idl)
    end
  end

  def test_parse_file
    idl = Solrengine::Programs::IdlParser.parse_file(fixture_path("piggy_bank_idl.json"))
    assert_equal "piggy_bank", idl.name
  end

  def test_piggy_bank_accounts_have_no_pda_metadata
    idl = piggy_bank_idl
    lock_ix = idl.instructions.find { |ix| ix.name == "lock" }
    lock_ix.accounts.each do |acct|
      assert_nil acct.pda, "expected #{acct.name} to have no pda metadata"
    end
  end

  def test_parse_voting_idl_instructions_have_pda_seeds
    idl = voting_idl

    assert_equal "2F1Z4eTmFqbjAnNWaDXXScoBYLMFn1gTasVy2mfPTeJx", idl.program_id
    assert_equal "voting", idl.name

    init_poll = idl.instructions.find { |ix| ix.name == "initialize_poll" }
    poll_account = init_poll.accounts.find { |a| a.name == "poll_account" }
    assert poll_account.pda, "expected poll_account to have pda metadata"
    assert_equal 2, poll_account.pda.size

    const_seed = poll_account.pda[0]
    assert_equal "const", const_seed.kind
    assert_equal [ 112, 111, 108, 108 ], const_seed.value # "poll"

    arg_seed = poll_account.pda[1]
    assert_equal "arg", arg_seed.kind
    assert_equal "poll_id", arg_seed.path
  end

  def test_parse_voting_candidate_has_two_arg_seeds
    idl = voting_idl
    init_candidate = idl.instructions.find { |ix| ix.name == "initialize_candidate" }
    candidate_account = init_candidate.accounts.find { |a| a.name == "candidate_account" }

    assert_equal 2, candidate_account.pda.size
    assert_equal "arg", candidate_account.pda[0].kind
    assert_equal "poll_id", candidate_account.pda[0].path
    assert_equal "arg", candidate_account.pda[1].kind
    assert_equal "candidate", candidate_account.pda[1].path
  end

  def test_parse_voting_signer_account_has_no_pda
    idl = voting_idl
    init_poll = idl.instructions.find { |ix| ix.name == "initialize_poll" }
    signer = init_poll.accounts.find { |a| a.name == "signer" }
    assert_nil signer.pda
    assert signer.signer
    assert signer.writable
  end

  def test_discriminators_match_idl_values
    idl = piggy_bank_idl

    # Lock account discriminator from IDL: [8, 255, 36, 202, 210, 22, 57, 137]
    lock_account = idl.accounts.first
    expected_bytes = [ 8, 255, 36, 202, 210, 22, 57, 137 ].pack("C*")
    assert_equal expected_bytes, lock_account.discriminator

    # Lock instruction discriminator from IDL: [21, 19, 208, 43, 237, 62, 255, 87]
    lock_ix = idl.instructions.find { |ix| ix.name == "lock" }
    expected_ix_bytes = [ 21, 19, 208, 43, 237, 62, 255, 87 ].pack("C*")
    assert_equal expected_ix_bytes, lock_ix.discriminator

    # Verify our computed discriminators match
    computed_account = Solrengine::Programs::BorshTypes::Discriminator.for_account("Lock")
    assert_equal lock_account.discriminator, computed_account

    computed_ix = Solrengine::Programs::BorshTypes::Discriminator.for_instruction("lock")
    assert_equal lock_ix.discriminator, computed_ix
  end
end
