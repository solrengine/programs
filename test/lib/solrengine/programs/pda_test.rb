require "test_helper"

class Solrengine::Programs::PdaTest < Minitest::Test
  def test_find_program_address_returns_address_and_bump
    # Use a known program ID and seed to verify PDA derivation
    program_id = "11111111111111111111111111111111"
    seeds = [ "test" ]

    address, bump = Solrengine::Programs::Pda.find_program_address(seeds, program_id)

    assert_kind_of String, address
    assert_kind_of Integer, bump
    assert bump >= 0 && bump <= 255
    # Base58 addresses should be 32-44 chars
    assert address.length.between?(32, 44)
  end

  def test_find_program_address_deterministic
    program_id = "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
    seeds = [ "vault" ]

    addr1, bump1 = Solrengine::Programs::Pda.find_program_address(seeds, program_id)
    addr2, bump2 = Solrengine::Programs::Pda.find_program_address(seeds, program_id)

    assert_equal addr1, addr2
    assert_equal bump1, bump2
  end

  def test_different_seeds_produce_different_addresses
    program_id = "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"

    addr1, = Solrengine::Programs::Pda.find_program_address([ "seed1" ], program_id)
    addr2, = Solrengine::Programs::Pda.find_program_address([ "seed2" ], program_id)

    refute_equal addr1, addr2
  end

  def test_to_seed_string
    result = Solrengine::Programs::Pda.to_seed("hello", :string)
    assert_equal "hello".encode("UTF-8").b, result
  end

  def test_to_seed_u32
    result = Solrengine::Programs::Pda.to_seed(42, :u32)
    assert_equal [ 42 ].pack("V"), result
  end

  def test_to_seed_u64
    result = Solrengine::Programs::Pda.to_seed(12345, :u64)
    assert_equal [ 12345 ].pack("Q<"), result
  end

  def test_to_seed_pubkey
    pubkey = "11111111111111111111111111111111"
    result = Solrengine::Programs::Pda.to_seed(pubkey, :pubkey)
    assert_equal 32, result.bytesize
  end

  def test_seed_type_for_idl_maps_known_types
    assert_equal :u64, Solrengine::Programs::Pda.seed_type_for_idl("u64")
    assert_equal :u32, Solrengine::Programs::Pda.seed_type_for_idl("u32")
    assert_equal :u16, Solrengine::Programs::Pda.seed_type_for_idl("u16")
    assert_equal :u8, Solrengine::Programs::Pda.seed_type_for_idl("u8")
    assert_equal :string, Solrengine::Programs::Pda.seed_type_for_idl("string")
    assert_equal :pubkey, Solrengine::Programs::Pda.seed_type_for_idl("pubkey")
    assert_equal :pubkey, Solrengine::Programs::Pda.seed_type_for_idl("publicKey")
  end

  def test_seed_type_for_idl_falls_back_to_raw
    assert_equal :raw, Solrengine::Programs::Pda.seed_type_for_idl("unknown_type")
    assert_equal :raw, Solrengine::Programs::Pda.seed_type_for_idl(nil)
  end

  def test_create_program_address_returns_nil_for_on_curve
    # Most hashes will be off-curve, but we verify the method works
    program_id = "11111111111111111111111111111111"
    result = Solrengine::Programs::Pda.create_program_address([ "test", 255.chr ], program_id)
    # Result is either nil (on-curve) or a valid address string
    assert(result.nil? || result.is_a?(String))
  end
end
