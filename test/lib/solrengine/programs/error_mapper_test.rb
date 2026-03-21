require "test_helper"

class Solrengine::Programs::ErrorMapperTest < Minitest::Test
  include TestFixtures

  def setup
    @mapper = Solrengine::Programs::ErrorMapper.new(piggy_bank_idl.errors)
  end

  def test_map_known_error
    result = @mapper.map(6000)
    assert_equal({ code: 6000, name: "InvalidAmount", message: "Amount must be greater than 0" }, result)
  end

  def test_map_unknown_error
    result = @mapper.map(9999)
    assert_nil result
  end

  def test_extract_custom_error
    rpc_error = { "InstructionError" => [ 0, { "Custom" => 6001 } ] }
    code = Solrengine::Programs::ErrorMapper.extract_custom_error(rpc_error)
    assert_equal 6001, code
  end

  def test_extract_custom_error_nil_for_non_custom
    assert_nil Solrengine::Programs::ErrorMapper.extract_custom_error(nil)
    assert_nil Solrengine::Programs::ErrorMapper.extract_custom_error({})
    assert_nil Solrengine::Programs::ErrorMapper.extract_custom_error("string")
  end

  def test_raise_if_program_error_known
    rpc_error = { "InstructionError" => [ 0, { "Custom" => 6002 } ] }

    err = assert_raises(Solrengine::Programs::ProgramError) do
      @mapper.raise_if_program_error!(rpc_error)
    end

    assert_equal 6002, err.code
    assert_equal "LockNotExpired", err.error_name
    assert_includes err.message, "Lock has not expired yet"
  end

  def test_raise_if_program_error_unknown_code
    rpc_error = { "InstructionError" => [ 0, { "Custom" => 9999 } ] }

    assert_raises(Solrengine::Programs::TransactionError) do
      @mapper.raise_if_program_error!(rpc_error)
    end
  end

  def test_raise_if_program_error_no_custom_does_nothing
    @mapper.raise_if_program_error!(nil)
    @mapper.raise_if_program_error!({})
    # No exception raised
  end
end
