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

> **Note:** This is a draft placeholder. The full specification is under active development.

## Specification

> **TODO:** Define the token interface, including required transitions, record types, mappings, and behavior specifications.

### Interface

> **TODO:** Specify the Leo interface definition (per ARC-0009) that conforming token programs must implement.

### Required Transitions

> **TODO:** List and document all required transitions (e.g., `transfer_public`, `transfer_private`, `mint`, `burn`, etc.) with their signatures and semantics.

### Token Registry

> **TODO:** Specify how tokens register with `token_registry.aleo` and how the registry enforces compliance.

### Credits Integration

> **TODO:** Describe how the standard relates to the built-in `credits.aleo` program and how `credits.aleo` itself conforms to this interface.

### Test Cases

> **TODO:** Add test cases covering: token registration, public/private transfers, minting, burning, allowance management, and interface-based dynamic dispatch.

## Reference Implementations

The `programs/` directory contains reference implementations:

- `programs/credits/` — Leo analog of the built-in `credits.aleo` program
- `programs/token_registry/` — Leo analog of `token_registry.aleo`
- `programs/stablecoin_program/` — A compliant stablecoin (USAD/USDCx) demonstrating ARC-0020 compliance with KYC/AML controls
- `programs/bridge_program/` — A bridge program demonstrating cross-chain token handling

See [`INSTRUCTIONS.md`](./INSTRUCTIONS.md) for build and run instructions.

## Dependencies

- **ARC-0009** — Dynamic Dispatch: required for interface-based token interactions
- `credits.aleo` — the built-in Aleo credits program

### Backwards Compatibility

This standard is not backwards compatible with ARC-0021. Programs implementing ARC-0021 will need to be updated to conform to ARC-0020.

ARC-0021 is deprecated.

## Security & Compliance

> **TODO:** Document security considerations including: authorization flows, external authorization hooks, double-spend prevention, and considerations for compliant (KYC/AML-gated) token programs.

## References

- [ARC-0009: Dynamic Dispatch](../arc-0009/README.md)
- [ARC-0021: Multi-Token Standard (Deprecated)](../arc-0021/README.md)
- [compliant-stablecoin reference implementation](https://github.com/ProvableHQ/compliant-stablecoin)
- [aleo-standard-programs](https://github.com/ProvableHQ/aleo-standard-programs)
