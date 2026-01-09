---
arc: 9
title: Dynamic Dispatch
authors: "@ProvableHQ"
discussion: https://github.com/ProvableHQ/ARCs/discussions/110
topic: Protocol
status: Draft
created: December 11, 2025
---

# Abstract

Static function calls in the Aleo Virtual Machine (AVM) require programs to know at compile time which functions they will invoke. While this provides strong guarantees, it limits the expressiveness of Aleo programs and prevents common smart contract patterns found in other ecosystems.

**This proposal introduces dynamic dispatch to the AVM, enabling programs to invoke functions determined at runtime.** Dynamic dispatch unlocks powerful programming paradigms including interfaces, plugin architectures and upgradeable libraries—while maintaining the security and privacy guarantees that define Aleo.

# Goals

We propose a system for dynamic dispatch with the following properties:

1. **Dispatch should be secure.** Dynamic dispatch has enabled rich application ecosystems in other VMs, but has also introduced vulnerabilities like code hijacking and reentrancy bugs. Security is the first priority.

2. **Dispatch should be flexible.** The core purpose of dynamic dispatch is to allow calling multiple programs under a single interface. The more flexible the dispatch, the more utility it provides.

3. **Dispatch should be backwards compatible.** This feature should not change the circuits or behavior of existing programs. Functions with dynamic calls should be able to invoke functions with static calls and vice versa. Existing records must be usable in dynamic dispatch.

4. **Dispatch should preserve privacy.** Dynamic calls should not leak unnecessary information about the nature of the call beyond what is inherently revealed by the resulting transitions.

# Specification

## Data Types

Dynamic dispatch introduces two new data types to handle AVM-native constructs that require special treatment when passed across dynamic call boundaries.

### `dynamic.record`

A `dynamic.record` is a fixed-size, general representation of a record. Unlike static records, a dynamic record:

- Has a constant size regardless of its data contents
- Is **NOT** checked for existence or uniqueness at the call site
- Can be instantiated as a concrete record when passed to the appropriate function

**Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `owner` | `address` | The owner of the record |
| `_root` | `field` | Merkle root of the record's data entries, including the entry name and visibility |
| `_nonce` | `group` | The record nonce |
| `_version` | `u8` | Record version (for commitment scheme selection) |

**String representation:**
```
{ owner: aleo1..., _root: 123field, _nonce: 456group, _version: 1u8 }
```

**Usage contexts:**

A `dynamic.record` can appear in:
- Function inputs: `input r0 as dynamic.record;`
- Function outputs: `output r0 as dynamic.record;`
- As input to `call` or `call.dynamic`
- As output from `call` or `call.dynamic`

**Important:** A `dynamic.record` cannot be instantiated directly within a program. It can only be:
- Received as input to a function
- Returned from a `call.dynamic`
- Created via the `cast` instruction from a static record

**Record consumption:** A record is only consumed (nullified) when it is input to a function that expects its static definition. Functions that accept `dynamic.record` or external records do NOT consume the record or verify ownership.

**Record creation:** A record is only created (its commitment and
ciphertext being published onto the ledger) when it is output by a function that
declares its (static) type as an output. Functions that output dynamic.record or
external records do NOT create an on-chain record that can be subsequently
consumed later on.

### `dynamic.future`

A `dynamic.future` is a fixed-size representation of a future returned from a dynamic call. It is produced exclusively as a result of `call.dynamic` when the callee returns a future.

**Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `program_name` | `field` | Program name as field element |
| `program_network` | `field` | Program network as field element |
| `function_name` | `field` | Function name as a field element |
| `root` | `field` | The Merkle root of the arguments |

**String representation:**
```
{ program_name: 0field, program_network: 1field, function_name: 2field, root: 123456789field }
```

**Awaiting a dynamic.future:**

Like static futures, a `dynamic.future` must be consumed by an `async` instruction and awaited in the corresponding finalize block:

```aleo
finalize my_function:
    input r0 as dynamic.future;
    await r0;
```

When `await` is invoked on a dynamic future, the runtime looks up the corresponding future in the global context, retrieves the static future, and executes it. The runtime guarantees that all futures (static and dynamic) are awaited exactly once.

**Note:** A `dynamic.future` cannot be directly output by a function; it must be wrapped in a static future via the `async` instruction.

## Instructions

### `call.dynamic`

The `call.dynamic` instruction invokes a function determined at runtime.

**Syntax:**
```
call.dynamic <PROG> <NET> <FUN> with <INPUTS> (as <INPUT_TYPES>) into <OUTPUTS> (as <OUTPUT_TYPES>);
```

| Operand | Type | Description |
|---------|------|-------------|
| `<PROG>` | `field` | Program name as a field element |
| `<NET>` | `field` | Network name as a field element |
| `<FUN>` | `field` | Function name as a field element |
| `<INPUTS>` | registers | Input operands to pass to the function |
| `<INPUT_TYPES>` | type list | Types and visibility of inputs |
| `<OUTPUTS>` | registers | Destination registers for outputs |
| `<OUTPUT_TYPES>` | type list | Types and visibility of outputs |

**Example:**
```aleo
// Dynamically call credits.aleo/transfer_public
call.dynamic 'credits' 'aleo' 'transfer_public' with r0 r1 (as address.public u64.public) into r2 (as dynamic.future);
```

**Type restrictions:**

| Context | Allowed Types | Disallowed Types |
|---------|---------------|------------------|
| Inputs | Plaintext types, `dynamic.record` | `record`, `external.record`, `future`, `dynamic.future` |
| Outputs | Plaintext types, `dynamic.record`, `dynamic.future` | `record`, `external.record`, `future` |

**Behavior:**
- The `call.dynamic` instruction can only be used in function bodies, not in finalize blocks
- The program, network, and function identifiers are witnessed as public inputs. **Consequently, private variables that influence the target of a dynamic call is implicitly leaked. Developers should take care to ensure that sensitive material is not used to determine the target.**
- The existence of the target program and function is verified at execution time
- A transition/request associated with a dynamic call is a "dynamic" transition/request. They are differentiated with additional (unsigned) metadata.

**Note:** Dynamic targets cannot be resolved from mappings at runtime. Callers must provide target identifiers as inputs (queried off-chain), and on-chain logic can verify these match stored values.

### `get.dynamic.record`

Retrieves a specific entry from a dynamic record by name.

**Syntax:**
```
get.dynamic.record r<i>.<name> into r<j> as <TYPE>;
```

| Operand | Description |
|---------|-------------|
| `r<i>` | Register containing the `dynamic.record` |
| `<name>` | Identifier of the entry to retrieve |
| `r<j>` | Destination register |
| `<TYPE>` | Expected plaintext type of the entry |

**Example:**
```aleo
get.dynamic.record r0.microcredits into r1 as u64;
get.dynamic.record r0.metadata into r2 as [u8; 32u32];
```

**Circuit behavior:** The instruction verifies a Merkle proof that the requested entry exists in the record's data tree with the specified identifier and type.

**Note: The owner of a dynamic record can be accessed directly, e.g `r0.owner`. This does not involve Merkle-path verification`.

### `cast ... as dynamic.record`

Converts a static record to a dynamic record.

**Syntax:**
```
cast r<i> into r<j> as dynamic.record;
```

The input register must contain a `record` or `external.record`. The output is a `dynamic.record` with:
- The same `owner`, `nonce`, and `version` as the static record
- A `data_root` computed as the Merkle root of the record's entries

**Important limitation:** A dynamic record created via `cast` cannot be passed to a function expecting a static record, as this would constitute either a double-spend (if the original was an input) or an attempt to spend an uncommitted record (if the original was created locally). Furthermore, casting a static record into a dynamic one, does not consume it.

### Dynamic Mapping Operations

Three finalize-scope commands enable dynamic access to mappings:

**`get.dynamic`**
```
get.dynamic <PROG> <NET> <MAP>[<KEY>] into <DEST> as <TYPE>;
```

**`get.or_use.dynamic`**
```
get.or_use.dynamic <PROG> <NET> <MAP>[<KEY>] <DEFAULT> into <DEST> as <TYPE>;
```

**`contains.dynamic`**
```
contains.dynamic <PROG> <NET> <MAP>[<KEY>] into <DEST>;
```

These commands behave identically to their static counterparts, except the program and mapping are resolved from field element operands at runtime.

## Identifier Literals

To improve ergonomics, this proposal introduces a syntax for specifying identifiers as field element literals using single quotes:

```
'credits'           // Program name
'aleo'              // Network name
'transfer_public'   // Function name
```
The identifier (excluding quotes) must fit within `Field::SIZE_IN_DATA_BITS`.  

To support this, we will be introducing a new literal type called `identifier`. An `identifier` can always be cast into a field element. This allows users to pass in human readable targets to `call.dynamic`.

## Translation Circuits

When records cross dynamic call boundaries, a translation circuit proves consistency between the dynamic and static representations. The AVM introduces a new circuit type parameterized by each record definition in a program.

**Translation is required when:**
- A caller passes a `dynamic.record` to a callee expecting a static `record` or `external.record`
- A callee returns a static `record` or `external.record` to a caller expecting a `dynamic.record`

**The translation circuit verifies:**
1. Owner, nonce, and version match between representations
2. The Merkle root of the static record's data equals the dynamic record's `data_root`
3. The record IDs (commitments or serial numbers) are correctly computed

**Deployment:** Programs must include translation verifying keys for each record type they define. Programs deployed before this feature can be redeployed to add translation keys.

## Differing view of inputs/outputs in the caller and callee
It follows from the previous sections that:
- In a call instruction, the input and output types must coincide exactly in the
caller and callee. A `dynamic.record` can be passed to or received from a call
instruction if and only if the callee declares it as such ( `input r<i> as dynamic.record` , `output r<j> as dynamic.record` ).
- In a call.dynamic instruction, the input and output types of the caller and
callee must coincide except in three concrete situations:
  - A `dynamic.record` can be passed (via `call.dynamic` ) to a function that expects
a static record or an external record
  - A `dynamic.record` can be received (via `call.dynamic` ) from a function that
outputs a static record or an external record
  - A `dynamic.future` can be received (via `call.dynamic` ) from a function that
outputs a static future. 

A root transition can never be dynamic or behave as such. In particular, no
translation of inputs or outputs will happen and the arguments passed to the
AVM for execution must match exactly the types in the root transition’s
function. However, a root transition can receive a dynamic record as an input
(and produce one as an output) as long as the corresponding function expects
a `dynamic.record`. 

# Usage

Dynamic dispatch enables programming patterns previously impossible or impractical on Aleo. This section illustrates key use cases.

## Interfaces and Polymorphism

Dynamic dispatch enables interface-like patterns where multiple programs implement a common function signature.

**Token Interface Pattern:**

Any program implementing `transfer`, `approve`, and `balance_of` with compatible signatures can be used interchangeably:

```aleo
program token_router.aleo;

// Route a transfer to any compatible token program
function transfer:
    input r0 as field.public;          // token program name
    input r1 as address.public;        // recipient
    input r2 as u64.public;            // amount
    call.dynamic r0 'aleo' 'transfer' with r1 r2 (as address.public u64.public) into r3 (as dynamic.future);
    async transfer r3 into r4;
    output r4 as token_router.aleo/transfer.future;

finalize transfer:
    input r0 as dynamic.future;
    await r0;
```

This pattern mirrors ERC-20 compatibility in Ethereum, allowing DEXs, lending protocols, and other DeFi applications to work with any compliant token.

**Record Interface Pattern:**

The `get.dynamic.record` instruction can enforce that a `dynamic.record` contains specific fields, regardless of which program defined it. When `get.dynamic.record` is executed, it verifies a Merkle proof that the requested entry exists in the record's data tree with the specified identifier and type. If the field doesn't exist or has an incompatible type, the proof fails.

This enables programs to define implicit interfaces for records:

```aleo
program collateral_manager.aleo;

// Accept any record that has 'owner' and 'value' fields
// The record can come from any token program
function deposit_collateral:
    input r0 as dynamic.record;        // any record with required fields

    // Extract required fields - this enforces the interface
    // If the record lacks these fields, the Merkle proof fails
    get.dynamic.record r0.owner into r1 as address;
    get.dynamic.record r0.value into r2 as u64;

    // Use the extracted values
    assert.eq r1 self.caller;          // caller must own the record
    gte r2 1000u64 into r3;            // minimum collateral check
    assert.eq r3 true;

    // ... rest of collateral logic using r1 (owner) and r2 (value) ...
```

Any record definition that includes `owner as address` and `value as u64` fields satisfies this interface:

```aleo
// These records from different programs all satisfy the interface:

// token_a.aleo
record credit:
    owner as address.private;
    value as u64.private;

// token_b.aleo
record coin:
    owner as address.private;
    value as u64.private;
    memo as field.private;            // extra fields are allowed

// nft.aleo
record asset:
    owner as address.private;
    value as u64.private;             // could represent appraised value
    token_id as u128.private;
```

This pattern is analogous to structural typing or duck typing. Combined with `call.dynamic`, this enables generic protocols that work with any compliant record type without needing to know the specific program at compile time. Note that the presence of a dynamic record does not imply the existence of a corresponding minted, unspent record. A dynamic record needs to be translated and passed into a function that expects a (non-external) static record for the existence check to happen.

## Strategy Pattern (Library Dispatch)

Dynamic dispatch enables the strategy pattern, where a program delegates computation to interchangeable library programs that implement a common interface. Since `call.dynamic` executes in the callee's context (there is no shared state), this pattern works best for pure computational functions.

**Example: Pluggable Pricing Algorithms**

A DEX can support multiple pricing algorithms (constant product, stableswap, concentrated liquidity) by dispatching to different library programs:

```aleo
// Library interface: compute_output(reserve_in, reserve_out, amount_in) -> amount_out
// Each pricing library implements this interface as a pure function

program dex.aleo;

function swap:
    input r0 as field.public;          // pricing_library program name
    input r1 as u64.public;            // reserve_in
    input r2 as u64.public;            // reserve_out
    input r3 as u64.public;            // amount_in

    // Dispatch to the pricing library to compute output amount
    // More complex logic could be introduced to determine the library used. For example, checking an auth token.
    call.dynamic r0 'aleo' 'compute_output' with r1 r2 r3 (as u64.public u64.public u64.public) into r4 (as u64.public);

    // Use computed amount_out for the swap
    // ... transfer logic using r4 ...

    output r4 as u64.public;
```

**Constant Product Library:**
```aleo
program constant_product_lib.aleo;

// x * y = k pricing: amount_out = (reserve_out * amount_in) / (reserve_in + amount_in)
function compute_output:
    input r0 as u64.public;            // reserve_in
    input r1 as u64.public;            // reserve_out
    input r2 as u64.public;            // amount_in

    mul r1 r2 into r3;                 // reserve_out * amount_in
    add r0 r2 into r4;                 // reserve_in + amount_in
    div r3 r4 into r5;                 // amount_out

    output r5 as u64.public;
```

**Stableswap Library:**
```aleo
program stableswap_lib.aleo;

// Curve-style stableswap pricing for pegged assets
function compute_output:
    input r0 as u64.public;            // reserve_in
    input r1 as u64.public;            // reserve_out
    input r2 as u64.public;            // amount_in

    // ... stableswap invariant calculation ...

    output r5 as u64.public;
```

This pattern enables:
- Swappable algorithms without redeploying the main program
- Third parties can deploy new pricing libraries
- Main program can allowlist approved libraries via finalize verification

## Conditional Execution

The Strategy Pattern above is actually a special case of conditional execution.
Dynamic dispatch enables runtime branching between different execution paths:

```aleo
program router.aleo;

function conditional_call:
    input r0 as boolean.private;       // condition
    input r1 as field.public;          // program if true
    input r2 as field.public;          // program if false
    input r3 as field.public;          // function name
    input r4 as u64.public;            // argument

    ternary r0 r1 r2 into r5;          // select program based on condition
    call.dynamic r5 'aleo' r3 with r4 (as u64.public) into r6 (as dynamic.future);
    async conditional_call r6 into r7;
    output r7 as router.aleo/conditional_call.future;

finalize conditional_call:
    input r0 as dynamic.future;
    await r0;
```

**Privacy note:** The resulting transaction will reveal which program was actually called. The condition itself may be inferred from the transaction structure.

## Recursive Calls

**TODO.** The restrictions on recursive calls are currently being discussed.

With conditional execution, it follows that dynamic dispatch enables recursive program structures:

```aleo
program recursive.aleo;

function fibonacci:
    input r0 as u64.private;

    // Base case check
    is.eq r0 0u64 into r1;
    is.eq r0 1u64 into r2;
    or r1 r2 into r3;

    // Recursive case setup
    sub.w r0 1u64 into r4;
    sub.w r0 2u64 into r5;

    // Select function based on base case
    ternary r3 'base' 'fibonacci' into r6;

    // Recursive calls
    call.dynamic 'recursive' 'aleo' r6 with r4 (as u64.private) into r7 (as u64.private);
    call.dynamic 'recursive' 'aleo' r6 with r5 (as u64.private) into r8 (as u64.private);

    // Combine results
    add r7 r8 into r9;
    ternary r3 r7 r9 into r10;
    output r10 as u64.private;

function base:
    input r0 as u64.private;
    output r0 as u64.private;
```

## Universal Token Operations

A unified interface for interacting with any token:

```aleo
program universal_swap.aleo;

struct SwapRequest:
    token_in as field;                 // input token program
    token_out as field;                // output token program
    amount_in as u64;
    min_amount_out as u64;
    recipient as address;

function swap:
    input r0 as SwapRequest.public;
    input r1 as dynamic.record;        // input token record

    // Transfer input tokens to this contract
    call.dynamic r0.token_in 'aleo' 'transfer'
        with r1 self.address r0.amount_in
        (as dynamic.record address.public u64.public)
        into r2 r3 (as dynamic.record dynamic.future);

    // ... pricing logic and output transfer ...

    async swap r3 into r4;
    output r2 as dynamic.record;
    output r4 as universal_swap.aleo/swap.future;

finalize swap:
    input r0 as dynamic.future;
    await r0;
```

## Extension Hooks

Programs can support extensibility through hooks that modify behavior at defined extension points. Since `call.dynamic` executes in the callee's context with no shared state, hooks work best as pure functions that return values the caller uses:

```aleo
program lending.aleo;

function borrow:
    input r0 as field.public;          // fee_calculator program (hook)
    input r1 as u64.public;            // collateral_amount
    input r2 as u64.public;            // borrow_amount
    input r3 as address.public;        // borrower

    // Call the fee calculator hook - returns the fee to charge
    // Different hooks can implement different fee strategies
    call.dynamic r0 'aleo' 'calculate_fee' with r1 r2 (as u64.public u64.public) into r4 (as u64.public);

    // Use the hook's result in the main logic
    add r2 r4 into r5;                 // total_debt = borrow_amount + fee

    // ... rest of borrow logic using r5 ...

    async borrow r0 r5 into r6;
    output r6 as lending.aleo/borrow.future;

finalize borrow:
    input r0 as field.public;
    input r1 as u64.public;

    // Optionally verify the hook is on an allowlist
    // ... allowlist check ...
```

**Standard Fee Hook:**
```aleo
program standard_fee.aleo;

// 1% fee
function calculate_fee:
    input r0 as u64.public;            // collateral_amount (unused)
    input r1 as u64.public;            // borrow_amount

    div r1 100u64 into r2;             // 1% fee
    output r2 as u64.public;
```

**Risk-Based Fee Hook:**
```aleo
program risk_fee.aleo;

// Fee based on collateral ratio
function calculate_fee:
    input r0 as u64.public;            // collateral_amount
    input r1 as u64.public;            // borrow_amount

    // Higher fee for lower collateral ratios
    mul r1 100u64 into r2;
    div r2 r0 into r3;                 // utilization = borrow/collateral * 100
    mul r1 r3 into r4;
    div r4 1000u64 into r5;            // fee scales with utilization

    output r5 as u64.public;
```

This pattern enables:
- Pluggable fee structures, access control, or validation logic
- Third parties can deploy custom hooks
- Main protocol can allowlist approved hooks or let users choose

# Test Cases

Implementations must correctly handle:

1. **Basic dynamic calls:** Calling a function with plaintext inputs and outputs
2. **Dynamic record passing:** Passing `dynamic.record` to functions expecting static records
3. **Dynamic future handling:** Properly awaiting `dynamic.future` in finalize blocks
4. **Nested dynamic calls:** Dynamic calls within dynamic calls
5. **Mixed static/dynamic:** Static calls to functions that make dynamic calls and vice versa
6. **Translation correctness:** Proper conversion between static and dynamic record representations
7. **Dynamic mapping access:** Reading from mappings in dynamically-determined programs
8. **Error cases:** Invalid program names, non-existent functions, type mismatches

# Reference Implementation

The reference implementation can be found in the snarkVM repository:
- Tracking branch: `feat/dynamic-dispatch`
- Repository: https://github.com/ProvableHQ/snarkVM

# Dependencies

This proposal affects:

| Repository | Impact |
|------------|--------|
| snarkVM | Core implementation of dynamic dispatch, translation circuits, new data types |
| snarkOS | Transaction validation, future resolution during finalization |
| Leo | Language support for dynamic types and instructions |
| Aleo SDK | Client-side support for constructing dynamic calls |

# Backwards Compatibility

**Existing programs are unaffected.** Dynamic dispatch does not change the circuits or behavior of programs that do not use it.

**Interoperability:**
- Functions with dynamic calls can invoke functions with static calls
- Functions with static calls can be invoked by functions with dynamic calls
- Existing records can be used with dynamic dispatch after one-time deployment of translation keys

**Migration for existing programs:** We plan to support a migration pathway for all existing programs to redeploy with translation verifying keys, without changing the state of the program on-chain.

**Consensus versioning:** Features are guarded by consensus version to ensure backwards compatibility for node operators.

# Security & Compliance

## For Application Developers

### Record Ownership and Consumption

A record is only consumed (nullified) when passed as a static record input. This has important implications:

- Functions accepting `dynamic.record` or `external.record` do NOT verify ownership or consume the record
- Passing an untrusted `dynamic.record` that is never converted to a static record provides no ownership guarantees
- Always convert to static records when ownership verification is required

### Information Leakage

Dynamic calls reveal information through transaction structure:

- The target program and function are publicly visible in transitions
- Observers can determine which branch was taken in conditional execution
- The number and structure of dynamic calls may leak information about program logic

### Reentrancy Considerations

Dynamic dispatch introduces potential reentrancy vectors:

- A dynamically-called function could call back into the caller
- State should be updated before making dynamic calls when possible
- Consider implementing reentrancy guards for sensitive operations

### Interface Validation

The VM enforces type compatibility at the call boundary, but:

- Semantic compatibility (what the function actually does) is not enforced
- Verify that dynamically-called programs implement expected behavior
- Consider maintaining allowlists of trusted implementations for sensitive operations

### Future Execution Order

When multiple `dynamic.future` values are awaited:

- Execution order follows the order of `await` statements
- State changes from earlier awaits are visible to later ones
- Design finalize logic with awareness of potential interleaving

## For Protocol Implementers

- Translation circuits must be verified alongside transition and inclusion proofs
- Dynamic call graph must be validated to prevent malformed transactions
- Future resolution must guarantee exactly-once execution semantics
- Batch proof limits must account for translation circuit instances

# References

- [Aleo Developer Documentation](https://developer.aleo.org)
- [EIP-1967: Standard Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967) (comparable pattern in Ethereum)
- [Uniswap V4 Hooks](https://docs.uniswap.org/contracts/v4/concepts/hooks) (comparable pattern in Ethereum)
