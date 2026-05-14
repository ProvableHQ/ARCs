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

ARC-20 defines a fungible token standard for Aleo, supporting both public and private balances. Programs declare conformance to the `ARC20` interface, and any other program can call them at runtime via dynamic dispatch -- without compile-time knowledge of the specific token implementation.

The standard defines a single **ARC20** interface covering public transfers, private transfers, shielding/unshielding, approvals, joins/splits, and mint/burn. Implementations commonly expose name, symbol, decimals, allowances, and supply via **`view fn`** on the core surface rather than a separate Leo trait. Reference deployments **[`wrapped_credits.aleo`](./wrapped_credits/)** and **[`wrapped_token_registry.aleo`](./wrapped_token_registry/)** both use program-local names **`IARC20`** / **`IARC20Mintable`** and match each other closely—see [**Implementation snapshots (reference wrappers)**](#implementation-snapshots-reference-wrappers).

For regulated tokens requiring freeze lists and compliance records, see [ARC-22](../arc-0022/).

## Motivation

Without a standard interface, every DeFi program must import each token at compile time, making it impossible to build token-agnostic protocols. ARC-20 solves this through Leo's dynamic dispatch: a single AMM, lending protocol, or exchange can interact with any conforming token by name at runtime, with no recompilation or redeployment required.

ARC-20 supersedes the previous ARC-20 draft (2023), which was written in Aleo instructions without interface support.

## Specification

### Interfaces

#### ARC20

The fungible token interface. Every ARC-20 token must implement these functions:

```leo
interface ARC20 {
    record Token {
        owner: address,
        amount: u128,
        ..
    }
    // Private receipt for the spender of `transfer_private_to_public`.
    record Metadata;

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, recipient: address, amount: u128) -> (Token, Metadata, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public recipient: address, public amount: u128) -> (Token, Final);

    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Final);

    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);

    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public owner: address, public amount: u128) -> Final;
    fn burn_private(input: Token, public amount: u128) -> (Token, Final);
}
```

Notes on signatures:

- `transfer_public_as_signer` is the signer-scoped variant of `transfer_public`, mirroring the existing primitives in `credits.aleo` / `token_registry.aleo`.
- `transfer_from_public_to_private` includes an explicit `recipient` so the spender can mint the resulting `Token` to a third party.
- `burn_public` accepts an explicit `owner`, leaving the choice of `self.caller` vs. `self.signer` to the caller rather than baking it into the implementation.
- `join` / `split` mirror the helpers offered by other Aleo tokens.
- `mint_private` / `burn_private` keep `amount` and `recipient` as `public` inputs so that conforming wrappers can forward the value into the underlying public ledger (e.g. `credits.aleo::transfer_public_as_signer`). Privacy of the resulting `Token` is preserved by the proof.
- Optional **`view fn`** reads (**`balance_of`**, **`allowance`**, **`decimals`**, **`name`**, **`symbol`**, plus implementation-defined **`total_supply`** / **`max_supply`**) are declared on **`IARC20`** in the [`wrapped_credits`](./wrapped_credits/) and [`wrapped_token_registry`](./wrapped_token_registry/) references instead of a separate metadata-extending interface type.

### Record Types

**Token** -- Represents a private token balance. Implementations may add additional fields beyond `owner` and `amount`:

```leo
record Token {
    owner: address,
    amount: u128,
}
```

The interface explicitly allows extra fields with `..`, but a conforming implementation must include at least `owner: address` and `amount: u128`.

**Metadata** -- Emitted by `transfer_private_to_public` as a private receipt for the spender. Conforming implementations only need to declare it (`record Metadata;`); the interface intentionally does not constrain any fields beyond the implicit `owner: address`. Reference wrappers set the `Metadata.owner` to the spender (`input.owner`) so the spender retains a fresh, owner-scoped record after their original `Token` is consumed:

```leo
record Metadata {
    owner: address,
}
```

### Programs

| Program | Description |
|---------|-------------|
| [`token_registry.aleo`](./token_registry/) | Multi-token registry supporting token registration, role-based access, and authorized balances. Manages public and private balances for arbitrary token IDs. |
| [`wrapped_credits.aleo`](./wrapped_credits/) | **`IARC20` + `IARC20Mintable`** wrapper around `credits.aleo`. Deposits Aleo credits and issues 1:1 wrapped tokens; see [reference snapshots](#implementation-snapshots-reference-wrappers). |
| [`wrapped_token_registry.aleo`](./wrapped_token_registry/) | **`IARC20` + `IARC20Mintable`** wrapper fixing one `token_registry.aleo` token ID (`WRAPPED_TOKEN_ID`); same surface as **`wrapped_credits`** aside from deposit/withdraw (see [snapshots](#implementation-snapshots-reference-wrappers)). |
| [`dummy_exchange.aleo`](./dummy_exchange/) | Dynamic dispatch example -- demonstrates `transfer_from_public` and `swap` to interact with any ARC20 token by program identifier at runtime. |

### Implementation snapshots (reference wrappers)

[`wrapped_credits/src/main.leo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry/src/main.leo`](./wrapped_token_registry/src/main.leo) both declare **`IARC20`** (core transfers, approvals, **`view fn`** accessors) and **`IARC20Mintable: IARC20`** (**`mint_*` / `burn_*`** only). Mint/burn are split from the core surface the same way a normative **`MintableToken: ARC20`** extension would; only the identifier names differ from the **`ARC20`** spelling in the specification fragment above.

Compared to the normative **`ARC20`** block in this document, both reference wrappers behave as follows:

| Topic | Normative **`ARC20`** in this ARC | **`wrapped_credits.aleo`** / **`wrapped_token_registry.aleo`** |
|--------|-----------------------------------|-------------------------------------|
| Private→public receipt | **`transfer_private_to_public` → `(Token, Metadata, Final)`** | **`(Token, Final)`** — no **`Metadata`** record type |
| Shield / unshield | Dedicated **`shield` / `unshield`** | Not exposed; use **`transfer_public_to_private`** and **`transfer_private_to_public`** |
| **`transfer_from_public_to_private`** | Example uses **`public recipient`** | **`private recipient`** |
| Read APIs | Historically mapping/API reads | **`view fn`** on **`IARC20`**: **`balance_of`**, **`allowance`**, **`decimals`**, **`name`**, **`symbol`**; both programs also define **`total_supply`** and **`max_supply`** views reading **`storage token_info`** |
| Supply counter | Implementation-defined | Shared **`final fn add_supply` / `sub_supply`** |

Bridging uses wrapper-specific helpers: **`wrapped_credits`** — **`deposit_credits_*`**, **`withdraw_credits_*`**; **`wrapped_token_registry`** — **`deposit_token_public`**, **`withdraw_token_*`** (registry-backed **`mint_*` / `burn_*`** remain deposit/withdraw semantics).

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
ARC20@(token_id)::transfer_public(recipient, amount);

// Call by program name literal
ARC20@('my_token')::transfer_public(recipient, amount);

// Specify both program name and network
ARC20@('my_token', 'aleo')::transfer_public(recipient, amount);
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
        let transfer_in: Final = ARC20@(token_in)::transfer_from_public(
            self.signer, self.address, amount_in
        );
        // Send tokens to the user
        let transfer_out: Final = ARC20@(token_out)::transfer_public(
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
    public recipient: address,
    public amount: u128,
) -> (dyn record, Final) {
    let (change, transfer_future): (dyn record, Final) =
        ARC20@(token_id)::transfer_private_to_public(
            token_record, recipient, amount
        );
    return (change, final { transfer_future.run(); });
}
```

See [`dummy_exchange.aleo`](./dummy_exchange/) for a working dynamic dispatch example using the low-level `_dynamic_call` intrinsic. A full AMM reference implementation is forthcoming.

#### Example: Implementing an ARC20 Token

A program declares interface conformance with `: InterfaceName`:

```leo
interface ARC20 {
    record Token { owner: address, amount: u128, .. }
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    // ... other required functions
}

program my_token.aleo: ARC20 {
    record Token {
        owner: address,
        amount: u128,
    }
    // Must implement all functions from ARC20
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        // ...
    }
}
```

See [`wrapped_credits.aleo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry.aleo`](./wrapped_token_registry/src/main.leo) for complete **`IARC20Mintable`** implementations.

## Test Cases

Tests use Jest with a local devnode and Leo CLI execution.

**ARC20 shared interface tests** (`arc20-wrapper-tests.js`), run for both `wrapped_credits` and `wrapped_token_registry`:

- All transfer variants: `transfer_public`, `transfer_public_as_signer`, `transfer_private`, `transfer_private_to_public` (returns change **`Token`** + **`Final`** only), `transfer_public_to_private`
- Public↔private round-trips via **`transfer_public_to_private` / `transfer_private_to_public`** (the JS harness may still call these paths **`shield` / `unshield`** for shared helpers)
- Approve/unapprove + `transfer_from_public` / `transfer_from_public_to_private` allowance management (the latter includes an explicit `recipient`)
- `join` / `split`
- `mint_public` / `mint_private` / `burn_public` / `burn_private` (the latter two include an explicit `owner` / change-record output)
- Negative tests: insufficient balance, exceeded allowance

## Rationale

- **Single interface**: `mint`/`burn` are part of `ARC20` rather than a separate `MintableToken` interface. Tokens that have no minting authority can simply revert in `mint_*` and `burn_*`, but downstream consumers always know the methods exist.
- **Additive approvals**: `approve_public` increases the existing allowance rather than replacing it. This avoids race conditions -- two `approve_public` calls in the same block will both succeed and add to the allowance, rather than one silently overwriting the other.
- **u128 amounts**: Future-proofs the standard for high-supply tokens and avoids truncation issues. `u64` would limit maximum supply to ~18.4 quintillion base units, which is insufficient for some token designs.
- **`recipient` naming**: The receiving address is consistently named `recipient` across every transfer, mint, shield, and unshield variant.
- **`shield` / `unshield` naming**: `shield` converts the signer's public balance to a private `Token` record. `unshield` converts a private `Token` back to the owner's public balance and returns the change `Token` together with a `Final`.
- **`transfer_private_to_public` returns a `Metadata` receipt**: the spender's private `Token` is consumed during the transfer, and the recipient receives the funds publicly. `Metadata` is a small, owner-scoped record returned to the spender so they have a fresh receipt without having to scan their `sk_tag` for the spent record.
- **`burn_public(owner, amount)`**: Implementations choose whether to enforce `owner == self.caller`, `owner == self.signer`, or some role-gated invariant. Pinning either of these into the interface would limit composability for stateful wrappers and compliant tokens.

## Reference Implementations

- [`wrapped_credits/`](./wrapped_credits/) -- **`IARC20` + `IARC20Mintable`** wrapping `credits.aleo` (see [snapshots](#implementation-snapshots-reference-wrappers))
- [`wrapped_token_registry/`](./wrapped_token_registry/) -- **`IARC20` + `IARC20Mintable`** wrapping a fixed `token_registry.aleo` token ID
- [`token_registry/`](./token_registry/) -- Multi-token registry
- [`dummy_exchange/`](./dummy_exchange/) -- Dynamic dispatch interoperability example

## Dependencies

- **Leo compiler** with interface/dynamic dispatch support (Leo 4.0+)
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

A **stateful** wrapper maintains its own `balances` mapping and exposes the standard ARC20 interface. Deposit/withdraw functions bridge between the wrapper's internal balances and the underlying program. See [`wrapped_credits.aleo`](./wrapped_credits/src/main.leo) and [`wrapped_token_registry.aleo`](./wrapped_token_registry/src/main.leo) for reference implementations.

### Shielding Considerations

- Dedicated **`shield` / `unshield`** transitions (when present) are self-only operations: the signer converts between their own public and private balances of the wrapped token. Implementations such as **`wrapped_credits`** and **`wrapped_token_registry`** expose the same effect through **`transfer_public_to_private`** / **`transfer_private_to_public`** (see [snapshots](#implementation-snapshots-reference-wrappers)). No interaction with the underlying token is required for shield/unshield-style flows on the wrapper’s own ledger.
- `transfer_private_to_public` has a UX limitation: the recipient receives tokens in their public balance but cannot learn the private sender's identity (by design). The sender can still locate the spent record off-chain via their `sk_tag`.

## Migration Guide: Wrapping Token Registry Tokens

Teams that have already deployed tokens to `token_registry.aleo` can make them ARC20-compatible by deploying a stateful wrapper.

### Why Wrapping Is Needed

`token_registry.aleo` functions take an extra `token_id: field` parameter:

```
token_registry.aleo::transfer_public(token_id, recipient, amount)  // 3 params
ARC20::transfer_public(recipient, amount)                          // 2 params
```

This signature mismatch means `token_registry.aleo` cannot directly implement the ARC20 interface.

### How to Create a Wrapper

1. Deploy a new program implementing **`ARC20`** or the reference **`IARC20`** / **`IARC20Mintable`** split used by [`wrapped_token_registry`](./wrapped_token_registry/)
2. Set a `WRAPPED_TOKEN_ID` constant for your token's ID in the registry
3. Maintain local `balances: address => u128` and `allowances: TokenAllowance => u128` mappings, plus a `storage token_info: TokenInfo;` singleton
4. Implement deposit/withdraw to bridge between the wrapper and the registry:
    - `deposit_token_public(amount)`: calls `token_registry.aleo::transfer_public_as_signer(TOKEN_ID, self.address, amount)`, increments local balance
    - `withdraw_token_public(amount)`: decrements local balance, calls `token_registry.aleo::transfer_public(TOKEN_ID, withdrawer, amount)`
5. Implement transfers, approvals, **`view fn`** reads, joins/splits, and mint/burn (`mint_*` / `burn_*` may act as deposit/withdraw on wrappers). Dedicated **`shield` / `unshield`** transitions are optional if **`transfer_public_to_private` / `transfer_private_to_public`** cover public↔private moves.

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

See [`wrapped_token_registry/`](./wrapped_token_registry/) for a complete implementation wrapping token ID `99999field`. In this wrapper, `mint_public`/`mint_private` act as deposits (pull from the signer's registry balance) and `burn_public`/`burn_private` act as withdraws (send back to the registry).

## Comparison to ERC-20

For developers familiar with Ethereum's ERC-20 standard:

| ERC-20 | ARC-20 | Notes |
|--------|--------|-------|
| `balanceOf` / `balance_of(address)` | Query `balances` mapping via API **or** `view fn balance_of` where implemented | Leo 4 **`view fn`** supports off-consensus reads (SDK / explorers); mappings remain queryable directly |
| `totalSupply()` | Query `token_info` / **`view fn total_supply`** where implemented | Same data via storage or **`view fn`** |
| `name()` / `symbol()` / `decimals()` | **`view fn`** on **`IARC20`** (reference wrappers) **or** mapping/API reads | Same constants via **`view fn`** as in [`wrapped_credits`](./wrapped_credits/) / [`wrapped_token_registry`](./wrapped_token_registry/) |
| `transfer(to, amount)` | `transfer_public(recipient, amount)` | Direct equivalent |
| `approve(spender, amount)` | `approve_public(spender, amount)` | Additive (not replace) -- use `unapprove_public` to decrease |
| `transferFrom(from, to, amount)` | `transfer_from_public(owner, recipient, amount)` | Direct equivalent |
| -- | `transfer_private(input, recipient, amount)` | No ERC-20 equivalent -- private transfers are unique to Aleo |
| -- | `shield(amount)` / `unshield(input, amount)` | Convert between public and private balances |
| -- | `join(a, b)` / `split(a, n)` | Manage record granularity |
| Contract address = token | Program name = token | Each ARC20 token is its own deployed program |

## Security Considerations

**Approval model**: ARC-20 uses additive approvals -- `approve_public` increases the allowance, and `unapprove_public` decreases it. This differs from ERC-20's replace semantics. To change an allowance from 100 to 50, call `unapprove_public(50)` rather than setting a new value. Calling `approve_public` without first reducing the existing allowance will add to it.

**Arithmetic overflow/underflow**: Leo's `u128` arithmetic aborts the transaction on underflow/overflow (enforced by the Aleo VM). Implementations therefore omit redundant explicit `assert(... >= amount)` checks in `unshield`, `transfer_from_public`, `transfer_from_public_to_private`, and `unapprove_public` -- the VM aborts naturally on underflow.

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
