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

The standard defines a single **`IARC20`** interface covering public transfers, private transfers, approvals, joins, splits, and **`view fn`** accessors for name, symbol, decimals, balances, allowances, and supply. Reference deployments **[`wrapped_credits.aleo`](./wrapped_credits/)** and **[`wrapped_token_registry.aleo`](./wrapped_token_registry/)** both declare conformance to **`IARC20`** with identical interface signatures.

For regulated tokens requiring freeze lists and compliance records, see [ARC-22](../arc-0022/).

## Motivation

Without a standard interface, every DeFi program must import each token at compile time, making it impossible to build token-agnostic protocols. ARC-20 solves this through Leo's dynamic dispatch: a single AMM, lending protocol, or exchange can interact with any conforming token by name at runtime, with no recompilation or redeployment required.

ARC-20 supersedes the previous ARC-20 draft (2023), which was written in Aleo instructions without interface support.

## Specification

### Interfaces

#### IARC20

The fungible token interface. Every ARC-20 token must implement these functions and **`view fn`** accessors:

```leo
interface IARC20 {
    record Token {
        owner: address,
        amount: u128,
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
    ) -> (Token, Final);
    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, public recipient: address, public amount: u128) -> (Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
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

Notes on signatures:

- `transfer_public_as_signer` is the signer-scoped variant of `transfer_public`, mirroring the existing primitives in `credits.aleo` / `token_registry.aleo`.
- `transfer_from_public_to_private` includes an explicit `recipient` (declared **`private`**, so the receiving address is not revealed on-chain) so the spender can route the resulting `Token` to a third party.
- `transfer_private_to_public` returns only **`(Token, Final)`** -- the change record plus a finalization future. The spender's original `Token` is consumed; the change record returned to **`input.owner`** is the spender's fresh receipt.
- `join` / `split` mirror the helpers offered by other Aleo tokens.
- **`view fn`** reads (**`balance_of`**, **`allowance`**, **`supply`**, **`max_supply`**, **`decimals`**, **`name`**, **`symbol`**) are part of the interface contract and enable off-consensus reads (SDK / explorers) through Leo 4's view function machinery.

### Record Types

**Token** -- Represents a private token balance. Implementations may add additional fields beyond `owner` and `amount`:

```leo
record Token {
    owner: address,
    amount: u128,
}
```

The interface explicitly allows extra fields with `..`, but a conforming implementation must include at least `owner: address` and `amount: u128`.

### Programs

| Program | Description |
|---------|-------------|
| [`token_registry.aleo`](./token_registry/) | Multi-token registry supporting token registration, role-based access, and authorized balances. Manages public and private balances for arbitrary token IDs. |
| [`wrapped_credits.aleo`](./wrapped_credits/) | **`IARC20`** wrapper around `credits.aleo`. Deposits Aleo credits and issues 1:1 wrapped tokens. |
| [`wrapped_token_registry.aleo`](./wrapped_token_registry/) | **`IARC20`** wrapper fixing one `token_registry.aleo` token ID (`WRAPPED_TOKEN_ID`); same interface surface as **`wrapped_credits`** aside from the deposit/withdraw helpers. |
| [`dummy_exchange.aleo`](./dummy_exchange/) | Dynamic dispatch example -- demonstrates `transfer_from_public` and `swap` to interact with any ARC20 token by program identifier at runtime. |

### Reference wrappers

[`wrapped_credits/src/main.leo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry/src/main.leo`](./wrapped_token_registry/src/main.leo) declare an **identical** **`IARC20`** interface block and implement every required transition and **`view fn`**. Implementation-level conventions shared by both:

| Topic | **`wrapped_credits.aleo`** / **`wrapped_token_registry.aleo`** |
|--------|--------------------------------------------------------------|
| Public balance storage | **`mapping balances: address => u128`** |
| Allowance storage | **`mapping allowances: TokenAllowance => u128`**, where **`TokenAllowance { account, spender }`** is used as the map key directly |
| Metadata & supply | **`storage token_info: TokenInfo`** singleton (`name`, `symbol`, `decimals`, `supply`, `max_supply`) |
| Supply bookkeeping | Shared top-level **`final fn add_supply` / `sub_supply`** invoked from deposit / withdraw paths |
| View fn metadata | **`view fn name() -> identifier`** and **`view fn symbol() -> identifier`** return Leo identifier literals (e.g. `'wCredits'`, `'wCRD'`) |

Bridging to the underlying program uses wrapper-specific helpers that are **not** part of **`IARC20`**: **`wrapped_credits`** -- **`deposit_credits_public_signer`**, **`deposit_credits_private`**, **`withdraw_credits_public`**, **`withdraw_credits_public_signer`**, **`withdraw_credits_private`**; **`wrapped_token_registry`** -- **`deposit_token_public`**, **`withdraw_token_*`**.

### Dynamic Dispatch

ARC-20 tokens are called via dynamic dispatch, which resolves the target program at runtime. This allows a single program (e.g. an AMM or lending protocol) to interact with *any* ARC20-implementing token without importing it at compile time.

Leo provides two ways to make dynamic calls:

1. **Interface-enforced syntax** ([leo#29201](https://github.com/ProvableHQ/leo/pull/29201)) -- the compiler validates function names, argument types, and return types against the interface definition at compile time. This is the recommended approach.
2. **`_dynamic_call` intrinsic** -- a low-level escape hatch that bypasses interface checking. The caller manually encodes function selectors as `field` constants and is responsible for passing correct arguments. Useful when working below the interface abstraction or with programs that don't declare interface conformance.

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

See [`dummy_exchange.aleo`](./dummy_exchange/) for a working dynamic dispatch example using the low-level `_dynamic_call` intrinsic. A full AMM reference implementation is forthcoming.

#### Example: Implementing an ARC20 Token

A program declares interface conformance with `: InterfaceName`:

```leo
interface IARC20 {
    record Token { owner: address, amount: u128, .. }
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    // ... other required functions and view fn accessors
}

program my_token.aleo: IARC20 {
    record Token {
        owner: address,
        amount: u128,
    }
    // Must implement all functions and view fn accessors from IARC20
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        // ...
    }
}
```

See [`wrapped_credits.aleo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry.aleo`](./wrapped_token_registry/src/main.leo) for complete **`IARC20`** implementations.

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**IARC20 shared interface tests** (`arc20-wrapper-tests.js`), run for both `wrapped_credits` and `wrapped_token_registry`:

- All transfer variants: `transfer_public`, `transfer_public_as_signer`, `transfer_private`, `transfer_private_to_public` (returns change **`Token`** + **`Final`**), `transfer_public_to_private`
- Public↔private round-trips via **`transfer_public_to_private` / `transfer_private_to_public`**
- Approve/unapprove + `transfer_from_public` / `transfer_from_public_to_private` allowance management (the latter includes an explicit private `recipient`)
- `join` / `split`
- **`view fn`** reads: `balance_of`, `allowance`, `supply`, `max_supply`, `decimals`, `name`, `symbol`
- Negative tests: insufficient balance, exceeded allowance

## Rationale

- **Additive approvals**: `approve_public` increases the existing allowance rather than replacing it. This avoids race conditions -- two `approve_public` calls in the same block will both succeed and add to the allowance, rather than one silently overwriting the other.
- **u128 amounts**: Future-proofs the standard for high-supply tokens and avoids truncation issues. `u64` would limit maximum supply to ~18.4 quintillion base units, which is insufficient for some token designs.
- **`recipient` naming**: The receiving address is consistently named `recipient` across transfer variants.
- **`transfer_private_to_public` returns `(Token, Final)`**: the spender's private `Token` is consumed during the transfer; the change `Token` (owned by the original spender) is the spender's fresh receipt, avoiding the need to scan `sk_tag` for the spent record.
- **`view fn` on the interface**: `balance_of`, `allowance`, `supply`, `max_supply`, `decimals`, `name`, `symbol` are part of the interface contract so off-consensus consumers (SDK, explorers, indexers) have a uniform read API without depending on implementation-specific mapping/storage layouts.

## Reference Implementations

- [`wrapped_credits/`](./wrapped_credits/) -- **`IARC20`** wrapping `credits.aleo`
- [`wrapped_token_registry/`](./wrapped_token_registry/) -- **`IARC20`** wrapping a fixed `token_registry.aleo` token ID
- [`token_registry/`](./token_registry/) -- Multi-token registry
- [`dummy_exchange/`](./dummy_exchange/) -- Dynamic dispatch interoperability example

## Dependencies

- **Leo compiler** with interface/dynamic dispatch support (Leo 4.0+)
- **@provablehq/sdk** (for SDK-based testing)

## Backwards Compatibility

This ARC supersedes the previous ARC-20 draft (2023). The prior spec was written in Aleo instructions without interface support. Programs implementing the old spec are not compatible with the new interface-based standard.

### Why Wrappers Are Needed

Existing programs cannot directly implement the **`IARC20`** interface for three reasons:

1. **Record name mismatch**: `credits.aleo` defines `record credits`, not `record Token`. The **`IARC20`** interface requires `record Token`. *(Not currently enforced at protocol level, but expected by consuming programs.)*
2. **Record entry name mismatch**: `credits.aleo` uses `microcredits` as the balance field, not `amount`. *(Enforced at protocol level; may become relaxable in future.)*
3. **Record entry type mismatch**: `credits.aleo` uses `u64` for amounts, while **`IARC20`** uses `u128`. *(Permanently enforced -- types affect circuit size and cannot be aliased.)*

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

A **stateful** wrapper maintains its own `balances` mapping and exposes the standard **`IARC20`** interface. Deposit/withdraw functions bridge between the wrapper's internal balances and the underlying program. See [`wrapped_credits.aleo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry.aleo`](./wrapped_token_registry/src/main.leo) for reference implementations.

### Public/Private Considerations

- Implementations such as **`wrapped_credits`** and **`wrapped_token_registry`** convert between public and private balances through **`transfer_public_to_private`** / **`transfer_private_to_public`** entirely within wrapper-local state. No interaction with the underlying token is required for these balance moves.
- `transfer_private_to_public` has a UX limitation: the recipient receives tokens in their public balance but cannot learn the private sender's identity (by design). The sender can still locate the spent record off-chain via their `sk_tag`; the returned change `Token` (owned by the spender) also serves as a fresh receipt.

## Migration Guide: Wrapping Token Registry Tokens

Teams that have already deployed tokens to `token_registry.aleo` can make them ARC20-compatible by deploying a stateful wrapper.

### Why Wrapping Is Needed

`token_registry.aleo` functions take an extra `token_id: field` parameter:

```
token_registry.aleo::transfer_public(token_id, recipient, amount)  // 3 params
IARC20::transfer_public(recipient, amount)                         // 2 params
```

This signature mismatch means `token_registry.aleo` cannot directly implement the **`IARC20`** interface.

### How to Create a Wrapper

1. Deploy a new program declaring conformance to **`IARC20`** (as used by [`wrapped_token_registry`](./wrapped_token_registry/))
2. Set a `WRAPPED_TOKEN_ID` constant for your token's ID in the registry
3. Maintain local `balances: address => u128` and `allowances: TokenAllowance => u128` mappings, plus a `storage token_info: TokenInfo;` singleton
4. Implement deposit/withdraw to bridge between the wrapper and the registry:
    - `deposit_token_public(amount)`: calls `token_registry.aleo::transfer_public_as_signer(TOKEN_ID, self.address, amount)`, increments local balance
    - `withdraw_token_public(amount)`: decrements local balance, calls `token_registry.aleo::transfer_public(TOKEN_ID, withdrawer, amount)`
5. Implement transfers, approvals, **`view fn`** reads, joins/splits, deposit/withdraw helpers, and **`transfer_public_to_private` / `transfer_private_to_public`** for public↔private moves.

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

See [`wrapped_token_registry/`](./wrapped_token_registry/) for a complete implementation wrapping token ID `99999field`.

## Comparison to ERC-20

For developers familiar with Ethereum's ERC-20 standard:

| ERC-20 | ARC-20 (**`IARC20`**) | Notes |
|--------|----------------------|-------|
| `balanceOf(address)` | `view fn balance_of(account) -> u128` | Off-consensus read via Leo 4 **`view fn`**; underlying `balances` mapping also queryable directly |
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

## Security Considerations

**Approval model**: ARC-20 uses additive approvals -- `approve_public` increases the allowance, and `unapprove_public` decreases it. This differs from ERC-20's replace semantics. To change an allowance from 100 to 50, call `unapprove_public(50)` rather than setting a new value. Calling `approve_public` without first reducing the existing allowance will add to it.

**Arithmetic overflow/underflow**: Leo's `u128` arithmetic aborts the transaction on underflow/overflow (enforced by the Aleo VM). Implementations therefore omit redundant explicit `assert(... >= amount)` checks in `transfer_from_public`, `transfer_from_public_to_private`, and `unapprove_public` -- the VM aborts naturally on underflow.

**Self.caller vs self.signer**: Wrapper programs must carefully distinguish between `self.caller` (the immediate caller, which may be another program) and `self.signer` (the transaction originator). Deposit functions use `self.signer` to pull from the user's underlying balance, while transfer functions use `self.caller` for composability with DeFi programs. The interface exposes both `transfer_public` (caller-scoped) and `transfer_public_as_signer` (signer-scoped) so consumers can pick the appropriate semantics.

## Testing

Prerequisites:

- Leo compiler with interface support (Leo 4.0+)
- Node.js 18+

```bash
cd arc-0020/tests
npm install
npm test                    # Run all tests (requires local devnode)
```

Tests start a local devnode, deploy programs with their dependencies, and execute transactions via `leo execute`.

## Copyright

This ARC is placed in the public domain.
