# token_registry.aleo

Multi-token registry supporting arbitrary token IDs. Migrated from [ProvableHQ/aleo-standard-programs](https://github.com/ProvableHQ/aleo-standard-programs).

## State Model

| Mapping | Key | Value |
|---------|-----|-------|
| `registered_tokens` | `field` (token_id) | `TokenMetadata` |
| `balances` | `field` (hash of `TokenOwner`) | `Balance` |
| `authorized_balances` | `field` (hash of `TokenOwner`) | `Balance` |
| `allowances` | `field` (hash of spender+owner+token_id) | `u128` |

## Key Structs

**TokenMetadata:** `token_id`, `name`, `symbol`, `decimals`, `supply`, `max_supply`, `admin`, `external_authorization_required`, `external_authorization_party`.

**TokenOwner:** `account: address`, `token_id: field` — used to key balance lookups.

## Why Not ARC20-Compatible Directly

Every function takes an extra `token_id: field` parameter. For example, `transfer_public(token_id, recipient, amount)` instead of ARC20's `transfer_public(recipient, amount)`. Wrapper programs (e.g., `wrapped_token_registry.aleo`) fix a single token ID and expose the standard ARC20 signature.

## Role System

Per-token roles managed via `set_role` / `remove_role`:

- **MINTER_ROLE** = `1u8` — can call `mint_public` / `mint_private`
- **BURNER_ROLE** = `2u8` — can call `burn_public`

## Constants

`CREDITS_RESERVED_TOKEN_ID` — reserved token ID for Aleo credits; cannot be registered by users.

## Omissions (Leo 3.4)

`burn_private`, `prehook_private`, `transfer_private_to_public` — record inputs require entry points. `credits.aleo` import removed; CREDITS_RESERVED_TOKEN_ID is a constant.

## Functions

`initialize`, `register_token`, `update_token_management`, `set_role`, `remove_role`, `mint_public`, `mint_private`, `burn_public`, `prehook_public`, `transfer_public`, `transfer_public_as_signer`, `transfer_public_to_private`, `transfer_pub_to_priv_as_signer`, `transfer_from_public_to_private`, `transfer_from_public`, `approve_public`, `unapprove_public`, `transfer_private`, `join`, `split`.

## Tests

From `arc-0020/tests`: `npm test -- token-registry.test.js`
