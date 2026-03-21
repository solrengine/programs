require "test_helper"

class Solrengine::Programs::BorshTypesTest < Minitest::Test
  include TestFixtures

  def test_pubkey_encode_decode_roundtrip
    pubkey = "11111111111111111111111111111111"
    buffer = Borsh::Buffer.new

    Solrengine::Programs::BorshTypes::PublicKey.encode(buffer, pubkey)
    data = buffer.data

    assert_equal 32, data.bytesize

    read_buffer = Borsh::Buffer.new(data)
    decoded = Solrengine::Programs::BorshTypes::PublicKey.decode(read_buffer)
    assert_equal pubkey, decoded
  end

  def test_pubkey_size
    assert_equal 32, Solrengine::Programs::BorshTypes::PublicKey.size
  end

  def test_discriminator_for_account
    disc = Solrengine::Programs::BorshTypes::Discriminator.for_account("Lock")
    assert_equal 8, disc.bytesize

    # Verify against known piggy_bank IDL discriminator
    idl = piggy_bank_idl
    expected = idl.accounts.first.discriminator
    assert_equal expected, disc
  end

  def test_discriminator_for_instruction
    disc = Solrengine::Programs::BorshTypes::Discriminator.for_instruction("lock")
    assert_equal 8, disc.bytesize

    # Verify against known piggy_bank IDL discriminator
    idl = piggy_bank_idl
    lock_ix = idl.instructions.find { |ix| ix.name == "lock" }
    assert_equal lock_ix.discriminator, disc
  end

  def test_read_field_u64
    value = 12345678
    data = [ value ].pack("Q<")
    buffer = Borsh::Buffer.new(data)

    result = Solrengine::Programs::BorshTypes.read_field(buffer, "u64")
    assert_equal value, result
  end

  def test_write_field_u64
    value = 42
    data = Borsh::Buffer.open do |buf|
      Solrengine::Programs::BorshTypes.write_field(buf, "u64", value)
    end

    assert_equal [ value ].pack("Q<"), data
  end

  def test_read_field_bool
    buffer = Borsh::Buffer.new([ 1 ].pack("C"))
    assert_equal true, Solrengine::Programs::BorshTypes.read_field(buffer, "bool")

    buffer = Borsh::Buffer.new([ 0 ].pack("C"))
    assert_equal false, Solrengine::Programs::BorshTypes.read_field(buffer, "bool")
  end

  def test_read_field_string
    str = "hello"
    data = [ str.bytesize ].pack("V") + str
    buffer = Borsh::Buffer.new(data)

    result = Solrengine::Programs::BorshTypes.read_field(buffer, "string")
    assert_equal str, result
  end

  def test_read_write_pubkey
    pubkey = "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"

    data = Borsh::Buffer.open do |buf|
      Solrengine::Programs::BorshTypes.write_field(buf, "pubkey", pubkey)
    end

    buffer = Borsh::Buffer.new(data)
    result = Solrengine::Programs::BorshTypes.read_field(buffer, "pubkey")
    assert_equal pubkey, result
  end

  def test_field_size_known_types
    assert_equal 8, Solrengine::Programs::BorshTypes.field_size("u64")
    assert_equal 1, Solrengine::Programs::BorshTypes.field_size("bool")
    assert_equal 32, Solrengine::Programs::BorshTypes.field_size("pubkey")
    assert_nil Solrengine::Programs::BorshTypes.field_size("string")
  end

  def test_encode_compact_u16
    assert_equal [ 0 ].pack("C"), Solrengine::Programs::BorshTypes.encode_compact_u16(0)
    assert_equal [ 1 ].pack("C"), Solrengine::Programs::BorshTypes.encode_compact_u16(1)
    assert_equal [ 127 ].pack("C"), Solrengine::Programs::BorshTypes.encode_compact_u16(127)
    assert_equal [ 128, 1 ].pack("CC"), Solrengine::Programs::BorshTypes.encode_compact_u16(128)
  end

  def test_read_write_option_present
    data = Borsh::Buffer.open do |buf|
      Solrengine::Programs::BorshTypes.write_field(buf, { "option" => "u64" }, 42)
    end

    buffer = Borsh::Buffer.new(data)
    result = Solrengine::Programs::BorshTypes.read_field(buffer, { "option" => "u64" })
    assert_equal 42, result
  end

  def test_read_write_option_none
    data = Borsh::Buffer.open do |buf|
      Solrengine::Programs::BorshTypes.write_field(buf, { "option" => "u64" }, nil)
    end

    buffer = Borsh::Buffer.new(data)
    result = Solrengine::Programs::BorshTypes.read_field(buffer, { "option" => "u64" })
    assert_nil result
  end

  def test_read_write_vec
    data = Borsh::Buffer.open do |buf|
      Solrengine::Programs::BorshTypes.write_field(buf, { "vec" => "u32" }, [ 1, 2, 3 ])
    end

    buffer = Borsh::Buffer.new(data)
    result = Solrengine::Programs::BorshTypes.read_field(buffer, { "vec" => "u32" })
    assert_equal [ 1, 2, 3 ], result
  end
end
