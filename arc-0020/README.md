---
arc: 20
title: ARC-20 Fungible Token Standard
authors: The Aleo Team <hello@aleo.org>
discussion: https://github.com/AleoHQ/ARCs/discussions/42
topic: Application
status: Draft
created: 2026-03-18
---

## Abstract

ARC-20 defines a fungible token standard for Aleo, supporting both public and private balances. Programs declare conformance to the ARC20 interface, and any other program can call them at runtime via dynamic dispatch -- without compile-time knowledge of the specific token implementation.

The standard defines **ARC20**, a minimal interface for public transfers, private transfers, shielding/unshielding, and approvals. An optional **MintableToken** extension adds mint and burn operations. Reference implementations: `wrapped_credits.aleo`, `wrapped_token_registry.aleo`.

For regulated tokens requiring freeze lists and compliance records, see [ARC-22](../arc-0022/).

## Motivation

Without a standard interface, every DeFi program must import each token at compile time, making it impossible to build token-agnostic protocols. ARC-20 solves this through Leo's dynamic dispatch: a single AMM, lending protocol, or exchange can interact with any conforming token by name at runtime, with no recompilation or redeployment required.

ARC-20 supersedes the previous ARC-20 draft (2023), which was written in Aleo instructions without interface support.

## Specification

### Interfaces

#### ARC20

The minimal fungible token interface. Every ARC-20 token must implement these functions:

```leo
interface ARC20 {
    record Token;
    record Metadata {
        owner: address,
        sender: address,
        ..
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Metadata, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Token, Final);

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public amount: u128) -> (Token, Final);
}
```

#### MintableToken

Optional extension for tokens backed by deposits (e.g. wrapped credits, wrapped registry tokens):

```leo
interface MintableToken: ARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public amount: u128) -> Final;
    fn burn_private(input: Token) -> Final;
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

**Metadata** -- Emitted by `transfer_private_to_public`. The recipient and amount are already visible as public inputs, but the sender's identity is hidden. The Metadata record is owned by the sender, giving them a private receipt of the transfer that only they can decrypt:
```leo
record Metadata {
    owner: address,     // set to the sender's address
    sender: address,
}
```

### Programs

| Program | Description |
|---------|-------------|
| `token_registry.aleo` | Multi-token registry supporting token registration, role-based access, and authorized balances. Manages public and private balances for arbitrary token IDs. |
| `wrapped_credits.aleo` | ARC20 + MintableToken wrapper around `credits.aleo`. Deposits Aleo credits and issues 1:1 wrapped tokens implementing the standard interface. |
| `wrapped_token_registry.aleo` | ARC20 + MintableToken wrapper around a specific `token_registry.aleo` token ID. Demonstrates wrapping registry tokens behind the standard interface. |
| `dummy_exchange.aleo` | Dynamic dispatch example -- demonstrates `transfer_from_public` and `swap` to interact with any ARC20 token by program identifier at runtime. |

### Dynamic Dispatch

ARC-20 tokens are called via dynamic dispatch, which resolves the target program at runtime. This allows a single program (e.g. an AMM or lending protocol) to interact with *any* ARC20-implementing token without importing it at compile time.

Leo provides two ways to make dynamic calls:

1. **Interface-enforced syntax** ([leo#29201](https://github.com/ProvableHQ/leo/pull/29201)) -- the compiler validates function names, argument types, and return types against the interface definition at compile time. This is the recommended approach.
2. **`_dynamic_call` intrinsic** -- a low-level escape hatch that bypasses interface checking. The caller manually encodes function selectors as `field` constants and is responsible for passing correct arguments. Useful when working below the interface abstraction or with programs that don't declare interface conformance.

#### Interface-Enforced Syntax

```leo
Interface@(target)/function(args)
```

The target is an `identifier` variable, an `identifier` literal (single-quoted program name), or a `field` value:

```leo
// Call by identifier variable (passed as a function parameter)
ARC20@(token_id)/transfer_public(recipient, amount);

// Call by program name literal
ARC20@('my_token')/transfer_public(recipient, amount);

// Specify both program name and network
ARC20@('my_token', 'aleo')/transfer_public(recipient, amount);
```

The compiler resolves function names and validates argument types against the interface definition. No manual function selector encoding is needed.

#### Example: Swap

A DeFi program that accepts any ARC20 token by program identifier:

```leo
program my_exchange.aleo {
    fn swap(
        public token_in: identifier,   // program name of any ARC20 token
        public token_out: identifier,   // program name of another ARC20 token
        public amount_in: u128,
        public amount_out: u128,
    ) -> Final {
        // Pull tokens from the user (requires prior approve_public)
        let transfer_in: Final = ARC20@(token_in)/transfer_from_public(
            self.signer, self.address, amount_in
        );
        // Send tokens to the user
        let transfer_out: Final = ARC20@(token_out)/transfer_public(
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
    private token_record: dyn record,    // any ARC20 Token record
    public token_id: identifier,         // which ARC20 program
    public amount: u128,
) -> (dyn record, Final) {
    let (change, transfer_future): (dyn record, Final) =
        ARC20@(token_id)/transfer_private_to_public(
            token_record, self.address, amount
        );
    return (change, final { transfer_future.run(); });
}
```

See `dummy_exchange.aleo` for a working dynamic dispatch example, and the [AMM reference implementation](https://github.com/ProvableHQ/leo-programs/tree/main/amm) for a full example.

#### Example: Implementing an ARC20 Token

A program declares interface conformance with `: InterfaceName`:

```leo
interface ARC20 {
    record Token;
    record Metadata { owner: address, sender: address, .. }
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    // ... other required functions
}

interface MintableToken: ARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    // ... mint/burn functions
}

program my_token.aleo: MintableToken {
    record Token {
        owner: address,
        amount: u128,
    }
    // Must implement all functions from ARC20 + MintableToken
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        // ...
    }
}
```

See `wrapped_credits.aleo` and `wrapped_token_registry.aleo` for complete implementations.

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**ARC20 shared interface tests** (`arc20-wrapper-tests.js`), run for both `wrapped_credits` and `wrapped_token_registry`:
- All transfer variants (public, private, private-to-public)
- Shield/unshield round-trips
- Approve/unapprove/transfer_from/transfer_from_public_to_private allowance management
- Mint/burn (public and private) via MintableToken extension
- Negative tests: insufficient balance, wrong owner, exceeded allowance

## Rationale

**Additive approvals**: `approve_public` increases the existing allowance rather than replacing it. This avoids race conditions -- two `approve_public` calls in the same block will both succeed and add to the allowance, rather than one silently overwriting the other.

**u128 amounts**: Future-proofs the standard for high-supply tokens and avoids truncation issues. u64 would limit maximum supply to ~18.4 quintillion base units, which is insufficient for some token designs.

**`shield`/`unshield` naming**: `shield` converts the signer's public balance to a private Token record. `unshield` converts a private Token back. The interface also includes `transfer_private_to_public`, which differs from `unshield` in that it allows specifying a recipient and emits a `Metadata` record linking the private sender to the public transfer.

## Reference Implementations

- [`wrapped_credits/`](./wrapped_credits/) -- ARC20 + MintableToken wrapping `credits.aleo`
- [`wrapped_token_registry/`](./wrapped_token_registry/) -- ARC20 + MintableToken wrapping `token_registry.aleo`
- [`token_registry/`](./token_registry/) -- Multi-token registry
- [`dummy_exchange/`](./dummy_exchange/) -- Dynamic dispatch interoperability example

## Dependencies

- **Leo compiler** with interface/dynamic dispatch support
- **@provablehq/sdk** (for SDK-based testing)

## Backwards Compatibility

This ARC supersedes the previous ARC-20 draft (2023). The prior spec was written in Aleo instructions without interface support. Programs implementing the old spec are not compatible with the new interface-based standard.

### Why Wrappers Are Needed

Existing programs cannot directly implement the ARC20 interface for three reasons:

1. **Record name mismatch**: `credits.aleo` defines `record credits`, not `record Token`. The ARC20 interface requires `record Token`. *(Not currently enforced at protocol level, but expected by consuming programs.)*
2. **Record entry name mismatch**: `credits.aleo` uses `microcredits` as the balance field, not `amount`. *(Enforced at protocol level; may become relaxable in future.)*
3. **Record entry type mismatch**: `credits.aleo` uses `u64` for amounts, while ARC20 uses `u128`. *(Permanently enforced -- types affect circuit size and cannot be aliased.)*

### Incompatible Programs

| Program | Record | Transfer Signature | Why Incompatible |
|---------|--------|--------------------|------------------|
| `credits.aleo` | `record credits { owner: address, microcredits: u64 }` | `transfer_public(address, u64)` | Wrong record name/fields, u64 vs u128 |
| `token_registry.aleo` | `record Token { owner, amount, token_id, ... }` | `transfer_public(field, address, u128)` | Extra `token_id` parameter |

Any program whose public transfer signature differs from `transfer_public(address, u128)` requires a stateful wrapper.

### Stateless vs Stateful Wrappers

A **stateless** wrapper (pure forwarding) cannot work because:
- Interface conformance cannot rename records or remap field names
- `self.caller` in the underlying program would be the wrapper, not the original caller -- breaking escrow patterns where a third-party program needs to hold tokens

A **stateful** wrapper maintains its own `balances` mapping and exposes the standard ARC20 interface. Deposit/withdraw functions bridge between the wrapper's internal balances and the underlying program. See `wrapped_credits.aleo` and `wrapped_token_registry.aleo` for reference implementations.

### Shielding Considerations

- `shield` / `unshield` are self-only operations: the signer converts between their own public and private balances
- `transfer_private_to_public` has a UX limitation: the recipient receives tokens in their public balance but cannot learn the private sender's identity (by design)

## Migration Guide: Wrapping Token Registry Tokens

Teams that have already deployed tokens to `token_registry.aleo` can make them ARC20-compatible by deploying a stateful wrapper.

### Why Wrapping Is Needed

`token_registry.aleo` functions take an extra `token_id: field` parameter:
```
token_registry.aleo/transfer_public(token_id, recipient, amount)  // 3 params
ARC20/transfer_public(recipient, amount)                          // 2 params
```
This signature mismatch means `token_registry.aleo` cannot directly implement the ARC20 interface.

### How to Create a Wrapper

1. Deploy a new program implementing `MintableToken` (or `ARC20`)
2. Set a `WRAPPED_TOKEN_ID` constant for your token's ID in the registry
3. Maintain local `balances: address => u128` and `allowances` mappings
4. Implement deposit/withdraw to bridge between the wrapper and the registry:
   - `deposit_token_public(amount)`: calls `token_registry.aleo/transfer_public_as_signer(TOKEN_ID, self.address, amount)`, increments local balance
   - `withdraw_token_public(amount)`: decrements local balance, calls `token_registry.aleo/transfer_public(TOKEN_ID, withdrawer, amount)`
5. Implement all ARC20 functions (`transfer_public`, `shield`, `approve_public`, etc.) operating on local balances

### Deposit/Withdraw Flow

```
                    deposit_token_public(100)                    transfer_public_as_signer
  User  ──────────────────────────────────►  wrapper.aleo       ─────────────────────────────►  token_registry
                                             balances[user]+=100    (TOKEN_ID, self.addr, 100)   balances[wrapper]

                    withdraw_token_public(100)                   transfer_public
  User  ──────────────────────────────────►  wrapper.aleo       ─────────────────────────────►  token_registry
                                             balances[user]-=100    (TOKEN_ID, user, 100)        balances[user]
```

### Reference

See [`wrapped_token_registry/`](./wrapped_token_registry/) for a complete implementation wrapping token ID `99999field`. In the MintableToken extension, `mint_public` acts as deposit (pulls from signer's registry balance) and `burn_public` acts as withdraw (sends back to registry).

## Comparison to ERC-20

For developers familiar with Ethereum's ERC-20 standard:

| ERC-20 | ARC-20 | Notes |
|--------|--------|-------|
| `balanceOf(address)` | Query `balances` mapping via API | No on-chain read-only functions; use off-chain indexers |
| `totalSupply()` | Query `token_info` mapping via API | Off-chain query, same as `balanceOf` |
| `name()` / `symbol()` / `decimals()` | `TokenInfo` struct in `token_info` mapping | Set at initialization; queryable off-chain |
| `transfer(to, amount)` | `transfer_public(recipient, amount)` | Direct equivalent |
| `approve(spender, amount)` | `approve_public(spender, amount)` | Additive (not replace) -- use `unapprove_public` to decrease |
| `transferFrom(from, to, amount)` | `transfer_from_public(owner, recipient, amount)` | Direct equivalent |
| -- | `transfer_private(input, to, amount)` | No ERC-20 equivalent -- private transfers are unique to Aleo |
| -- | `shield(amount)` / `unshield(input, amount)` | Convert between public and private balances |
| Contract address = token | Program name = token | Each ARC20 token is its own deployed program |

## Security Considerations

**Approval model**: ARC-20 uses additive approvals -- `approve_public` increases the allowance, and `unapprove_public` decreases it. This differs from ERC-20's replace semantics. To change an allowance from 100 to 50, call `unapprove_public(50)` rather than setting a new value. Calling `approve_public` without first reducing the existing allowance will add to it.

**Arithmetic overflow/underflow**: Leo's `u128` arithmetic aborts the transaction on underflow/overflow (enforced by the Aleo VM). No explicit checks are needed in implementations.

**Self.caller vs self.signer**: Wrapper programs must carefully distinguish between `self.caller` (the immediate caller, which may be another program) and `self.signer` (the transaction originator). Deposit functions use `self.signer` to pull from the user's underlying balance, while transfer functions use `self.caller` for composability with DeFi programs.

## Testing

Prerequisites:
- Leo compiler with interface support (build from source)
- Node.js 18+

```bash
cd arc-0020/tests
npm install
npm test                    # Run all tests (requires local devnode)
```

Tests start a local devnode, deploy programs with their dependencies, and execute transactions via `leo execute`.

## Copyright

This ARC is placed in the public domain.
