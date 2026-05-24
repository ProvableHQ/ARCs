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

ARC-22 defines a compliant fungible token interface for Aleo. It extends [ARC-20](../arc-0020/) with freeze-list enforcement and compliance records for regulated token issuers (stablecoins, security tokens). ARC-22 preserves Aleo's privacy guarantees while enabling regulatory oversight through Merkle non-inclusion proofs and investigator-visible compliance records.

The reference program [`compliant_token_template.aleo`](./compliant_token_template/) declares the Leo interface **`IARC22`** with core transfers, **`view fn`** reads, and compliance-bearing transitions. The signatures below match [`compliant_token_template/src/main.leo`](./compliant_token_template/src/main.leo) exactly.

## Motivation

ARC-20 provides a minimal token standard but lacks regulatory compliance features required by many real-world token deployments. Regulated tokens need:

1. **Freeze lists** to block sanctioned or compromised addresses from transacting
2. **Audit trails** for private transfers, enabling authorized investigators to review token movements without exposing sender identity to the public

ARC-22 adds these capabilities while preserving Aleo's privacy guarantees through Merkle non-inclusion proofs. Private transfers remain hidden from the public, but produce compliance records visible only to a designated investigator address.

## Specification

### `IARC22`

The compliant token surface adds freeze-list enforcement (via Merkle non-inclusion proofs on private sends) and investigator-visible **`ComplianceRecord`** outputs on every transition that materially changes a balance. Mappings and storage variables are intentionally **not** part of the interface body—only function signatures and the records (**`Token`**, **`ComplianceRecord`**) form the contract.

```leo
interface IARC22 {
    record Token {
        owner: address,
        amount: u128,
        ..
    }

    record ComplianceRecord {
        owner: address,
        amount: u128,
        sender: address,
        recipient: address,
        ..
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(
        public owner: address,
        recipient: address,
        public amount: u128,
    ) -> (ComplianceRecord, Token, Final);

    fn transfer_private(
        recipient: address,
        amount: u128,
        input_record: Token,
        sender_merkle_proofs: [freezelist.aleo::MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Token, Final);

    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input_record: Token,
        sender_merkle_proofs: [freezelist.aleo::MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Final);

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (
        ComplianceRecord, Token, Final,
    );

    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);

    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}
```

**Public ↔ private conversions.** Use **`transfer_public_to_private`** (caller debits public balance; sender is `self.caller`, freeze check reads the public `freeze_list` mapping; returns **`(ComplianceRecord, Token, Final)`**) and **`transfer_private_to_public`** (private **`Token`** in; sender proves freeze-list non-inclusion with **`sender_merkle_proofs`**; credits recipient public balance; returns **`(ComplianceRecord, Token, Final)`**). Both emit a **`ComplianceRecord`** to **`INVESTIGATOR_ADDRESS`**.

**Merkle non-inclusion proofs** are required only on transitions where the sender is private -- **`transfer_private`** and **`transfer_private_to_public`**. Transitions where the sender is public -- **`transfer_public_to_private`** and **`transfer_from_public_to_private`** -- read the **`freeze_list`** mapping directly for the sender, but still emit a **`ComplianceRecord`** because the recipient is private.

**Compliance coverage.** Every transition that moves balances on a private path -- **`transfer_private`**, **`transfer_private_to_public`**, **`transfer_public_to_private`**, and **`transfer_from_public_to_private`** -- emits a **`ComplianceRecord`** owned by **`INVESTIGATOR_ADDRESS`**, so the investigator can decrypt the full sender / recipient / amount tuple whenever at least one side is private.

### Record Types

**Token** -- Represents a private token balance. Implementations may add additional fields beyond `owner` and `amount`:
```leo
record Token {
    owner: address,
    amount: u128,
}
```

**ComplianceRecord** -- Emitted to the investigator address during the four transitions listed above. Contains the full transfer details for compliance auditing:

```leo
record ComplianceRecord {
    owner: address,     // INVESTIGATOR_ADDRESS
    amount: u128,
    sender: address,    // ZERO_ADDRESS for mint paths
    recipient: address, // ZERO_ADDRESS for burn paths
}
```

The interface declares both records with `..`, so implementations may add fields. The reference template uses the exact two-field `Token` and four-field `ComplianceRecord` shown above.

### Freeze-List Mechanism

The freeze list prevents sanctioned or compromised addresses from transacting. It uses a Merkle tree to enable privacy-preserving verification.

#### Merkle Non-Inclusion Proofs

Private transfers require the sender to prove they are **not** on the freeze list without revealing their identity publicly. This is accomplished through non-inclusion proofs:

1. The freeze list is maintained as a sorted Merkle tree of frozen addresses
2. To prove non-inclusion, the sender provides Merkle proofs for two adjacent leaves in the tree, showing that their address falls in the **gap** between them (or before the first / after the last frozen address)
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

Transitions that move balances along a private path emit a **`ComplianceRecord`** with **`owner`** set to **`INVESTIGATOR_ADDRESS`**, so only the investigator can decrypt the record and view the transfer details (sender, recipient, amount). The reference template emits **`ComplianceRecord`** on:

| Transition | `sender` field | `recipient` field |
|------------|----------------|--------------------|
| **`transfer_private`** | `input_record.owner` (private) | `recipient` (private) |
| **`transfer_private_to_public`** | `input_record.owner` (private) | `recipient` (public input) |
| **`transfer_public_to_private`** | `self.caller` (public) | `recipient` (private) |
| **`transfer_from_public_to_private`** | `owner` (public) | `recipient` (private) |
| **`mint_private`** (admin path) | `ZERO_ADDRESS` | `recipient` (private) |
| **`burn_private`** (admin path) | `input_record.owner` | `ZERO_ADDRESS` |

Fully public transitions (**`transfer_public`**, **`transfer_public_as_signer`**, **`transfer_from_public`**, **`mint_public`**, **`burn_public`**) do **not** emit a **`ComplianceRecord`** -- the sender, recipient, and amount are already public inputs visible on-chain.

### Investigator Address

The investigator address is hardcoded as the `INVESTIGATOR_ADDRESS` constant in `compliant_token_template.aleo`. It can only be changed by deploying a new edition of the program, which is gated by `multisig_core.aleo` signing operations. This ensures that changes to the investigator require multi-party approval.

### Admin & Operational Surface (non-interface)

`compliant_token_template.aleo` also exposes admin transitions that are **not** part of **`IARC22`** but are required for a functioning regulated token:

- **`initialize(name, symbol, decimals, max_supply, admin)`** -- one-time setup, callable only by `DEPLOYER_ADDRESS`; populates `storage token_info`, sets `pause = false`, marks `initialized = true`, and assigns `MANAGER_ROLE` to `admin`.
- **`update_role(new_address, role)`** -- manager-only role bitmask updates; supports `MINTER_ROLE`, `BURNER_ROLE`, `PAUSE_ROLE`, `MANAGER_ROLE`.
- **`mint_public(recipient, amount)` / `mint_private(recipient, amount)`** -- gated by `MINTER_ROLE`; both honor `pause` and `max_supply`. `mint_private` emits a **`ComplianceRecord`** with `sender = ZERO_ADDRESS`.
- **`burn_public(owner, amount)` / `burn_private(input_record, amount)`** -- gated by `BURNER_ROLE`. `burn_private` emits a **`ComplianceRecord`** with `recipient = ZERO_ADDRESS`.
- **`set_pause_status(pause_status)`** -- gated by `PAUSE_ROLE`; toggles the `pause` storage flag, which blocks every balance-moving transition.
- **`get_signing_op_id_for_deploy(checksum, edition)`** -- helper for computing the multisig signing op id needed to upgrade the program.

### Dynamic Dispatch

**`IARC22`** is a Leo `interface`, so transitions can be called dynamically using interface-enforced syntax (`Interface@(target)::function(args)`):

```leo
IARC22@(token_program)::transfer_public(recipient, amount);
IARC22@(token_program)::approve_public(spender, amount);
IARC22@(token_program)::transfer_from_public(owner, recipient, amount);
```

See [ARC-20 Dynamic Dispatch](../arc-0020/#dynamic-dispatch) for the full syntax reference, the `_dynamic_call` intrinsic, and worked examples.

Private transitions (**`transfer_private`**, **`transfer_private_to_public`**, **`transfer_from_public_to_private`**, **`transfer_public_to_private`**, etc.) can also be invoked dynamically -- the caller supplies Merkle non-inclusion proofs where required. **`ComplianceRecord`** outputs return as dynamic records where applicable (see Leo's dynamic records documentation).

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**Compliant token template tests** (`compliant-token-template.test.js`):
- `initialize`: Rejects duplicate initialization; only `DEPLOYER_ADDRESS` may call
- `update_role`: Manager assigns roles; manager cannot demote themselves without `MANAGER_ROLE`
- `mint_public` / `mint_private`: Gated by `MINTER_ROLE`, honor `pause` and `max_supply`; `mint_private` emits a `ComplianceRecord`
- `burn_public` / `burn_private`: Gated by `BURNER_ROLE`; `burn_private` emits a `ComplianceRecord`
- `transfer_public` / `transfer_public_as_signer`: Move balances; reject insufficient balance and frozen sender/recipient
- `approve_public` / `unapprove_public`: Manage allowances (keyed by the `TokenAllowance` struct directly)
- `transfer_from_public`: Spender transfers with allowance
- `transfer_public_to_private` / `transfer_from_public_to_private`: Public-to-private conversions; both emit a `ComplianceRecord`
- `transfer_private_to_public`: Private-to-public conversion with freeze-list non-inclusion proofs; emits a `ComplianceRecord` and returns `(ComplianceRecord, Token, Final)`
- `transfer_private`: Private transfer with freeze-list proofs and `ComplianceRecord`
- `pause/unpause`: `set_pause_status` (gated by `PAUSE_ROLE`) blocks and unblocks transfers
- **`view fn`** reads: `balance_of`, `allowance`, `supply`, `max_supply`, `decimals`, `name`, `symbol`

## Reference Implementations

- [`compliant_token_template/`](./compliant_token_template/) -- **`IARC22`** implementation with freeze list integration, Merkle non-inclusion verification, **`view fn`** metadata/supply reads (`balance_of`, `allowance`, `supply`, `max_supply`, `decimals`, `name`, `symbol`), shared **`add_supply` / `sub_supply`** bookkeeping, role-based admin (`MINTER_ROLE`, `BURNER_ROLE`, `PAUSE_ROLE`, `MANAGER_ROLE`), and multisig-gated upgrades via `multisig_core.aleo`
- [`freezelist/`](./freezelist/) -- On-chain freeze list using a Merkle tree with windowed root updates for proof validity across blocks

## Dependencies

- [ARC-20](../arc-0020/) -- **`IARC22`** tokens mirror ARC-20-style transfer primitives with extra compliance constraints (freeze-list proofs on sensitive paths, **`ComplianceRecord`** emission where specified)
- **Leo compiler** with interface/dynamic dispatch support
- **merkle_tree.aleo** and **multisig_core.aleo** -- Deployed as on-chain dependencies; `merkle_tree.aleo` provides Merkle tree verification primitives, `multisig_core.aleo` gates program upgrades
- **@provablehq/sdk** (for SDK-based testing)
- **@sealance-io/policy-engine-aleo** (Merkle proof generation for tests)

## Backwards Compatibility

ARC-22 is a new standard and has no backwards compatibility concerns. Programs implementing **`IARC22`** are not required to declare Leo conformance to the **`IARC20`** interface from ARC-20, because compliance paths change signatures (freeze-list proofs, **`ComplianceRecord`** outputs, public `recipient` / `amount` inputs on `transfer_private_to_public`).

## Security Considerations

**Freeze list**: The **`IARC22`** surface enforces freeze-list checks on every balance-moving path:

- Fully public sender paths (`transfer_public`, `transfer_public_as_signer`, `transfer_from_public`) read the **`freeze_list`** mapping directly for both sender and recipient.
- Public-sender / private-recipient paths (`transfer_public_to_private`, `transfer_from_public_to_private`) read **`freeze_list`** directly for the sender; recipient is not checked at the freeze-list level because the recipient address may itself be private to the call site.
- Private-sender paths (`transfer_private`, `transfer_private_to_public`) verify Merkle non-inclusion proofs against the current or previous freeze-list Merkle root, plus a direct **`freeze_list`** check on the public recipient in `transfer_private_to_public`.

A windowed root update mechanism allows proofs generated against a previous root to remain valid for `BLOCK_HEIGHT_WINDOW` blocks after a root update, preventing race conditions where a freeze-list update invalidates in-flight transactions.

**Compliance records**: Every transition with a private sender or private recipient emits a **`ComplianceRecord`** owned by `INVESTIGATOR_ADDRESS`, allowing authorized parties to audit those movements while preserving privacy from the general public. The investigator address is hardcoded and can only be changed via a multisig-gated program upgrade.

**Pause kill-switch**: Every balance-moving transition checks `storage pause` and aborts when paused. Only addresses holding `PAUSE_ROLE` can toggle the flag via `set_pause_status`.

**Upgradability**: `compliant_token_template.aleo` and `freezelist.aleo` gate program upgrades behind `multisig_core.aleo` signing operations (see the `@custom` constructor and `get_signing_op_id_for_deploy` helper), ensuring that code changes require multi-party approval.

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
