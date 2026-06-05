---
arc: 20
title: ARC-20 Fungible Token Standard
authors: The Aleo Team <hello@aleo.org>
discussion: https://github.com/ProvableHQ/ARCs/discussions/124
topic: Application
status: Draft
created: 2026-03-18
---

## Abstract

ARC-20 defines a fungible token standard for Aleo, supporting both public and private balances. Programs declare conformance to the `IARC20` interface, and any other program can call them at runtime via dynamic dispatch -- without compile-time knowledge of the specific token implementation.

The standard defines a single **`IARC20`** interface covering public transfers, private transfers, approvals, joins, splits, and **`view fn`** accessors for name, symbol, decimals, balances, allowances, and supply.

For regulated tokens requiring freeze lists and compliance records, see [ARC-22](../arc-0022/).

## Motivation

Without a standard interface, every DeFi program must import each token at compile time, making it impossible to build token-agnostic protocols. ARC-20 solves this through Leo's dynamic dispatch: a single AMM, lending protocol, or exchange can interact with any conforming token by name at runtime, with no recompilation or redeployment required.

## Specification

### Interfaces

#### IARC20

The fungible token interface. Every ARC-20 token must implement these functions and **`view fn`** accessors:

### Record Types

**Token** -- Represents a private token balance. Implementations may add additional fields beyond `owner` and `amount`:

```leo
record Token {
    owner: address,
    amount: u128,
    ..
}
```

The interface explicitly allows extra fields with `..`, but a conforming implementation must include at least `owner: address` and `amount: u128`.



### Dynamic Dispatch

ARC-20 tokens are called via dynamic dispatch, which resolves the target program at runtime. This allows a single program (e.g. an AMM or lending protocol) to interact with *any* ARC20-implementing token without importing it at compile time.

#### Interface-Enforced Syntax

```leo
Interface@(target)::function(args)
```

The target is an `identifier` variable, an `identifier` literal (single-quoted program name), or a `field` value:

```leo
// Call by identifier variable (passed as a function parameter)
IARC20@(token_id)::transfer_public(recipient, amount);

// Call by program name literal
IARC20@('my_token')::transfer_public(recipient, amount);

// Specify both program name and network
IARC20@('my_token', 'aleo')::transfer_public(recipient, amount);
```

The compiler resolves function names and validates argument types against the interface definition. No manual function selector encoding is needed.

#### Example: Swap

A DeFi program that accepts any ARC20 token by program identifier:

```leo
program my_exchange.aleo {
    fn swap(
        public token_in: identifier,   // program name of any ARC20 token
        public token_out: identifier,  // program name of another ARC20 token
        public amount_in: u128,
        public amount_out: u128,
    ) -> Final {
        // Pull tokens from the user (requires prior approve_public)
        let transfer_in: Final = IARC20@(token_in)::transfer_from_public(
            self.signer, self.address, amount_in
        );
        // Send tokens to the user
        let transfer_out: Final = IARC20@(token_out)::transfer_public(
            self.signer, amount_out
        );
        return final {
            transfer_in.run();
            transfer_out.run();
        };
    }
}
```

#### Example: Private Transfer with `dyn record`

For private token operations, `dyn record` provides dynamic records that work with any ARC20 token:

```leo
fn deposit_private(
    private token_record: dyn record,    // any IARC20 Token record
    public token_id: identifier,         // which IARC20 program
    public recipient: address,
    public amount: u128,
) -> (dyn record, Final) {
    let (change, transfer_future): (dyn record, Final) =
        IARC20@(token_id)::transfer_private_to_public(
            token_record, recipient, amount
        );
    return (change, final { transfer_future.run(); });
}
```

#### Example: Implementing an ARC20 Token

A program declares interface conformance with `: InterfaceName`:

```leo
program my_token.aleo: IARC20 {
    record Token {
        owner: address,
        amount: u128,
    }
    // Must implement all functions and view fn accessors from IARC20
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        // ...
    }

    // ... other required functions and view fn accessors
}
```


### Design Notes

- **Additive approvals**: `approve_public` increases the existing allowance rather than replacing it. This avoids race conditions -- two `approve_public` calls in the same block will both succeed and add to the allowance, rather than one silently overwriting the other.

- **u128 amounts**: Future-proofs the standard for high-supply tokens and avoids truncation issues. `u64` would limit maximum supply to ~18.4 quintillion base units, which is insufficient for some token designs.

- **`recipient` naming**: The receiving address is consistently named `recipient` across transfer variants.

- **`transfer_private_to_public` returns `(Token, Final)`**: the spender's private `Token` is consumed during the transfer; the change `Token` (owned by the original spender) is the spender's fresh receipt, avoiding the need to scan `sk_tag` for the spent record.

- **`view fn` on the interface**: `balance_of`, `allowance`, `supply`, `max_supply`, `decimals`, `name`, `symbol` are part of the interface contract so off-consensus consumers (SDK, explorers, indexers) have a uniform read API without depending on implementation-specific mapping/storage layouts.

- **`transfer_from_public_to_private` includes an explicit `recipient`**: Declared **`private`**, so the receiving address is not revealed on-chain, which allows the spender to route the resulting `Token` to a third party.

## Comparison to ERC-20

For developers familiar with Ethereum's ERC-20 standard:

| ERC-20 | ARC-20 (**`IARC20`**) | Notes |
|--------|----------------------|-------|
| `balanceOf(address)` | `view fn balance_of(account) -> u128` | Off-consensus read via Leo v4.0 **`view fn`**; underlying `balances` mapping also queryable directly |
| `totalSupply()` | `view fn supply() -> u128` | Reads `storage token_info.supply`; `view fn max_supply() -> u128` exposes the configured cap |
| `decimals()` | `view fn decimals() -> u8` | Reads `storage token_info.decimals` |
| `name()` / `symbol()` | `view fn name() -> identifier` / `view fn symbol() -> identifier` | Reference wrappers return Leo identifier literals (`'wCredits'`, `'wCRD'`, `'wTokReg'`, `'wTR'`) |
| `allowance(owner, spender)` | `view fn allowance(owner, spender) -> u128` | Reads `allowances` map keyed by `TokenAllowance { account, spender }` |
| `transfer(to, amount)` | `transfer_public(recipient, amount)` | Direct equivalent |
| `approve(spender, amount)` | `approve_public(spender, amount)` | Additive (not replace) -- use `unapprove_public` to decrease |
| `transferFrom(from, to, amount)` | `transfer_from_public(owner, recipient, amount)` | Direct equivalent |
| -- | `transfer_private(input, recipient, amount)` | No ERC-20 equivalent -- private transfers are unique to Aleo |
| -- | `join(a, b)` / `split(a, n)` | Manage record granularity |
| Contract address = token | Program name = token | Each ARC-20 token is its own deployed program |

### Security Considerations

**Approval model**: ARC-20 uses additive approvals -- `approve_public` increases the allowance, and `unapprove_public` decreases it. This differs from ERC-20's replace semantics. To change an allowance from 100 to 50, call `unapprove_public(50)` rather than setting a new value. Calling `approve_public` without first reducing the existing allowance will add to it.

**Arithmetic overflow/underflow**: Leo's `u128` arithmetic aborts the transaction on underflow/overflow (enforced by the Aleo VM). Implementations therefore omit redundant explicit `assert(... >= amount)` checks in `transfer_from_public`, `transfer_from_public_to_private`, and `unapprove_public` -- the VM aborts naturally on underflow.

**`self.caller` vs `self.signer`**: Wrapper programs must carefully distinguish between `self.caller` (the immediate caller, which may be another program) and `self.signer` (the transaction originator). Deposit functions use `self.signer` to pull from the user's underlying balance, while transfer functions use `self.caller` for composability with DeFi programs. The interface exposes both `transfer_public` (caller-scoped) and `transfer_public_as_signer` (signer-scoped) so consumers can pick the appropriate semantics.



## Special Exception: `credits.aleo`

The program for the native Aleo Credits asset cannot directly implement the **`IARC20`** interface for three reasons:

1. **Record name mismatch**: `credits.aleo` defines `record credits`, not `record Token`. The **`IARC20`** interface requires `record Token`. *(Not currently enforced at protocol level, but expected by consuming programs.)*
2. **Record entry name mismatch**: `credits.aleo` uses `microcredits` as the balance field, not `amount`. *(Enforced at protocol level; may become relaxable in future.)*
3. **Record entry type mismatch**: `credits.aleo` uses `u64` for amounts, while **`IARC20`** uses `u128`. *(Permanently enforced -- types affect circuit size and cannot be aliased.)*


### Stateless vs Stateful Wrappers

A **stateless** wrapper (pure forwarding) cannot work because:

- Interface conformance cannot rename records or remap field names
- `self.caller` in the underlying program would be the wrapper, not the original caller -- breaking escrow patterns where a third-party program needs to hold tokens

A **stateful** wrapper maintains its own `balances` mapping and exposes the standard **`IARC20`** interface. Deposit/withdraw functions bridge between the wrapper's internal balances and the underlying program. 

### Public/Private Considerations

- Implementations convert between public and private balances through **`transfer_public_to_private`** / **`transfer_private_to_public`** entirely within wrapper-local state. No interaction with the underlying token is required for these balance moves.
- `transfer_private_to_public` has a UX limitation: the recipient receives tokens in their public balance but cannot learn the private sender's identity (by design). The sender can still locate the spent record off-chain via their `sk_tag`; the returned change `Token` (owned by the spender) also serves as a fresh receipt.


## Copyright

This ARC is placed in the public domain.
