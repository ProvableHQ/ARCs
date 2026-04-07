# wrapped_token_registry.aleo

**Stateful** wrapper around `token_registry.aleo` implementing the `MintableToken` interface (which extends `ARC20`). Provides an ARC20-compliant adapter for a specific `token_registry` token ID.

## Wrapper Pattern

Each wrapped token deploys its own program with a unique `WRAPPED_TOKEN_ID`. This program uses `WRAPPED_TOKEN_ID = 99999field`.

The wrapper maintains its own mappings rather than forwarding reads to the registry:

| Mapping | Key | Value |
|---------|-----|-------|
| `balances` | `address` | `u128` |
| `token_info` | `bool` | `TokenInfo` |
| `allowances` | `TokenAllowance` | `u128` |

## Deposit / Withdraw Flows

**`deposit_token_public(amount)`** — calls `token_registry.aleo::transfer_public_as_signer(WRAPPED_TOKEN_ID, self.address, amount)`, then increments the depositor's (signer's) local balance.

**`withdraw_token_public(amount)`** — decrements caller's local balance, then calls `token_registry.aleo::transfer_public(WRAPPED_TOKEN_ID, caller, amount)`.

**`withdraw_token_private(amount)`** — decrements caller's local balance, then calls `token_registry.aleo::transfer_public_to_private(WRAPPED_TOKEN_ID, caller, amount)`.

## MintableToken Extension

- `mint_public` = deposit (pulls from signer's registry balance into this wrapper)
- `burn_public` = withdraw (sends tokens back from wrapper to the registry)

## ARC20 Functions

`transfer_public`, `transfer_private`, `transfer_private_to_public`, `shield`, `unshield`, `approve_public`, `unapprove_public`, `transfer_from_public`, `transfer_from_public_to_private`, `mint_public`, `mint_private`, `burn_public`, `burn_private`, `deposit_token_public`, `withdraw_token_public`, `withdraw_token_public_signer`, `withdraw_token_private`.

## Dependency

`token_registry.aleo` (local)
