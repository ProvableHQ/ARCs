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

The reference program [`compliant_token_template.aleo`](./compliant_token_template/) declares Leo interfaces **`IARC22`** (core transfers, **`view fn`** reads, and compliance-bearing transitions) and **`IARC22Mintable: IARC22`** (**`mint_*` / `burn_*`**). Earlier discussion may use the shorthand **ARC20 compliant** for this surface; the signatures below match [`compliant_token_template/src/main.leo`](./compliant_token_template/src/main.leo).

## Motivation

ARC-20 provides a minimal token standard but lacks regulatory compliance features required by many real-world token deployments. Regulated tokens need:

1. **Freeze lists** to block sanctioned or compromised addresses from transacting
2. **Audit trails** for private transfers, enabling authorized investigators to review token movements without exposing sender identity to the public

ARC-22 adds these capabilities while preserving Aleo's privacy guarantees through Merkle non-inclusion proofs. Private transfers remain hidden from the public, but produce compliance records visible only to a designated investigator address.

## Specification

### `IARC22` and `IARC22Mintable`

The compliant token surface adds freeze-list enforcement (via Merkle non-inclusion proofs on private sends) and investigator-visible **`ComplianceRecord`** outputs where specified. Mappings and storage variables are intentionally **not** part of the interface body—only function signatures and the records (**`Token`**, **`ComplianceRecord`**) form the contract.

Mint and burn are isolated on **`IARC22Mintable: IARC22`** so consumers can type dynamic calls against a core compliant token vs. a mintable deployment.

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
    ) -> (Token, Final);

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (
        ComplianceRecord, Token, Final,
    );

    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);

    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn total_supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> u128;
    view fn symbol() -> u128;
}

interface IARC22Mintable: IARC22 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final);
    fn burn_public(public owner: address, public amount: u128) -> Final;
    fn burn_private(input_record: Token, public amount: u128) -> (ComplianceRecord, Token, Final);
}
```

**Public ↔ private without dedicated `shield` / `unshield`.** The reference template does not expose separate shield or unshield transitions. Use **`transfer_public_to_private`** (caller debits public balance; mints private **`Token`** plus **`ComplianceRecord`**) and **`transfer_private_to_public`** (private **`Token`** in; credits recipient public balance; returns change **`Token`** and **`Final`**).

**Private→public return type.** **`transfer_private_to_public`** returns **`(Token, Final)`** only—no investigator **`Metadata`** record type. Amount and recipient are already **`public`** inputs on the transition; auditing uses those inputs plus emitted **`ComplianceRecord`** on other paths.

### Record Types

**Token** -- Represents a private token balance:
```leo
record Token {
    owner: address,
    amount: u128,
}
```

**ComplianceRecord** -- Emitted to the investigator address during private transfers and other transitions where the interface specifies it. Contains the full transfer details for compliance auditing:

```leo
record ComplianceRecord {
    owner: address,     // investigator address
    amount: u128,
    sender: address,
    recipient: address,
}
```

**`transfer_private_to_public`** -- Returns **`(Token, Final)`** in [`compliant_token_template`](./compliant_token_template/src/main.leo). There is no separate investigator **`Metadata`** record type; **`amount`** and **`recipient`** are **`public`** inputs on the transition (visible on-chain). Implementations that want an encrypted investigator receipt could extend this pattern with an additional output record in a future revision.

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

Private transfers that take Merkle proofs emit a **`ComplianceRecord`** with **`owner`** set to **`INVESTIGATOR_ADDRESS`**, so only the investigator can decrypt the record and view the transfer details (sender, recipient, amount).

**`transfer_private_to_public`** does **not** emit a **`ComplianceRecord`** or a separate **`Metadata`** record in [`compliant_token_template`](./compliant_token_template/src/main.leo); **`amount`** and **`recipient`** are **`public`** inputs, so they are directly visible on-chain for auditing.

### Investigator Address

The investigator address is hardcoded as the `INVESTIGATOR_ADDRESS` constant in `compliant_token_template.aleo`. It can only be changed by deploying a new edition of the program, which is gated by `multisig_core.aleo` signing operations. This ensures that changes to the investigator require multi-party approval.

### Dynamic Dispatch

**`IARC22`** / **`IARC22Mintable`** are Leo `interface`s, so transitions can be called dynamically using interface-enforced syntax (`Interface@(target)::function(args)`):

```leo
IARC22@(token_program)::transfer_public(recipient, amount);
IARC22@(token_program)::approve_public(spender, amount);
IARC22@(token_program)::transfer_from_public(owner, recipient, amount);
```

See [ARC-20 Dynamic Dispatch](../arc-0020/#dynamic-dispatch) for the full syntax reference, the `_dynamic_call` intrinsic, and worked examples.

Private transitions (**`transfer_private`**, **`transfer_private_to_public`**, **`mint_private`**, **`burn_private`**, **`transfer_from_public_to_private`**, **`transfer_public_to_private`**, etc.) can also be invoked dynamically—the caller supplies Merkle non-inclusion proofs where required. **`ComplianceRecord`** outputs return as dynamic records where applicable (see Leo’s dynamic records documentation).

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**Compliant token template tests** (`compliant-token-template.test.js`):
- `initialize`: Rejects duplicate initialization
- `transfer_public` / `transfer_public_as_signer`: Move balances; reject insufficient balance and frozen sender/recipient
- `approve_public` / `unapprove_public`: Manage allowances (keyed by the `TokenAllowance` struct directly)
- `transfer_from_public`: Spender transfers with allowance
- `transfer_public_to_private` / `transfer_from_public_to_private`: Public-to-private conversions with `ComplianceRecord` emission (no separate `shield` transition—the test harness may treat these flows as “shielding”)
- `transfer_private_to_public`: Private-to-public conversion with freeze-list proofs; returns **`(Token, Final)`** only (tests may label this path “unshield” alongside registry-style wrappers)
- `transfer_private`: Private transfer with freeze-list proof and `ComplianceRecord`
- `mint_public`: Minter increases recipient balance; non-minter is rejected
- `mint_private`: Minter creates private Token with `ComplianceRecord`
- `burn_public` / `burn_private`: Burner decreases owner balance; non-burner is rejected
- `pause/unpause`: `set_pause_status` blocks and unblocks transfers

## Reference Implementations

- [`compliant_token_template/`](./compliant_token_template/) -- **`IARC22` + `IARC22Mintable`** implementation with freeze list integration, Merkle proof non-inclusion verification, **`view fn`** metadata/supply reads, **`add_supply` / `sub_supply`** bookkeeping, and multisig-gated upgrades
- [`freezelist/`](./freezelist/) -- On-chain freeze list using a Merkle tree with windowed root updates for proof validity across blocks

## Dependencies

- [ARC-20](../arc-0020/) -- **`IARC22`** tokens mirror ARC-20-style transfer primitives with extra compliance constraints (freeze-list proofs on sensitive paths, **`ComplianceRecord`** emission where specified)
- **Leo compiler** with interface/dynamic dispatch support
- **merkle_tree.aleo** and **multisig_core.aleo** -- Deployed as on-chain dependencies; `merkle_tree.aleo` provides Merkle tree verification primitives, `multisig_core.aleo` gates program upgrades
- **@provablehq/sdk** (for SDK-based testing)
- **@sealance-io/policy-engine-aleo** (Merkle proof generation for tests)

## Backwards Compatibility

ARC-22 is a new standard and has no backwards compatibility concerns. Programs implementing **`IARC22`** are not required to declare Leo conformance to the base **`ARC20`** interface name from ARC-20, because compliance paths change signatures (freeze-list proofs, **`ComplianceRecord`** outputs).

## Security Considerations

**Freeze list**: The **`IARC22`** surface enforces freeze-list checks on paths that carry Merkle proofs via Merkle proof non-inclusion. Public transfers check the **`freeze_list`** mapping directly. A windowed root update mechanism allows proofs generated against a previous root to remain valid for a configurable number of blocks after a root update, preventing race conditions where a freeze list update invalidates in-flight transactions.

**Compliance records**: Private transfers emit a **`ComplianceRecord`** to the designated investigator address where the interface specifies it, allowing authorized parties to audit those movements while preserving sender privacy from the general public. The investigator address is hardcoded and can only be changed via multisig-gated program upgrade.

**Public inputs on private→public**: For **`transfer_private_to_public`**, **`amount`** and **`recipient`** are **`public`** inputs; the reference template does not add a separate investigator-only receipt record—auditability relies on those inputs.

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
