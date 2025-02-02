---
arc: 0032
title: Add block_hash and block_height keywords
authors: evan@demoxlabs.xyz mike@demoxlabs.xyz
discussion: https://github.com/AleoHQ/ARCs/discussions/23
topic: Application
status: Draft
created: 12/2/2022
---

## Abstract

Currently, it's not possible to get the `block_height` or `blockhash` within an Aleo program. 
These opcodes would enable Aleo Dapps to take advantage of time without a Time Oracle.

For example, if you have a game like Battleship, a Time Oracle is required to handle the case where one of the players fails to respond. Using `block_height` or `blockhash`, a game could introduce timeouts to handle such edge cases.


## Specification

```
program example.aleo;

record some_record:
    owner as address.private;
    gates as u64.private;
    hash as blockhash.private;
    height as u64.private;

function create_record:
    cast self.caller 0u64 blockhash block_height into r0 as some_record.record;
    output r0 as some_record.record;
```

We should also considering mirroring Solidity global variables:
```
blockhash[block_height]: hash of the given block when blocknumber is one of the 256 most recent blocks; otherwise returns zero
block.basefee: current block’s base fee (EIP-3198 and EIP-1559)
block.chainid: current chain id
block.timestamp: current block timestamp as seconds since unix epoch
```

## Dependencies

This impacts snarkVM, snarkOS, aleo, & leo repositories. As a new opcode determined from consensus, it will impact all parts of the Aleo ecosystem.

### Backwards Compatibility

Adding new opcodes seems to require a regeneration of the genesis block.
Existing programs should not be impacted.


## Security & Compliance

There should not be any security or compliance considerations. 

DApp developers should not use these variables as a source of randomness as they could be influenced by validators.
Depending on the usecase, validators may have trouble influencing results if the programs are sufficiently private.


## References

Global variables in Solidity: https://docs.soliditylang.org/en/v0.8.17/units-and-global-variables.html
