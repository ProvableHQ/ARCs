---
arc: 6
title: Program Upgradability
authors: 
- "@ProvableHQ"
discussion: "https://github.com/ProvableHQ/ARCs/discussions/94"
topic: Protocol
status: Draft
created: 2025-04-16
---


# Abstract

As the Aleo ecosystem matures, it is apparent that applications will need to be upgraded over their lifetime. The Aleo Virtual Machine (AVM) provides a method for program-driven upgrades. This method, while sound, has properties that may be undesirable for some applications. **This proposal offers a new method for program upgrades that seeks to be timely and cost-effective, while preventing fragmentation of application state.**


# Goals

We propose a system for program upgrades with the following properties:

1. **Upgrades should be (relatively) cheap for application users**.
2. **Upgrades should be atomic.**
3. **Upgrades should take effect immediately.**
4. **Upgrades should preserve the interface of a program.**
    * An upgrade can:
        * change logic in a `function` or `finalize`
        * define new `struct`s, `record`s, or `mapping`s but cannot modify or remove existing ones.
        * add new `function`s and `closure`s
    * An upgrade **cannot:**
        * change a `function`’s `input` and `output` interface
        * change a `finalize`’s `input` interface
        * change logic in a `closure`. This is because a change in a closure would invalidate all dependent proving and verifying keys.
        * change existing `struct`s, `record`s, or `mapping`s
5. **Upgrades can be rejected by dependent applications.**
6. **Developers must be able to ossify their programs.**



<table>
  <tr>
   <td>
<strong>Program Component</strong>
   </td>
   <td><strong>Delete</strong>
   </td>
   <td><strong>Modify</strong>
   </td>
   <td><strong>Add</strong>
   </td>
  </tr>
  <tr>
   <td><code>import</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>struct</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>record</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>mapping</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>closure</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>function</code>
   </td>
   <td>❌
   </td>
   <td>✅ (logic)
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>finalize</code>
   </td>
   <td>❌
   </td>
   <td>✅ (logic)
   </td>
   <td>✅
   </td>
  </tr>
  <tr>
   <td><code>constructor</code>
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
   <td>❌
   </td>
  </tr>
</table>




# Design

At a high-level, our proposed design introduces **constructors** and **operands** so that users can programmatically define upgrades with the above design goals in mind.

## Operands

The Aleo Virtual Machine will support the following new operands:

* `<PROGRAM_ID>/checksum`
* `<PROGRAM_ID>/edition`
* `<PROGRAM_ID>/program_owner`

**These specific operands can only be used in off-chain AND on-chain contexts.**

### Checksum

* The `checksum` is defined as the SHA3-256 hash of the program string.
* It is available in the `finalize` scope.
* It is a `[u8; 32u32]` and is optionally declared in a `Deployment` transaction.
* Before a defined migration height, the protocol will require that the `checksum` is **NOT** defined in a `Deployment`.
* After a defined migration height, the protocol will require that the `checksum` is defined in a `Deployment`.


### Edition

* The `edition` denotes the version of a program.
* It is available in the `finalize` scope.
* It is a `u16` literal and is explicitly declared in a `Deployment` transaction.
* An `edition` must be `0` when a program is first deployed and must be incremented by 1 on each upgrade.


### Program Owner

* The `program_owner` is the address that deployed the program.
* It is available in the `finalize` scope.
* It is an `address` and is optionally declared in a `Deployment` transaction.
* Before a defined migration height, the protocol will require that the `program_owner` is **NOT** defined in a `Deployment`.
* After a defined migration height, the protocol will require that the `program_owner` is defined in a `Deployment`.

## Constructors

Programs can define constructors which are **immutable** (they cannot be upgraded) sequences of code that are always run on-chain as part of a deployment or upgrade. Here is an example:
```
program foo.aleo;
...
constructor:
  assert.eq foo.aleo/edition 0u16;
```

In this example, the constructor checks that its `edition` is always zero, ensuring that the program cannot be upgraded.

Additionally, constructors have the following rules:
* **If a constructor halts, then the deployment or upgrade will fail.**
* **A program without a constructor is NOT upgradable.**
* **A program WITH a constructor is upgradable.**
* **Programs deployed after program upgradability is supported must all have constructors.**

A core idea of this design is to allow developers to define rich instantiation and upgrade logic that suits their needs. Refer to the [Usage](#usage) section for more examples.

## Verifying a Deployment

To support upgrades, deployments are checked using the additional rules:

* Before upgradability is enabled:
    * the deployment edition is zero.
    * the deployment checksum is `None`
    * the deployment owner is `None`
    * the deployment program does **NOT** use `constructor` or any of the new operands.
* After upgradability is enabled:
    * The deployment checksum is `Some` and that it matches the program.
    * The deployment owner is `Some` and that it matches the transaction
    * The program contains a `constructor`
* If the `edition` is zero (`N::EDITION`), then check that:
    * the program does not exist in the DB or in-memory `Process`
* Otherwise, check that:
    * the program does exist in the DB and in-memory `Process`
    * the new edition increments the old edition by 1
    * the upgraded code is well-formed and does not violate any of the upgrade rules
    * the existing program has a constructor.

## Changes to the VM and DB

In order to ensure that upgrades are correct and preserve existing state, we also require that:
* The deployment storage store all versions of the programs.
* When an upgrade is deployed, the VM/DB should use the same program state (mappings, records, etc.) as before. If an upgrade defines additional state (mappings), it should be initialized and added to the same scope.
* A call should resolve to the latest version of the program.

## Cost
A `constructor` uses the same cost model as on-chain execution, with a multiplier. Currently, this multiplier is set to 100.

# Implementation
The tracking issue for the implementation can be found [here.](https://github.com/ProvableHQ/snarkVM/issues/2654)


# Security & Compliance

## Protocol

The protocol must ensure that:
* **existing programs are valid and not upgradable.**
* **an upgrade does not break an existing program’s interface.**
* **an edition is always incremented by 1.**
* **prior editions are present but invalid.**
* **cyclic programs do not create issues.**
* **users should have a way of explicitly opting in to a program upgrade before executing.**

## Application

Upgrades are a powerful mechanism for improving program usability and management. However, mutability fundamentally introduces new risks for users and dependent applications.

Mutable applications can be modified in malicious ways. For example, a developer can modify program logic to introduce a vulnerability or freeze the function. They could even introduce a new function to drain funds.

In the general case, there is not much a user can do. Users should validate that applications are written correctly and build trust in developers. Developers can demonstrate good intent to users by relying on governance mechanisms or restrictions to what an upgrade can do. Developers can use the upgrade mechanism to “ossify” a program by setting the authority to a “null” value, like the zero address. Ultimately, these are only mitigations and the burden falls on the user to do due-diligence.

Dependent programs have some defenses available to them. In **Usage**, we detail a mechanism where upgrades must be explicitly approved. This allows developers to fix dependent programs and issue a migration when a dependent makes a divergent change. It is worth noting that protocols like Sui do not atomically apply upgrades; the dependent application defaults to the old logic until the developer issues an upgrade. This option, while mitigating risks of malicious upgrades, prevents security patches or critical features from being applied immediately, which can be an issue.

Developers also need to be mindful of the fact that constructors are immutable. **This means that a bug in the constructor logic cannot be fixed by rolling out a new upgrade.** Developers should take special care and perform security audits.

**The protocol provides some application security by requiring that all executions contains signatures over the checksums of the programs they intend to execute. This reduces the likelihood that a malicious developer front-runs an execution with an upgrade that a user did not know about.**

## Audits
Audits have been completed and their findings are addressed in this PR: https://github.com/ProvableHQ/snarkVM/pull/2758.
The reports will be made public.

# Usage

In this section, we detail how constructors and metadata declarations can be used to implement a variety of upgrades.

## Not Upgradable
**Goal.** Define a program that cannot be upgraded.
```
program foo.aleo;
... // A program without a constructor cannot be upgraded.
```
```
program foo.aleo;
...
constructor:
  assert.eq foo.aleo/edition 0u16; // Upgrades will be rejected as their editions will always be nonzero.

```
## Anyone Can Upgrade
**Goal.** Define a program that anyone can upgrade.
```
program foo.aleo;
...
constructor: 
  assert.eq true true: 
...
```

## Fix Dependency

**Goal.** Require that a dependent program is on a specific version.
**Important. If using this pattern, we recommend you make your program upgradable, in case your function is locked due to a dependency upgrade.**

## Remove Upgradability

**Goal.** Allow a developer to lock a program from future upgrades.
**Important. Note that this pattern can be generalized to support ‘toggle-able’ upgrades.**
```
program foo.aleo;
...
mapping locked: // Once an entry is set, assuming that there is no code that removes it, the program will be locked from future upgrades.
    key as boolean;
    value as boolean;
...
constructor:
    contains locked[true] into r0;
    assert.eq r0 false;
...
```

## Admin-Driven Upgrades
**Goal.** Define a program that only an authorized admin can upgrade.

**Important. Note that the admin account can NEVER be changed. This pattern should be used IFF the private key associated with the admin is properly secured.**
```
program foo.aleo;
...
constructor:
    assert.eq program_owner <ADMIN_ADDRESS>; // You can add any number of admin addresses.
...
```

## Content-Locked Upgrades

**Goal.** Define a program that can only be upgraded to a program with some specific contents.
**This helps ensure that an upgrade has some pre-determined logic.**
```
program foo.aleo;
...
mapping expected:
    key as boolean;
    value as u128;
...
constructor:
    branch.eq foo.aleo/edition 0u16 to end;
    get expected[true] into r0; // Assume that there was some mechanism to set the expected value.
    assert.eq foo.aleo/checksum r0;
    position end;
...
```

## Configurable Admin-Driven Upgrades
**Goal.** Define a program that only an authorized admin can upgrade, with the option to swap admins and declare programs upfront.
**This pattern combines the ideas behind Content-Locked Upgrades with the notion of an administrator.**
```
program foo.aleo;
...
mapping admin:
    key as boolean.public;
    value as address.public;
...
mapping expected:
    key as boolean;
    value as [u8; 32u32];
...
constructor:
    branch.neq foo.aleo/edition 0u16 to rest;
    set aleo1... into admin[true]; // Set the admin.
    branch.eq true true to end;
    position rest;
    get expected[true] into r0; 
    assert.eq foo.aleo/checksum r0; // Check that the checksum matches.
    position end;
...
function set_expected:
    input r0 as [u8; 32u32].public;
    async set_expected self.caller r0 into r1;
    output r1 as foo.aleo/set_expected.future;
finalize set_expected:
    input r0 as address.public; // The caller.
    input r1 as [u8; 32u32].public; // The expected checksum.
    get admin[true] into r2; // Get the admin.
    assert.eq r0 r2; // Check that the caller is an admin.
    set r1 into expected[true]; // Set the next expected upgrade.
...
```


## Vote-Driven Upgrades
**Goal.** Define a program that can only be upgraded by an approving vote from a governance contract. \
```
import governor.aleo; // Assume `governer.aleo` has some logic for voting on upgrades. Accepted votes are recorded in a mapping `accepted` which contains an expected checksum.

program foo.aleo;
...
constructor:
    branch.eq foo.aleo/edition 0u16 to end;
    get governor.aleo/accepted[true] into r0;
    assert.eq foo.aleo/checksum r0;
    position end;
```

## Time-Locked Upgrades

**Goal.** Define a program that can only be upgraded after a specific block height.
```
program foo.aleo;
...
constructor:
    gte block.height 10u32 into r0;
    assert.eq r0 true; // Upgrades can be made by anyone, only after block 10.
...
```

# To Developers
* It is important to note that closures are **NOT** upgradable since they make up the verification keys of any function that calls them. Developers should only call external closures that they have verified the functionality of.
* We strongly recommend  that production applications define a secure upgrade pathway. This will allow applications to stay up-to-date with future protocol changes that may affect the underlying circuits

# To Reviewers
* Is there a usage of program upgrades this proposal does not cover?
* Does the upgrade model feel easy to use? Is it operationally safe?
* Should developers be allowed to mark functions as immutable? The current thinking is to defer this to future work, if developers ask for it.

 
