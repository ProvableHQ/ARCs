# ARC-0020 Reference Implementations

This directory contains reference implementations of the ARC-0020 token standard for Aleo.

## Programs

| Program | Implements | Description |
|---------|-----------|-------------|
| `wrapped_credits.aleo` | `MintableToken` | Wraps native Aleo credits into an ARC20-compatible token. Deposit/withdraw credits to mint/burn wrapped tokens. |
| `wrapped_token_registry.aleo` | `MintableToken` | Wraps any token registered in `token_registry.aleo` into an ARC20-compatible interface. |
| `compliant_token_template.aleo` | `ARC20Compliant` | Token with KYC/AML controls: freeze list (Merkle-proof-based), pause switch, role-based minting/burning, and compliance records emitted on private transfers. Multisig-gated upgrades. |
| `dummy_exchange.aleo` | — | Example DeFi consumer: calls `transfer_from_public` on `wrapped_credits.aleo` to spend an approved allowance. Shows how protocols interact with ARC20 tokens. |
| `freezelist.aleo` | — | Merkle-tree-based freeze list used by `compliant_token_template.aleo`. Supports efficient non-inclusion proofs that preserve sender privacy in private transfers. |
| `token_registry.aleo` | — | Multi-token registry with per-token roles (minter, burner, supply manager), external authorization hooks, and both public and private balance support. |

## Interfaces

### `ARC20`

The core fungible token interface. All compliant token programs must implement these transitions:

| Transition | Description |
|------------|-------------|
| `transfer_public(recipient, amount)` | Transfer public balance from caller to recipient |
| `transfer_private(input, to, amount) → (Token, Token)` | Transfer private token record; returns change and new token |
| `transfer_private_to_public(input, to, amount) → (Token, Final)` | Convert private token to public balance |
| `shield(amount) → (Token, Final)` | Convert public balance to private token |
| `unshield(input, amount) → (Token, Token, Final)` | Convert private token back to public balance |
| `approve_public(spender, amount)` | Approve a spender to transfer up to `amount` from caller's public balance |
| `unapprove_public(spender, amount)` | Reduce an existing approval |
| `transfer_from_public(owner, recipient, amount)` | Transfer from owner using caller's allowance |
| `transfer_from_public_to_private(owner, amount) → (Token, Final)` | Transfer from owner into a private token using caller's allowance |

### `MintableToken: ARC20`

Extends `ARC20` with supply management:

| Transition | Description |
|------------|-------------|
| `mint_public(recipient, amount)` | Mint new public tokens to recipient |
| `mint_private(recipient, amount) → (Token, Final)` | Mint new private token to recipient |
| `burn_public(amount)` | Burn caller's public tokens |
| `burn_private(input) → Final` | Burn a private token record |

### `ARC20Compliant`

For tokens requiring KYC/AML controls. Private transfers require Merkle non-inclusion proofs (proving the sender is not in the freeze list) and emit a `ComplianceRecord` to a designated investigator address.

## Running Tests

Prerequisites: a Leo devnode must be running.

```bash
# Start devnode (in a separate terminal)
cd arc-0020-2026/tests
npm run devnode

# Run all tests
cd arc-0020-2026/tests
npm install
npm test
```

Run a specific test file:
```bash
npm test -- wrapped-credits.test.js
```

Run a specific test case:
```bash
npm test -- -t "transfer_private"
```

## Advanced Examples

The `../arc-0020/programs/dispatchers/` directory contains dispatcher programs demonstrating runtime dynamic dispatch (ARC-0009): a caller program that can invoke any ARC20-compliant token without knowing its program ID at compile time.
