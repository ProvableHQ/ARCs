---
arc: 8
title: Support Snark Verification in Aleo Programs
authors: raychu86 
discussion: https://github.com/ProvableHQ/ARCs/discussions/102 
topic: Protocol
status: Active
created: 2025-11-28
signature_domain: aleo-gov-8-v1
pass_threshold: 66
quorum_threshold: 66
voting_start: 13600000
voting_end: 14000000
snapshot: 14000000
---

## Abstract

This ARC proposes adding new Snark verification opcodes (i.e. `snark.verify` and `snark.verify.batch`)  to Aleo programs. These opcodes enable the verification of SNARK proofs, specifically Varuna proofs, within the finalize scope of a program. This enhancement enables native, intra-program proof verification and lays the foundation for modular proof composition directly on Aleo.

## Motivation

The ability to **verify SNARK proofs inside Aleo programs** unlocks powerful new patterns in application design. Developers can:

- Build programs that verify external computation.
- Compose proofs from multiple sources on-chain.
- Reduce trust assumptions by embedding verification directly into on-chain program execution.
- This functionality also improves interoperability, allowing proofs produced off-chain or by other systems to be verified natively on Aleo.

## Specification

This ARC introduces **new finalize-only opcodes - `snark.verify.*`**

Currently, the opcodes variants verify Varuna proofs and return a **boolean** result.

Because verifying keys and proofs can be large, this ARC also increases the maximum allowed array size from **512** to **2048** elements.

### Examples

#### **snark.verify**

```
snark.verify r0 r1 r2 into r3

Inputs

- r0 - Verifying key ([u8])
- r1 - Verifier inputs ([field])
- r2 - Proof ([u8])

Output
- r3 - Verification result (boolean)
```

#### snark.verify.batch

```
snark.verify.batch r0 r1 r2 into r3

Inputs
- r0 - Array of verifying keys (2D byte array)
- r1 - Array of verifier inputs (3D byte array - [[[field]; num_batches_on_same_key]; num_keys])
- r2 - Batch proof ([u8])

Output
- r3 - Batch verification result (boolean)

```

### Reference Implementation

An implementation can be viewed here for your review - https://github.com/ProvableHQ/snarkVM/pull/3004

### Backwards Compatibility

This ARC introduces new **finalize-only opcodes** and an increased array capacity. A network upgrade is required to activate the feature, tied to a new Consensus Version. No breaking changes to existing programs are expected.

### Future Work

Future extensions may include support for additional ZK proof systems and/or more generalized proof verification APIs.