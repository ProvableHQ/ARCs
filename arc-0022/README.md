---
arc: 22
title: ARC-22 Compliant Fungible Token Standard
authors: The Aleo Team <hello@aleo.org>
discussion: https://github.com/AleoHQ/ARCs/discussions/TBD
topic: Application
status: Draft
created: 2026-03-18
---

## Abstract

ARC-22 defines a compliant fungible token interface for Aleo. It extends [ARC-20](../arc-0020/) with freeze-list enforcement, compliance records, role-based access control, and pause functionality for regulated token issuers (stablecoins, security tokens). ARC-22 preserves Aleo's privacy guarantees while enabling regulatory oversight through Merkle non-inclusion proofs and investigator-visible compliance records.

## Motivation

ARC-20 provides a minimal token standard but lacks regulatory compliance features required by many real-world token deployments. Regulated tokens need:

1. **Freeze lists** to block sanctioned or compromised addresses from transacting
2. **Audit trails** for private transfers, enabling authorized investigators to review token movements without breaking sender privacy for the public
3. **Role-based minting/burning/pausing** to support operational controls required by regulated issuers

ARC-22 adds these capabilities while preserving Aleo's privacy guarantees through Merkle non-inclusion proofs. Private transfers remain private to the public, but produce compliance records visible only to a designated investigator address.

## Specification

### ARC20Compliant Interface

The compliant token interface adds freeze-list enforcement and compliance reporting to ARC-20's transfer primitives:

```leo
interface ARC20Compliant {
    record Token;
    record ComplianceRecord;
    record Metadata;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;

    fn transfer_private(recipient: address, amount: u128, input_record: Token,
        sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32])
        -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(public recipient: address, public amount: u128,
        input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32])
        -> (Metadata, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128)
        -> (ComplianceRecord, Token, Final);
    fn transfer_from_public_to_private(public owner: address, recipient: address,
        public amount: u128) -> (ComplianceRecord, Token, Final);
    fn shield(public amount: u128) -> (ComplianceRecord, Token, Final);
    fn unshield(public recipient: address, public amount: u128, input_record: Token,
        sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32])
        -> (ComplianceRecord, Token, Final);
}
```

### Record Types

**Token** -- Represents a private token balance:
```leo
record Token {
    owner: address,
    amount: u128,
}
```

**ComplianceRecord** -- Emitted to the investigator address during private transfers. Contains the full transfer details for compliance auditing:
```leo
record ComplianceRecord {
    owner: address,     // investigator address
    amount: u128,
    sender: address,
    recipient: address,
}
```

**Metadata** -- Emitted by `transfer_private_to_public` instead of `ComplianceRecord`. Since `amount` and `recipient` are already public inputs visible on-chain, only the sender identity is recorded privately:
```leo
record Metadata {
    owner: address,     // investigator address
    sender: address,
}
```

### Freeze-List Mechanism

The freeze list prevents sanctioned or compromised addresses from transacting. It uses a Merkle tree to enable privacy-preserving verification.

#### Merkle Non-Inclusion Proofs

Private transfers require the sender to prove they are **not** on the freeze list without revealing their identity publicly. This is accomplished through non-inclusion proofs:

1. The freeze list is maintained as a sorted Merkle tree of frozen addresses
2. To prove non-inclusion, the sender provides two adjacent leaf proofs showing that their address falls in a **gap** between two consecutive frozen addresses (or before the first / after the last)
3. The proof verifies against the current (or previous) Merkle root stored on-chain

#### Windowed Root Updates

When the freeze list is updated, the Merkle root changes. A `BLOCK_HEIGHT_WINDOW` mechanism prevents race conditions:

- Both the current and previous Merkle roots are stored on-chain
- Proofs generated against the previous root remain valid for `BLOCK_HEIGHT_WINDOW` blocks after a root update
- This allows in-flight transactions with proofs generated before a freeze list update to still succeed

#### `freezelist.aleo` State

| Mapping | Key | Value | Description |
|---------|-----|-------|-------------|
| `freeze_list` | `address` | `bool` | Whether an address is frozen |
| `freeze_list_index` | `u32` | `address` | Ordered index of frozen addresses |
| `freeze_list_last_index` | `bool` | `u32` | Last used index in the freeze list |
| `freeze_list_root` | `u8` (1 or 2) | `field` | Current and previous Merkle roots |
| `root_updated_height` | `bool` | `u32` | Block height of last root update |
| `block_height_window` | `bool` | `u32` | Number of blocks the previous root remains valid |

### Compliance Records

All private transfers emit a `ComplianceRecord` with `owner` set to `INVESTIGATOR_ADDRESS`. This means only the investigator can decrypt the record and view the transfer details (sender, recipient, amount).

For `transfer_private_to_public`, a lighter `Metadata` record is emitted instead, since the amount and recipient are already visible as public inputs on-chain. The `Metadata` record's `owner` is also set to `INVESTIGATOR_ADDRESS`, allowing the investigator to learn the sender's identity.

### Investigator Address

The investigator address is hardcoded as the `INVESTIGATOR_ADDRESS` constant in `compliant_token_template.aleo`. It can only be changed by deploying a new edition of the program, which is gated by `multisig_core.aleo` signing operations. This ensures that changes to the investigator require multi-party approval.

### Role-Based Access Control

Roles are assigned using a bitmask system, allowing a single address to hold multiple roles:

| Role | Bitmask | Description |
|------|---------|-------------|
| `MINTER_ROLE` | `1` | Can mint new tokens (public and private) |
| `BURNER_ROLE` | `2` | Can burn tokens (public and private) |
| `PAUSE_ROLE` | `4` | Can pause/unpause all transfers |
| `MANAGER_ROLE` | `8` | Can assign roles to other addresses |

Role checks use bitwise AND: `role & REQUIRED_ROLE == REQUIRED_ROLE`. A MANAGER can assign any role combination to any address, but cannot remove MANAGER from themselves (the `update_role` function requires that if `caller == new_address`, the new role must still include MANAGER).

### Dynamic Dispatch

ARC20Compliant is declared as a Leo `interface`, so its public functions (`transfer_public`, `approve_public`, `transfer_from_public`) can be called dynamically using Leo's interface-enforced syntax:

```leo
ARC20Compliant@(token_id)/transfer_public(recipient, amount);
ARC20Compliant@(token_id)/approve_public(spender, amount);
ARC20Compliant@(token_id)/transfer_from_public(owner, recipient, amount);
```

See [ARC-20 Dynamic Dispatch](../arc-0020/#dynamic-dispatch) for the full syntax reference, `_dynamic_call` intrinsic details, and examples.

Private functions (`transfer_private`, `unshield`, etc.) require Merkle proof parameters specific to the freeze-list state, making them impractical for generic dynamic dispatch. These are typically called directly by the token owner or through a program that imports the specific compliant token.

### Pause Mechanism

`set_pause_status(bool)` requires `PAUSE_ROLE` and blocks all transfer functions (public, private, shield, unshield) while paused. Minting and burning are also blocked during pause. This provides an emergency stop mechanism for regulated tokens.

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**Compliant token template tests** (`compliant-token-template.test.js`):
- `initialize`: Rejects duplicate initialization
- `transfer_public`: Moves balances; rejects insufficient balance
- `approve_public` / `unapprove_public`: Manages allowances
- `transfer_from_public`: Spender transfers with allowance
- `transfer_public_to_private` / `transfer_from_public_to_private`: Public-to-private conversions with ComplianceRecord emission
- `shield` / `unshield`: Shield and unshield with Merkle proof verification
- `transfer_private`: Private transfer with freeze-list proof and ComplianceRecord
- `transfer_private_to_public`: Returns `Metadata` record (not `ComplianceRecord`) with investigator as owner; validates sender address
- `shield`: ComplianceRecord contains correct investigator owner and sender
- `mint_public (positive)`: Minter increases recipient balance
- `mint_private (positive)`: Minter creates private Token with ComplianceRecord
- `burn_public (positive)`: Burner decreases owner balance
- `burn_public (negative)`: Non-burner is rejected
- `mint_public (negative)`: Non-minter is rejected
- `set_pause_status (negative)`: Non-pauser is rejected
- `update_role (negative)`: Non-manager is rejected
- `pause/unpause`: `set_pause_status` blocks all transfers while paused

## Reference Implementations

- [`compliant_token_template/`](./compliant_token_template/) -- Full ARC20Compliant implementation with freeze list, role-based minting/burning/pausing, Merkle proof non-inclusion verification, and multisig-gated upgrades
- [`freezelist/`](./freezelist/) -- On-chain freeze list using a Merkle tree with windowed root updates for proof validity across blocks

## Dependencies

- [ARC-20](../arc-0020/) -- ARC20Compliant tokens provide the same transfer primitives as ARC-20 with additional compliance constraints (freeze-list proofs, ComplianceRecord emission)
- **Leo compiler** with interface/dynamic dispatch support
- **merkle_tree.aleo** and **multisig_core.aleo** -- Deployed as on-chain dependencies; `merkle_tree.aleo` provides Merkle tree verification primitives, `multisig_core.aleo` gates program upgrades
- **@provablehq/sdk** (for SDK-based testing)
- **@sealance-io/policy-engine-aleo** (Merkle proof generation for tests)

## Backwards Compatibility

ARC-22 is a new standard and has no backwards compatibility concerns. Programs implementing ARC20Compliant are not required to implement the base ARC20 interface, as the compliance requirements (freeze-list proofs on private transfers, ComplianceRecord emission) change the function signatures.

## Security Considerations

**Freeze list**: The ARC20Compliant interface enforces freeze-list checks on all private transfers via Merkle proof non-inclusion. Public transfers check the `freeze_list` mapping directly. A windowed root update mechanism allows proofs generated against a previous root to remain valid for a configurable number of blocks after a root update, preventing race conditions where a freeze list update invalidates in-flight transactions.

**Compliance records**: Private transfers emit a `ComplianceRecord` to the designated investigator address, allowing authorized parties to audit private token movements while preserving sender privacy from the public. The investigator address is hardcoded and can only be changed via multisig-gated program upgrade.

**Metadata records**: `transfer_private_to_public` emits a lighter `Metadata` record instead of `ComplianceRecord`, since the amount and recipient are already visible as public inputs. The `Metadata` record owner is set to the investigator address so the investigator can identify the sender.

**Pause mechanism**: Token admins with the `PAUSE_ROLE` can halt all transfers via `set_pause_status`. This is an emergency mechanism -- prolonged pauses should be avoided as they freeze all user funds.

**Role-based access**: Minting, burning, pausing, and freeze-list management are gated by role bitmasks. A MANAGER can assign any role to any address but cannot remove MANAGER from themselves, preventing accidental self-lockout.

**Upgradability**: `compliant_token_template.aleo` and `freezelist.aleo` gate program upgrades behind `multisig_core.aleo` signing operations, ensuring that code changes require multi-party approval.

## Testing

Prerequisites:
- Leo compiler with interface support (build from source)
- Node.js 18+

```bash
cd arc-0022/tests
npm install
npm test                    # Run all tests (requires local devnode)
npm run test:compliant-token-template  # Run compliant token tests only
```

Tests start a local devnode, deploy programs with their dependencies, and execute transactions via `leo execute`.

## Copyright

This ARC is placed in the public domain.
