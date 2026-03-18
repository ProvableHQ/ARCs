---
arc: 20
title: Token Standard
authors: TBD
discussion: TBD
topic: Application
status: Draft
created: 2026-02-27
---

## Abstract

ARC-0020 defines a standard interface for fungible tokens on Aleo, leveraging ARC-0009 (Dynamic Dispatch) to enable composable, interface-based token interactions. This standard supersedes the deprecated ARC-0021 (Multi-Token Standard) and is designed to work natively with the Aleo Virtual Machine's built-in `credits.aleo` program.

Unlike ARC-0021, which required a centralized multi-token support program due to the absence of dynamic dispatch, ARC-0020 defines a standard interface that any token program can implement. DeFi protocols and other consumers can call tokens through the interface without compile-time knowledge of the specific token program, enabling true composability.

## Specification

### Interfaces

ARC-0020 defines three Leo interfaces. Conforming programs declare which interface they implement in their program header (e.g. `program my_token.aleo: ARC20`).

#### `ARC20`

The core fungible token interface. Every ARC-0020-compliant program must implement all transitions in `ARC20`.

```leo
interface ARC20 {
    record Token;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Final);
    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Token, Final);

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public amount: u128) -> (Token, Final);
}
```

#### `MintableToken: ARC20`

Extends `ARC20` with supply management. Programs that control their own issuance (e.g. wrapped tokens) should implement this interface.

```leo
interface MintableToken: ARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public amount: u128) -> Final;
    fn burn_private(input: Token) -> Final;
}
```

#### `ARC20Compliant`

For tokens requiring KYC/AML controls. Private transfers accept Merkle non-inclusion proofs that prove the sender is not on the freeze list, while preserving sender privacy. Every private transfer emits a `ComplianceRecord` to a designated investigator address.

```leo
interface ARC20Compliant {
    record Token;
    record ComplianceRecord;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;

    fn transfer_private(recipient: address, amount: u128, input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(public recipient: address, public amount: u128, input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final);
    fn transfer_from_public_to_private(public owner: address, recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final);
    fn shield(public amount: u128) -> (ComplianceRecord, Token, Final);
    fn unshield(public recipient: address, public amount: u128, input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Final);
}
```

### Required Mappings

All ARC-0020 programs must maintain:

- `balances: address => u128` — public token balances per address
- `allowances: TokenAllowance => u128` — approved spending amounts, keyed by `{ account, spender }`

where `TokenAllowance` is defined as:

```leo
struct TokenAllowance {
    account: address,
    spender: address,
}
```

Programs may use a hash of `TokenAllowance` as the mapping key (e.g. `BHP256::hash_to_field(allowance)`).

### Required Record Type

All ARC-0020 programs must define a `Token` record with at minimum:

```leo
record Token {
    owner: address,
    amount: u128,
}
```

### Transition Semantics

**`transfer_public(recipient, amount)`**
Deducts `amount` from the caller's public balance and adds it to `recipient`'s balance. Must fail if caller's balance is insufficient.

**`transfer_private(input, to, amount) → (Token, Token)`**
Splits a private `Token` record: returns a change token to the original owner and a new token to `to`. `input.amount` must be ≥ `amount`. No finalize step required.

**`transfer_private_to_public(input, to, amount) → (Token, Final)`**
Burns `amount` from the private `input` record and credits it to `to`'s public balance in finalize.

**`shield(amount) → (Token, Final)`**
Converts `amount` from the signer's public balance into a private `Token` record.

**`unshield(input, amount) → (Token, Token, Final)`**
Converts `amount` from the private `input` record back to public balance. Returns a change token and a zero token.

**`approve_public(spender, amount)`**
Increases the caller's allowance for `spender` by `amount`.

**`unapprove_public(spender, amount)`**
Decreases the caller's allowance for `spender` by `amount`. Must fail if the current allowance is less than `amount`.

**`transfer_from_public(owner, recipient, amount)`**
Transfers `amount` from `owner`'s public balance to `recipient`, deducting from the caller's allowance from `owner`. Must fail if allowance or balance is insufficient.

**`transfer_from_public_to_private(owner, amount) → (Token, Final)`**
Transfers `amount` from `owner`'s public balance into a private `Token` owned by the caller, deducting from the caller's allowance from `owner`.

### Token Registry

Token programs that wrap assets from `token_registry.aleo` must register their token ID with the registry before minting. The registry enforces:
- Unique token IDs
- Per-token supply caps (`max_supply`)
- Role-based access control: minter, burner, and supply manager roles
- Optional external authorization for compliance-sensitive tokens (balance authorization that expires at a given block height)

The reserved token ID for native Aleo credits in the registry is:
```
CREDITS_RESERVED_TOKEN_ID = 3443843282313283355522573239085696902919850365217539366784739393210722344986field
```

### Credits Integration

The built-in `credits.aleo` program is ARC-0020 compatible. `wrapped_credits.aleo` demonstrates how to wrap it: deposit credits to receive ARC20 tokens, withdraw tokens to reclaim credits. The wrapped token holds the underlying credits at its own program address.

### Allowance Model

Allowances are additive: `approve_public` increases an existing allowance rather than overriding it. To set an exact allowance, call `unapprove_public` to zero it out first, then call `approve_public`.

## Reference Implementations

The [`../arc-0020-2026/`](../arc-0020-2026/) directory contains runnable reference implementations with a full test suite.

The [`programs/dispatchers/`](./programs/dispatchers/) directory contains dispatcher programs demonstrating ARC-0009 dynamic dispatch: invoking any ARC20-compliant token at runtime without compile-time knowledge of the token program ID.

## Dependencies

- **ARC-0009** — Dynamic Dispatch: required for interface-based token interactions
- `credits.aleo` — the built-in Aleo credits program

### Backwards Compatibility

This standard is not backwards compatible with ARC-0021. Programs implementing ARC-0021 will need to be updated to conform to ARC-0020.

ARC-0021 is deprecated.

## Security & Compliance

**Authorization**: All public transfers check the caller's balance or allowance in finalize; arithmetic underflow is caught by the AVM.

**Double-spend prevention**: Private token records are consumed by the AVM upon use; a spent record cannot be reused.

**Compliance hooks**: Programs implementing `ARC20Compliant` emit a `ComplianceRecord` on every private transfer. The record is owned by a designated investigator address and contains sender, recipient, and amount. The investigator can decrypt it; no one else can.

**Freeze list**: `compliant_token_template.aleo` uses a sorted Merkle tree stored in `freezelist.aleo`. Private transfers require a non-inclusion proof (two adjacent Merkle paths bracketing the sender's address), which proves the sender is not frozen without revealing the sender to on-chain observers.

**Upgrades**: Programs using `@custom constructor` with `multisig_core.aleo` require multi-party approval before an upgrade can be deployed. The signing operation ID is derived from the new program's checksum and edition number.

## References

- [ARC-0009: Dynamic Dispatch](../arc-0009/README.md)
- [ARC-0021: Multi-Token Standard (Deprecated)](../arc-0021/README.md)
- [Reference implementations](../arc-0020-2026/)
