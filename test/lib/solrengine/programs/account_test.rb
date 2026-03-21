require "test_helper"

# Define a test account class matching piggy_bank Lock
class TestLock < Solrengine::Programs::Account
  program_id "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
  account_name "Lock"

  borsh_field :dst, "pubkey"
  borsh_field :exp, "u64"

  def expired?
    exp < Time.now.to_i
  end
end

class Solrengine::Programs::AccountTest < Minitest::Test
  include TestFixtures

  def test_program_id
    assert_equal "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN", TestLock.program_id
  end

  def test_borsh_fields_defined
    fields = TestLock.borsh_fields
    assert_equal 2, fields.size
    assert_equal :dst, fields[0][:name]
    assert_equal "pubkey", fields[0][:type]
    assert_equal :exp, fields[1][:name]
    assert_equal "u64", fields[1][:type]
  end

  def test_discriminator
    disc = TestLock.discriminator
    assert_equal 8, disc.bytesize

    # Should match the IDL's Lock discriminator
    expected = [ 8, 255, 36, 202, 210, 22, 57, 137 ].pack("C*")
    assert_equal expected, disc
  end

  def test_from_account_data
    dst_pubkey = "11111111111111111111111111111111"
    exp_value = 1700000000
    data_base64 = mock_lock_account_data(dst_pubkey: dst_pubkey, exp: exp_value)

    lock = TestLock.from_account_data("SomeAccountPubkey", data_base64, lamports: 1_000_000_000)

    assert_equal "SomeAccountPubkey", lock.pubkey
    assert_equal 1_000_000_000, lock.lamports
    assert_equal dst_pubkey, lock.dst
    assert_equal exp_value, lock.exp
  end

  def test_from_account_data_sol_balance
    data_base64 = mock_lock_account_data
    lock = TestLock.from_account_data("key", data_base64, lamports: 500_000_000)

    assert_equal 0.5, lock.sol_balance
  end

  def test_from_account_data_empty_raises
    assert_raises(Solrengine::Programs::DeserializationError) do
      TestLock.from_account_data("key", Base64.strict_encode64(""))
    end
  end

  def test_from_account_data_too_short_raises
    assert_raises(Solrengine::Programs::DeserializationError) do
      TestLock.from_account_data("key", Base64.strict_encode64("short"))
    end
  end

  def test_query_requires_filters
    assert_raises(Solrengine::Programs::Error) do
      TestLock.query(filters: [])
    end
  end

  def test_query_with_filters
    dst_pubkey = "11111111111111111111111111111111"
    data_base64 = mock_lock_account_data(dst_pubkey: dst_pubkey, exp: 1700000000)

    Solrengine::Rpc.stub_client.responses["getProgramAccounts"] = {
      "result" => [
        {
          "pubkey" => "AccountPubkey123",
          "account" => {
            "data" => [ data_base64, "base64" ],
            "lamports" => 1_000_000_000
          }
        }
      ]
    }

    results = TestLock.query(filters: [
      { "memcmp" => { "offset" => 8, "bytes" => dst_pubkey } }
    ])

    assert_equal 1, results.size
    assert_equal "AccountPubkey123", results.first.pubkey
    assert_equal dst_pubkey, results.first.dst
  end

  def test_query_skips_malformed_accounts
    Solrengine::Rpc.stub_client.responses["getProgramAccounts"] = {
      "result" => [
        {
          "pubkey" => "BadAccount",
          "account" => {
            "data" => [ Base64.strict_encode64("tooshort"), "base64" ],
            "lamports" => 0
          }
        }
      ]
    }

    results = TestLock.query(filters: [
      { "memcmp" => { "offset" => 8, "bytes" => "whatever" } }
    ])

    assert_equal 0, results.size
  end

  def test_custom_method
    data_base64 = mock_lock_account_data(exp: 1)
    lock = TestLock.from_account_data("key", data_base64)

    assert lock.expired?
  end

  def test_initialize_with_attributes
    lock = TestLock.new(dst: "abc", exp: 123)
    assert_equal "abc", lock.dst
    assert_equal 123, lock.exp
  end
end
