# Changelog

## 0.2.0

- Parse `pda.seeds` metadata from Anchor IDL account specs (`const` and `arg` seed kinds).
- Auto-derive PDA addresses in generated instruction builders — no more manual address math for programs that use `#[account(seeds = [...], bump)]`.
- `Instruction.account` DSL accepts a `pda:` kwarg with declarative seed specs.
- `Pda.seed_type_for_idl` translates IDL arg type strings to `Pda.to_seed` symbols.
- Generator raises a clear error when a PDA seed path does not match any instruction argument (after stripping leading underscores).
- Generator normalizes leading-underscore arg names (e.g., Rust `_poll_id` → Ruby `:poll_id`).

## 0.1.0

- Initial release.
