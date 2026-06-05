---
arc: 22
title: ARC-22 Compliant Fungible Token Standard
authors: The Aleo Team <hello@aleo.org>
discussion:
topic: Application
status: Draft
created: 2026-03-18
signature_domain: aleo-gov-22-v1
pass_threshold: 66
quorum_threshold: 66
voting_start: 19060000
voting_end: 19260000
snapshot: 19260000
---

## Abstract

ARC-22 defines a compliant fungible token interface for Aleo. It modifies [ARC-20](../arc-0020/) with freeze-list enforcement and compliance records for regulated token issuers (stablecoins, security tokens). ARC-22 preserves Aleo's privacy guarantees while enabling regulatory oversight through Merkle non-inclusion proofs and investigator-visible compliance records.

## Motivation

ARC-20 provides a minimal token standard but lacks regulatory compliance features required by many real-world token deployments. Regulated tokens need compliance mechanisms such as:

1. **Freeze lists** to block sanctioned or compromised addresses from transacting
2. **Audit trails** for private transfers, enabling authorized investigators to review token movements without exposing sender identity to the public

ARC-22 adds these capabilities while preserving Aleo's privacy guarantees through Merkle non-inclusion proofs. Private transfers remain hidden from the public, but produce compliance records visible only to a designated investigator address.

## Specification

The ARC-22 standard provides a library ([`IARC22`](./IARC22)), which is composed of:

- Two interfaces, **`IARC22`** and **`IARC22Freezelist`**, defining the token and freeze-list contracts
- A **`MerkleProof`** struct used by the non-inclusion proof flow
- A small set of **constants** (`MAX_TREE_DEPTH`, `ZERO_ADDRESS`, `EMPTY_ROOT`)
- **Merkle helper functions** that implementations call to verify proofs

### `IARC22`

The compliant token surface adds freeze-list enforcement (via Merkle non-inclusion proofs on private sends) and investigator-visible **`ComplianceRecord`** outputs on every transition that materially changes a balance. Mappings and storage variables are intentionally **not** part of the interface; only function signatures and the records (**`Token`**, **`ComplianceRecord`**) form the contract.

**Merkle non-inclusion proofs** are required only on transitions where the sender is private -- **`transfer_private`** and **`transfer_private_to_public`**. Transitions where the sender is public -- **`transfer_public_to_private`** and **`transfer_from_public_to_private`** -- check the sender against the freeze list directly via **`is_frozen_address`** (or the equivalent **`verify_non_inclusion_pub`** helper).

**Compliance coverage.** Every transition that moves balances on a private path -- **`transfer_private`**, **`transfer_private_to_public`**, **`transfer_public_to_private`**, and **`transfer_from_public_to_private`** -- emits a **`ComplianceRecord`** owned by **`INVESTIGATOR_ADDRESS`**, so the investigator can decrypt the full sender / recipient / amount tuple whenever at least one side is private.

#### Record Types

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
    owner: address,     // INVESTIGATOR_ADDRESS
    amount: u128,
    sender: address,    // ZERO_ADDRESS for mint paths
    recipient: address, // ZERO_ADDRESS for burn paths
    ..
}
```

The interface declares both records with `..`, so implementations may add fields.

### `IARC22Freezelist`

The freeze list prevents sanctioned or compromised addresses from transacting. It uses a Merkle tree to enable privacy-preserving verification.

```leo
interface IARC22Freezelist {
    fn initialize(public admin: address, public blocks: u32) -> Final;
    fn update_freeze_list(
        public account: address,
        public is_frozen: bool,
        public index: u32,
        public existing_root: field,
        public new_root: field,
    ) -> Final;
    fn verify_non_inclusion_pub(public account: address) -> Final;
    fn verify_non_inclusion_priv(account: address, merkle_proof: [MerkleProof; 2u32]) -> Final;

    //=============================================================
    //                VIEW FUNCTIONS
    //=============================================================
    view fn is_frozen_address(account: address) -> bool;
    view fn is_frozen_index(index: u32) -> bool;
    view fn current_freeze_list_root() -> field;
    view fn previous_freeze_list_root() -> field;
    view fn root_updated_height() -> u32;
    view fn block_height_window() -> u32;
}
```

As with **`IARC22`**, mappings and storage variables are intentionally **not** part of the interface; implementations are free to choose their own backing storage. State is exposed exclusively through the view functions above.

#### Merkle Non-Inclusion Proofs

Private transfers require the sender to prove they are **not** on the freeze list without revealing their identity publicly. This is accomplished through non-inclusion proofs:

1. The freeze list is maintained as a sorted Merkle tree of frozen addresses
2. To prove non-inclusion, the sender provides Merkle proofs for two adjacent leaves in the tree, showing that their address falls in the **gap** between them (or before the first / after the last frozen address)
3. The proof verifies against the current (or previous) Merkle root stored on-chain

The `MerkleProof` struct (defined in the `IARC22` library, see below) carries the sibling path and leaf index used for verification.

#### Windowed Root Updates

When the freeze list is updated, the Merkle root changes. A `block_height_window` mechanism prevents race conditions:

- Both the current and previous Merkle roots are stored on-chain
- Proofs generated against the previous root remain valid for `block_height_window` blocks after a root update
- This allows in-flight transactions with proofs generated before a freeze list update to still succeed

#### `IARC22Freezelist` View Functions

| View Function | Returns | Description |
|---------------|---------|-------------|
| `is_frozen_address(account)` | `bool` | Whether `account` is currently on the freeze list |
| `is_frozen_index(index)` | `bool` | Whether the slot at `index` is occupied by a frozen address |
| `current_freeze_list_root()` | `field` | The current Merkle root of the freeze-list tree |
| `previous_freeze_list_root()` | `field` | The previous Merkle root, still valid within the block-height window |
| `root_updated_height()` | `u32` | Block height at which the root was last updated |
| `block_height_window()` | `u32` | Number of blocks for which the previous root remains valid |

### Library Constants

The `IARC22` library exports the following constants. Implementations should use these values.

| Constant | Type | Value | Purpose |
|----------|------|-------|---------|
| `MAX_TREE_DEPTH` | `u32` | `15u32` | Maximum depth of the freeze-list Merkle tree. Bounds the `siblings` array size at `MAX_TREE_DEPTH + 1`. |
| `ZERO_ADDRESS` | `address` | `aleo1qqq...3ljyzc` (encoding of `0field`) | Sentinel used as `sender` for mint paths and `recipient` for burn paths in `ComplianceRecord`. |
| `EMPTY_ROOT` | `field` | `H(ZERO_ADDRESS, ZERO_ADDRESS)` (Poseidon-based) | Initial Merkle root of an empty freeze list, used at `initialize` time. |

### `MerkleProof`

`MerkleProof` is defined in the `IARC22` library itself. Implementations reference it directly as `MerkleProof`.

```leo
struct MerkleProof {
    siblings: [field; MAX_TREE_DEPTH + 1],
    leaf_index: u32,
}
```

### Merkle Helper Functions

The library exposes helpers that implementations use to verify Merkle proofs. They use Poseidon4 hashes with a domain-separation tag (`0field` for internal nodes, `1field` for leaf pairs).

| Function | Signature | Purpose |
|----------|-----------|---------|
| `calculate_hash_for_nodes` | `(sibling1: field, sibling2: field, indexbit: u32) -> field` | Hash two internal sibling nodes, ordered by `indexbit`. |
| `calculate_hash_for_leaves` | `(sibling1: field, sibling2: field, indexbit: u32) -> field` | Hash the leaf-level sibling pair, ordered by `indexbit`. |
| `calculate_root_depth_siblings` | `(merkle_proof: MerkleProof) -> (field, u32)` | Reconstruct the Merkle root from a proof; stops at the first `0field` sibling and returns `(root, depth)`. |
| `verify_inclusion` | `(addr: address, merkle_proof: MerkleProof) -> field` | Assert `addr` matches the leaf and return the reconstructed root for comparison against a known root. |
| `verify_non_inclusion` | `(addr: address, merkle_proofs: [MerkleProof; 2]) -> field` | Verify `addr` falls in the gap between two adjacent sorted leaves (or before the first / after the last) and return the common root. |

`verify_non_inclusion` assumes the freeze-list tree is sorted in ascending order by address (cast to `field`). It is the function private senders rely on to prove they are not on the freeze list.

### Compliance Records

Transitions that move balances along a private path emit a **`ComplianceRecord`** with **`owner`** set to a designated investigator address, so only that address can decrypt the record and view the transfer details (sender, recipient, amount). The reference template emits **`ComplianceRecord`** on the following transitions. The first four are part of the **`IARC22`** interface; **`mint_private`** and **`burn_private`** are admin extensions added by the reference template (see "ARC22 Tokens In Practice" below) and are **not** part of the interface.

| Transition | Part of `IARC22`? | `sender` field | `recipient` field |
|------------|-------------------|----------------|--------------------|
| **`transfer_private`** | yes | `input_record.owner` (private) | `recipient` (private) |
| **`transfer_private_to_public`** | yes | `input_record.owner` (private) | `recipient` (public input) |
| **`transfer_public_to_private`** | yes | `self.caller` (public) | `recipient` (private) |
| **`transfer_from_public_to_private`** | yes | `owner` (public) | `recipient` (private) |
| **`mint_private`** (admin path) | no | `ZERO_ADDRESS` | `recipient` (private) |
| **`burn_private`** (admin path) | no | `input_record.owner` | `ZERO_ADDRESS` |

Fully public transitions (**`transfer_public`**, **`transfer_public_as_signer`**, **`transfer_from_public`**, **`mint_public`**, **`burn_public`**) do **not** emit a **`ComplianceRecord`** -- the sender, recipient, and amount are already public inputs visible on-chain.

### ARC22 Tokens In Practice

While not required by the interface, deployers will likely need a set of admin capabilities for a fully-functioning regulated token:

- **Role-gated Access Controls** -- various predefined roles that only allow an approved subset of users to call certain functions.  Roles may include `MINTER_ROLE`, `BURNER_ROLE`, `PAUSE_ROLE`, `MANAGER_ROLE`, and `FREEZELIST_MANAGER_ROLE`.

- **`initialize(name, symbol, decimals, max_supply, admin)`** -- one-time setup, callable only by `DEPLOYER_ADDRESS`; populates `storage token_info`, sets `pause = false`, marks `initialized = true`, and assigns `MANAGER_ROLE` to `admin`.

- **`update_role(new_address, role)`** -- manager-only role bitmask updates; supports `MINTER_ROLE`, `BURNER_ROLE`, `PAUSE_ROLE`, `MANAGER_ROLE`.

- **`mint_public(recipient, amount)` / `mint_private(recipient, amount)`** -- gated by `MINTER_ROLE`; both honor `pause` and `max_supply`. `mint_private` emits a **`ComplianceRecord`** with `sender = ZERO_ADDRESS`.

- **`burn_public(owner, amount)` / `burn_private(input_record, amount)`** -- gated by `BURNER_ROLE`. `burn_private` emits a **`ComplianceRecord`** with `recipient = ZERO_ADDRESS`.

- **`set_pause_status(pause_status)`** -- gated by `PAUSE_ROLE`; toggles the `pause` storage flag, which blocks every balance-moving transition.

- **`Credentials` Record / `transfer_private_with_creds` / `transfer_private_to_public_with_creds`** -- Allows users to only need to generate the Merkle non-inclusion proof one time, then continue to execute private transfers without needing to reprove (assuming the freeze list root hasn't changed)
```leo
record Credentials {
    owner: address,
    freeze_list_root: field,
}
```
-  **`INVESTIGATOR_ADDRESS`** -- The investigator address should be hardcoded as the `INVESTIGATOR_ADDRESS` constant in `compliant_token_template.aleo`. In practice, this only allows it to be changed by deploying a new edition of the program, which should be gated by multi-sig signing operations. This ensures that changes to the investigator require multi-party approval.



<!-- ## Security Considerations

**Freeze list**: The **`IARC22`** surface enforces freeze-list checks on every balance-moving path:

- Fully public sender paths (`transfer_public`, `transfer_public_as_signer`, `transfer_from_public`) check the freeze list directly via **`is_frozen_address`** (or **`verify_non_inclusion_pub`**) for both sender and recipient.
- Public-sender / private-recipient paths (`transfer_public_to_private`, `transfer_from_public_to_private`) check the sender via **`is_frozen_address`**; the recipient is not checked at the freeze-list level because the recipient address may itself be private to the call site.
- Private-sender paths (`transfer_private`, `transfer_private_to_public`) verify Merkle non-inclusion proofs against the current or previous freeze-list Merkle root, plus a direct **`is_frozen_address`** check on the public recipient in `transfer_private_to_public`.

A windowed root update mechanism allows proofs generated against a previous root to remain valid for `BLOCK_HEIGHT_WINDOW` blocks after a root update, preventing race conditions where a freeze-list update invalidates in-flight transactions.

**Compliance records**: Every transition with a private sender or private recipient emits a **`ComplianceRecord`** owned by `INVESTIGATOR_ADDRESS`, allowing authorized parties to audit those movements while preserving privacy from the general public. The investigator address is hardcoded and can only be changed via a multisig-gated program upgrade.

**Pause kill-switch**: Every balance-moving transition checks `storage pause` and aborts when paused. Only addresses holding `PAUSE_ROLE` can toggle the flag via `set_pause_status`.

**Upgradability**: `compliant_token_template.aleo` gates program upgrades behind `multisig_core.aleo` signing operations (see the `@custom` constructor and `get_signing_op_id_for_deploy` helper), ensuring that code changes require multi-party approval. -->

## Copyright

This ARC is placed in the public domain.
