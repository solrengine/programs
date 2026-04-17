# Changelog

## 0.2.0

- Parse `pda.seeds` metadata from Anchor IDL account specs (`const` and `arg` seed kinds).
- Auto-derive PDA addresses in generated instruction builders — no more manual address math for programs that use `#[account(seeds = [...], bump)]`.
- `Instruction.account` DSL accepts a `pda:` kwarg with declarative seed specs.
- `Pda.seed_type_for_idl` translates IDL arg type strings to `Pda.to_seed` symbols.
- Generator raises a clear error when a PDA seed path does not match any instruction argument (after stripping leading underscores).
- Generator normalizes leading-underscore arg names (e.g., Rust `_poll_id` → Ruby `:poll_id`).
- **Bugfix:** `Pda.on_curve?` now strips the Ed25519 sign bit (top bit of byte 31) before interpreting the y coordinate. Previously, ~50% of on-curve addresses were misclassified as off-curve, causing `find_program_address` to pick a higher bump than Anchor and produce a mismatched PDA. Also rejects non-canonical y values (`y >= 2^255 - 19`) and handles the `x² = 0` edge case correctly.

## 0.1.0

- Initial release.
