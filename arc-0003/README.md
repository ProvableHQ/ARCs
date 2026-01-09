---
arc: 3
title: Leo and Aleo instructions
authors: acoglio@aleo.org, collin@aleo.org, ericm@aleo.org, howard@aleo.org, pranav@aleo.org
discussion: https://github.com/ProvableHQ/ARCs/discussions/17
topic: Application
status: Living
created: 2022-09-29
---

## Abstract

The purpose of this ARC is to unify syntax between Leo and Aleo instructions to make it clear what tools developers have at their disposal. We propose several breaking changes to both Leo and Aleo instructions to achieve this goal.

| Leo V1           —> | Leo V2 & Aleo Instructions V2 | <—  Aleo Instructions V1 |
|:-------------------:|:-----------------------------:|:------------------------:|
|          ∅          |           `program`           |        `program`         |
|          ∅          |          `interface`          |            ∅             |
|      `mapping`      |           `mapping`           |        `mapping`         |
|      `circuit`      |           `struct`            |       `interface`        |
|      `record`       |           `record`            |         `record`         |
| `@program function` |         `transition`          |        `function`        |
|     `function`      |          `function`           |        `closure`         |
|   *name.network*    |        *name.network*         |      *name.network*      |

## Specification

### Program Scope

The program scope definition `program name.network {}` is a new Leo feature that expresses Aleo programs inside a Leo file more clearly.

**Leo code**
```rust=
import bar.leo;

program foo.aleo {
    mapping balances: address => u64;
    
    record token {
        owner: address,
        gates: u64,
        amount: u64,
    }
    
    struct message {
        sender: address,
        object: u64,
    }
    
    transition mint(owner: address, amount: u64) -> token { ... }
    
    function compute(a: u64, b: u64) -> u64 { ... }
}
```
The following must be defined inside the program scope in a Leo file.
* mapping definitions
* record types
* struct types
* transition function definitions
* helper function definitions

The following must be defined outside the program scope in a Leo file.
* import definitions
* interface definitions.

### Interface Abstract Type
Interfaces are being added to both Leo and Aleo instructions to relate types that have similar implementations.
Interfaces are similar to classes in object-oriented programming languages.

Interfaces can define
* mappings
* transition functions
* helper functions

Interfaces cannot define
* record types
* struct types

**Leo code**
```rust=
interface fooable {
    mapping balances: address => u64;
    
    transition compute(amount: u64) -> u64;
}

program foo.aleo is fooable {
    mapping balances: address => u64;
    
    transition compute(amount: u64) -> u64 {
        return amount + 1u64;
    }
}
```

Interfaces can be implemented by programs with the `is` keyword.
Interfaces must be defined within a [program scope](#program-scope).
Interfaces cannot be instantiated on their own.


**Aleo instructions**
The syntax for interfaces in Aleo instructions has not been finalized.

Interfaces can be implemented by programs with the `is` keyword.
Interfaces cannot be instantiated on their own.


### Struct Type

**Leo code**
```rust=
struct message {
    sender: address,
    object: u64,
}

```
Structs must be defined within a [program scope](#program-scope).
Structs can be instantiated.
Structs can be called by external programs.

**Aleo instructions**
```rust= 
struct message:
    sender as address.private;
    object as u64.private;
```
Structs must be defined after the program declaration `program foo.aleo;`
Structs can be instantiated.
Structs can be called by external programs.


### Transition Function
A transition function is an external function that can modify or create records.
In Aleo's architecture, transitions are datatypes inside of transactions that detail modification or creation of record objects.

Transition functions can call helper [functions](#function).
Transition functions can call other transition functions defined in an external program.
Transition functions cannot call other transition functions defined in the same program.

Although transition functions are introduced with the single keyword `transition`,
documentation should refer to them as "transition functions", not "transitions".

**Leo code**
```rust=
program foo.aleo {
    mapping balances: address => u64;
    
    record token {
        owner: address,
        gates: u64,
        amount: u64,
    }
    
    transition mint(public sender: address, public amount: u64) -> token {
        return token {
            owner: sender,
            gates: 0u64,
            amount, // Shorthand syntax
        } then finalize(sender, amount);
    } 
    
    finalize mint(sender: address, amount: u64) {
        increment(balances, sender, amount);
    }
}
```
In Leo, transition functions were previously written as `@program function` - this syntax is now deprecated.
Transition functions must be defined within a [program scope](#program-scope).
Transition functions can have an associated `finalize` function with the same name that modifies data in a public mapping.


**Aleo instructions**
```rust=
program foo.aleo;

mapping balances:
	key left as address.public;
	value right as u64.public;

record token:
    owner as address.private;
    gates as u64.private;
    amount as u64.private;

transition mint:
    input r0 as address.public;
    input r1 as u64.public;
    cast r0 0u64 r1 into r2 as token.record;
    output r2 as token.record;
    finalize r0 r1;

finalize mint:
    input r0 as address.public;
    input r1 as u64.public;
    increment balances[r0] by r1;
```
In Aleo instructions, transition functions were previously written as `function` - this syntax now defines (helper) [functions](#function).
Transition function can have an associated `finalize` function with the same name that modifies data in a public mapping.


### Helper Function
All other functions are helper functions that do not modify or create records.
Functions cannot call other functions.
Functions cannot call transition functions.

**Leo code**
```rust=
program foo.aleo {
    function compute(a: u64, b: u64) -> u64 {
        return a + b;
    }
}

```
Functions must be defined within a [program scope](#program-scope).
In Aleo instructions, helper functions are written as `closure`.

**Aleo instructions**
```rust=
program foo.aleo;

closure compute:
    input r0 as u64.private;
    input r1 as u64.private;
    add r0 r1 into r2;
    output r2 as u64.private;
```


### Test Cases

Each case outlined in the specification of each feature should be tested.

## Reference Implementations

This section should contain links to reference implementations that the community can review to evaluate the
quality, complexity, and completeness of the new ARC standard.

## Dependencies

This will affect the SnarkVM, Aleo, and Leo repositories.
All grammar and documentation repositories will also need to be updated.

### Backwards Compatibility

(The 'V1' and 'V2' designations refer to Leo and Aleo instructions before and after the change proposed by this ARC. They do not refer to official release versions.)

| Leo V1           —> | Leo V2 & Aleo Instructions V2 | <—  Aleo Instructions V1 |
|:-------------------:|:-----------------------------:|:------------------------:|
|          ∅          |           `program`           |        `program`         |
|          ∅          |          `interface`          |            ∅             |
|      `mapping`      |           `mapping`           |        `mapping`         |
|      `circuit`      |           `struct`            |       `interface`        |
|      `record`       |           `record`            |         `record`         |
| `@program function` |         `transition`          |        `function`        |
|     `function`      |          `function`           |        `closure`         |
|   *name.network*    |        *name.network*         |      *name.network*      |

## Security & Compliance


## References
