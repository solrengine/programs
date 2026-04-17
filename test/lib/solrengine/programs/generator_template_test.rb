require "test_helper"
require "erb"
require "active_support/core_ext/string/inflections"

class Solrengine::Programs::GeneratorTemplateTest < Minitest::Test
  include TestFixtures

  TEMPLATE_PATH = File.expand_path(
    "../../../../lib/generators/solrengine/program/templates/instruction.rb.erb",
    __dir__
  )

  def render(instruction, program_id, program_class_name)
    template_src = File.read(TEMPLATE_PATH)
    ctx = Object.new
    ctx.define_singleton_method(:program_class) { program_class_name }
    ctx.instance_variable_set(:@instruction, instruction)
    ctx.instance_variable_set(:@program_id, program_id)
    erb = ERB.new(template_src, trim_mode: "-")
    erb.result(ctx.instance_eval { binding })
  end

  def test_piggy_bank_lock_renders_without_pda
    idl = piggy_bank_idl
    lock = idl.instructions.find { |ix| ix.name == "lock" }
    output = render(lock, idl.program_id, "PiggyBank")

    assert_match(/class PiggyBank::LockInstruction/, output)
    assert_match(/account :payer, signer: true, writable: true/, output)
    assert_match(/account :system_program, address: "11111111111111111111111111111111"/, output)
    refute_match(/pda:/, output)
  end

  def test_voting_initialize_poll_renders_pda_block
    idl = voting_idl
    init_poll = idl.instructions.find { |ix| ix.name == "initialize_poll" }
    output = render(init_poll, idl.program_id, "Voting")

    assert_match(/class Voting::InitializePollInstruction/, output)
    assert_match(/argument :poll_id, "u64"/, output)
    assert_match(/account :poll_account, writable: true, pda: \[/, output)
    assert_match(/\{ const: \[112, 111, 108, 108\] \}/, output)
    assert_match(/\{ arg: :poll_id, type: :u64 \}/, output)
  end

  def test_voting_initialize_candidate_renders_two_pdas
    idl = voting_idl
    init_candidate = idl.instructions.find { |ix| ix.name == "initialize_candidate" }
    output = render(init_candidate, idl.program_id, "Voting")

    assert_match(/account :poll_account, writable: true, pda: \[/, output)
    assert_match(/account :candidate_account, writable: true, pda: \[/, output)
    assert_match(/\{ arg: :candidate, type: :string \}/, output)
  end

  def test_voting_vote_raises_on_seed_path_mismatch
    # The bootcamp voting program has `_pool_id` in the function signature but
    # `poll_id` in the #[instruction(...)] macro. That mismatch surfaces at
    # generation time with a clear error.
    idl = voting_idl
    vote = idl.instructions.find { |ix| ix.name == "vote" }

    error = assert_raises(RuntimeError) do
      render(vote, idl.program_id, "Voting")
    end

    assert_match(/Cannot resolve PDA seed reference `poll_id`/, error.message)
    assert_match(/instruction `vote`/, error.message)
    assert_match(/Available args: pool_id, candidate/, error.message)
  end

  def test_generated_voting_instruction_compiles_and_derives_pda
    idl = voting_idl
    init_candidate = idl.instructions.find { |ix| ix.name == "initialize_candidate" }
    output = render(init_candidate, idl.program_id, "GeneratedVoting")

    # Wrap the class in a module so we can eval it safely
    module_wrapper = Module.new
    module_wrapper.const_set(:GeneratedVoting, Module.new)
    module_wrapper.module_eval(output)

    klass = module_wrapper.const_get(:GeneratedVoting).const_get(:InitializeCandidateInstruction)
    assert_equal idl.program_id, klass.program_id

    ix = klass.new(poll_id: 7, candidate: "alpha", signer: "11111111111111111111111111111111")
    assert ix.valid?, "generated instruction invalid: #{ix.errors.inspect}"

    result = ix.to_instruction
    # signer is at [0], poll_account at [1], candidate_account at [2], system_program at [3]
    assert_equal 4, result[:accounts].size

    poll_pubkey = result[:accounts][1][:pubkey]
    candidate_pubkey = result[:accounts][2][:pubkey]
    refute_nil poll_pubkey
    refute_nil candidate_pubkey
    refute_equal poll_pubkey, candidate_pubkey
    assert poll_pubkey.length.between?(32, 44)
  end
end
