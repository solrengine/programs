# SolRengine Programs

Solana program interaction for Rails. Parse Anchor IDL files to generate Ruby account models, instruction builders, and Stimulus controllers.

## Installation

Add to your Gemfile:

```ruby
gem "solrengine-programs"
```

## Usage

### Generate from Anchor IDL

```bash
rails generate solrengine:program PiggyBank path/to/piggy_bank.json
```

This creates:
- `app/models/piggy_bank/lock.rb` — Account model with Borsh decoding
- `app/services/piggy_bank/lock_instruction.rb` — Instruction builder
- `app/services/piggy_bank/unlock_instruction.rb` — Instruction builder
- `app/javascript/controllers/piggy_bank_controller.js` — Stimulus controller
- `config/idl/piggy_bank.json` — IDL copy

### Query Program Accounts

```ruby
class PiggyBank::Lock < Solrengine::Programs::Account
  program_id "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
  account_name "Lock"

  borsh_field :dst, "pubkey"
  borsh_field :exp, "u64"

  def self.for_wallet(wallet_address)
    query(filters: [
      { "memcmp" => { "offset" => 8, "bytes" => wallet_address } }
    ])
  end

  def expired?
    exp < Time.now.to_i
  end
end

# Query accounts
locks = PiggyBank::Lock.for_wallet("YourWalletAddress...")
locks.each do |lock|
  puts "#{lock.pubkey}: #{lock.sol_balance} SOL, expires #{Time.at(lock.exp)}"
end
```

### Build Instructions (Server-Side)

```ruby
class PiggyBank::LockInstruction < Solrengine::Programs::Instruction
  program_id "ZaU8j7XCKSxmmkMvg7NnjrLNK6eiLZbHsJQAc2rFzEN"
  instruction_name "lock"

  argument :amt, "u64"
  argument :exp, "u64"

  account :payer, signer: true, writable: true
  account :dst
  account :lock, signer: true, writable: true
  account :system_program, address: "11111111111111111111111111111111"
end

# Build and send a transaction
ix = PiggyBank::LockInstruction.new(
  amt: 100_000_000,
  exp: (Time.now + 5.minutes).to_i,
  payer: payer_pubkey,
  dst: destination_pubkey,
  lock: lock_keypair_pubkey
)

builder = Solrengine::Programs::TransactionBuilder.new
builder.add_instruction(ix)
builder.add_signer(server_keypair)
signature = builder.sign_and_send
```

### PDA Derivation

```ruby
address, bump = Solrengine::Programs::Pda.find_program_address(
  ["vault", Solrengine::Programs::Pda.to_seed(user_pubkey, :pubkey)],
  program_id
)
```

### Error Mapping

```ruby
idl = Solrengine::Programs::IdlParser.parse_file("config/idl/piggy_bank.json")
mapper = Solrengine::Programs::ErrorMapper.new(idl.errors)

begin
  builder.sign_and_send
rescue Solrengine::Programs::TransactionError => e
  mapper.raise_if_program_error!(e.rpc_error)
  # Raises: ProgramError "LockNotExpired (6002): Lock has not expired yet"
end
```

### Configuration

```ruby
# config/initializers/solrengine_programs.rb
Solrengine::Programs.configure do |config|
  config.keypair_format = :base58  # or :json_array
end
```

Set `SOLANA_KEYPAIR` environment variable for server-side transaction signing.

## Dependencies

- [solrengine-rpc](https://github.com/solrengine/rpc) — Solana RPC client
- [borsh](https://github.com/dryruby/borsh.rb) — Borsh binary serialization
- [ed25519](https://github.com/RubyCrypto/ed25519) — Transaction signing
- [base58](https://github.com/dougal/base58) — Address encoding

## License

MIT
