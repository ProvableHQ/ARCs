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

ARC-22 defines a compliant fungible token interface for Aleo. It modifies [ARC-20](../arc-0020/) with freeze-list enforcement and compliance records for regulated token issuers (stablecoins, security tokens). ARC-22 preserves Aleo's privacy guarantees while enabling regulatory oversight through Merkle non-inclusion proofs and investigator-visible compliance records.

## Motivation

ARC-20 provides a minimal token standard but lacks regulatory compliance features required by many real-world token deployments. Regulated tokens compliance mechanisms such as:

1. **Freeze lists** to block sanctioned or compromised addresses from transacting
2. **Audit trails** for private transfers, enabling authorized investigators to review token movements without exposing sender identity to the public

ARC-22 adds these capabilities while preserving Aleo's privacy guarantees through Merkle non-inclusion proofs. Private transfers remain hidden from the public, but produce compliance records visible only to a designated investigator address.

## Specification

### `IARC22`

The compliant token surface adds freeze-list enforcement (via Merkle non-inclusion proofs on private sends) and investigator-visible **`ComplianceRecord`** outputs on every transition that materially changes a balance. Mappings and storage variables are intentionally **not** part of the interface; body—only function signatures and the records (**`Token`**, **`ComplianceRecord`**) form the contract.

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

    //=============================================================
    //               APPROVAL FUNCTIONS
    //=============================================================
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;

    //=============================================================
    //               TRANSFER FUNCTIONS
    //=============================================================
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(
        private recipient: address,
        private amount: u128,
        private input_record: Token,
        private sender_merkle_proofs: [MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        private input_record: Token,
        private sender_merkle_proofs: [MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (
        ComplianceRecord, Token, Final,
    );
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(
        public owner: address,
        private recipient: address,
        public amount: u128,
    ) -> (ComplianceRecord, Token, Final);
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;

    //=============================================================
    //             SHIELD/UNSHIELD FUNCTIONS
    //=============================================================
    fn shield(public amount: u128) -> (ComplianceRecord, Token, Final);
    fn unshield(public amount: u128, input_record: Token) -> (ComplianceRecord, Token, Final);

    //=============================================================
    //               JOIN/SPLIT FUNCTIONS
    //=============================================================
    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);

    //=============================================================
    //                VIEW FUNCTIONS
    //=============================================================
    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}
```

**Merkle non-inclusion proofs** are required only on transitions where the sender is private -- **`transfer_private`** and **`transfer_private_to_public`**. Transitions where the sender is public -- **`transfer_public_to_private`** and **`transfer_from_public_to_private`** -- read the **`freeze_list`** mapping directly for the sender.

**Compliance coverage.** Every transition that moves balances on a private path -- **`transfer_private`**, **`transfer_private_to_public`**, **`transfer_public_to_private`**, and **`transfer_from_public_to_private`** -- emits a **`ComplianceRecord`** owned by **`INVESTIGATOR_ADDRESS`**, so the investigator can decrypt the full sender / recipient / amount tuple whenever at least one side is private.

### Record Types

**Token** -- Represents a private token balance. Implementations may add additional fields beyond `owner` and `amount`:
```leo
record Token {
    owner: address,
    amount: u128,
    ..
}
```

**ComplianceRecord** -- Emitted to the investigator address during the four transitions listed above. Contains the full transfer details for compliance auditing:

```leo
record ComplianceRecord {
    owner: address,  
    amount: u128,
    sender: address,  
    recipient: address, 
    .. 
}
```

The interface declares both records with `..`, so implementations may add fields.

### `IARC22Freezelist`

The freeze list prevents sanctioned or compromised addresses from transacting. It uses a Merkle tree to enable privacy-preserving verification.

```leo
interface ARC22Freezelist {
    mapping freeze_list: address => bool;
    mapping freeze_list_index: u32 => address;
    storage freeze_list_last_index: u32;
    storage current_freeze_list_root: field;
    storage previous_freeze_list_root: field;
    storage root_updated_height: u32;
    storage block_height_window: u32;

    fn initialize(public admin: address, public blocks: u32) -> Final;
    fn update_freeze_list(
        public account: address,
        public action: bool,
        public index: u32,
        public existing_root: field,
        public new_root: field,
    ) -> Final;
    fn verify_non_inclusion_pub(public account: address) -> Final;
    fn verify_non_inclusion_priv(account: address, merkle_proof: [MerkleProof; 2u32]) -> Final;
}
```

#### Merkle Non-Inclusion Proofs

Private transfers require the sender to prove they are **not** on the freeze list without revealing their identity publicly. This is accomplished through non-inclusion proofs:

1. The freeze list is maintained as a sorted Merkle tree of frozen addresses
2. To prove non-inclusion, the sender provides Merkle proofs for two adjacent leaves in the tree, showing that their address falls in the **gap** between them (or before the first / after the last frozen address)
3. The proof verifies against the current (or previous) Merkle root stored on-chain

```leo
struct MerkleProof {
    siblings: [field; MAX_TREE_DEPTH + 1],
    leaf_index: u32,
}
```

#### Windowed Root Updates

When the freeze list is updated, the Merkle root changes. A `block_height_window` mechanism prevents race conditions:

- Both the current and previous Merkle roots are stored on-chain
- Proofs generated against the previous root remain valid for `block_height_window` blocks after a root update
- This allows in-flight transactions with proofs generated before a freeze list update to still succeed

#### `IARC22Freezelist` State

| State Variable | Type | Description |
|----------------|------|-------------|
| `freeze_list` | `address -> bool` | Whether an address is frozen |
| `freeze_list_index` | `u32 -> address` | Ordered index of frozen addresses |
| `freeze_list_last_index` | `u32` | Last used index in the freeze list |
| `current_freeze_list_root` | `field` | Current Merkle root |
| `previous_freeze_list_root` | `field` | Previous Merkle root |
| `root_updated_height` | `u32` | Block height of last root update |
| `block_height_window` | `u32` | Number of blocks the previous root remains valid |

### Compliance Records

Transitions that move balances along a private path emit a **`ComplianceRecord`** with **`owner`** set to a designated investigator address, so only that address can decrypt the record and view the transfer details (sender, recipient, amount). The reference template emits **`ComplianceRecord`** on:

| Transition | `sender` field | `recipient` field |
|------------|----------------|--------------------|
| **`transfer_private`** | `input_record.owner` (private) | `recipient` (private) |
| **`transfer_private_to_public`** | `input_record.owner` (private) | `recipient` (public input) |
| **`transfer_public_to_private`** | `self.caller` (public) | `recipient` (private) |
| **`transfer_from_public_to_private`** | `owner` (public) | `recipient` (private) |
| **`mint_private`** (admin path) | `ZERO_ADDRESS` | `recipient` (private) |
| **`burn_private`** (admin path) | `input_record.owner` | `ZERO_ADDRESS` |

Fully public transitions (**`transfer_public`**, **`transfer_public_as_signer`**, **`transfer_from_public`**, **`mint_public`**, **`burn_public`**) do **not** emit a **`ComplianceRecord`** -- the sender, recipient, and amount are already public inputs visible on-chain.

### ARC22 Tokens In Practice

While not required by the interface, deployers will likely need a set of admin transitions for a fully functioning regulated token in practice:

- **`initialize(name, symbol, decimals, max_supply, admin)`** -- one-time setup, callable only by `DEPLOYER_ADDRESS`; populates `storage token_info`, sets `pause = false`, marks `initialized = true`, and assigns `MANAGER_ROLE` to `admin`.

- **`update_role(new_address, role)`** -- manager-only role bitmask updates; supports `MINTER_ROLE`, `BURNER_ROLE`, `PAUSE_ROLE`, `MANAGER_ROLE`.

- **`mint_public(recipient, amount)` / `mint_private(recipient, amount)`** -- gated by `MINTER_ROLE`; both honor `pause` and `max_supply`. `mint_private` emits a **`ComplianceRecord`** with `sender = ZERO_ADDRESS`.

- **`burn_public(owner, amount)` / `burn_private(input_record, amount)`** -- gated by `BURNER_ROLE`. `burn_private` emits a **`ComplianceRecord`** with `recipient = ZERO_ADDRESS`.

- **`set_pause_status(pause_status)`** -- gated by `PAUSE_ROLE`; toggles the `pause` storage flag, which blocks every balance-moving transition.

- **`Credentials` Record / `transfer_private_with_creds`** -- Allows users to only need to generate the Merkle non-inclusion proof one time, them continue to execute private transfers without needing to reprove (assuming the freeze list root hasn't changed)
```leo
record Credentials {
    owner: address,
    freeze_list_root: field,
}
```
-  **`INVESTIGATOR_ADDRESS`** -- The investigator address should be hardcoded as the `INVESTIGATOR_ADDRESS` constant in `compliant_token_template.aleo`. In practice, this only allows it to be changed by deploying a new edition of the program, which should be gated by multi-sig signing operations. This ensures that changes to the investigator require multi-party approval.



<!-- ## Security Considerations

**Freeze list**: The **`IARC22`** surface enforces freeze-list checks on every balance-moving path:

- Fully public sender paths (`transfer_public`, `transfer_public_as_signer`, `transfer_from_public`) read the **`freeze_list`** mapping directly for both sender and recipient.
- Public-sender / private-recipient paths (`transfer_public_to_private`, `transfer_from_public_to_private`) read **`freeze_list`** directly for the sender; recipient is not checked at the freeze-list level because the recipient address may itself be private to the call site.
- Private-sender paths (`transfer_private`, `transfer_private_to_public`) verify Merkle non-inclusion proofs against the current or previous freeze-list Merkle root, plus a direct **`freeze_list`** check on the public recipient in `transfer_private_to_public`.

A windowed root update mechanism allows proofs generated against a previous root to remain valid for `BLOCK_HEIGHT_WINDOW` blocks after a root update, preventing race conditions where a freeze-list update invalidates in-flight transactions.

**Compliance records**: Every transition with a private sender or private recipient emits a **`ComplianceRecord`** owned by `INVESTIGATOR_ADDRESS`, allowing authorized parties to audit those movements while preserving privacy from the general public. The investigator address is hardcoded and can only be changed via a multisig-gated program upgrade.

**Pause kill-switch**: Every balance-moving transition checks `storage pause` and aborts when paused. Only addresses holding `PAUSE_ROLE` can toggle the flag via `set_pause_status`.

**Upgradability**: `compliant_token_template.aleo` and `freezelist.aleo` gate program upgrades behind `multisig_core.aleo` signing operations (see the `@custom` constructor and `get_signing_op_id_for_deploy` helper), ensuring that code changes require multi-party approval. -->

## Copyright

This ARC is placed in the public domain.
