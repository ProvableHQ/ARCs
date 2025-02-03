---
arc: 30
title: Adding self.parent opcode
authors: evan@demoxlabs.xyz mike@demoxlabs.xyz
discussion: https://github.com/AleoHQ/ARCs/discussions/11
topic: Application
status: Deprecated
created: 9/2/2022
---

## Abstract

Let's get NFTs & Tokens/DeFI working on Aleo. Currently, you can create an ERC-20/ERC-721-like program on Aleo but it is severely limited.
The biggest limitation is that a program cannot own an NFT. This prevents these Aleo tokens from being used in: escrow, auctions, pools, etc.

In order to enable this functionality, we need an opcode in the Aleo instruction set like: `self.parent`. This opcode would be similar to `self.caller` except it would result in the address of the program who called another program.

By creating this opcode, we could design token/nft programs to enable ownership through a public mapping, enabling Aleo users to transfer assets to a program. A program could then hold them in escrow and only release them as dictated through the smart contract.

In ethereum, there's a concept of `tx.origin` -> `self.caller` and `msg.sender`. Currently, there's no `msg.sender` equivalent in ethereum.

## Specification

Given two programs: token.aleo & escrow.aleo

```
program token.aleo;

mapping balances:
    owner as address.public;
    amount as u64.public;

function transfer:
    input r0 as address.private;
    input r1 as u64.private;

    finalize self.caller r0 r1;

finalize transfer:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;

    decrement balances[r0] by r2;
    increment balances[r1] by r2;

function transfer_program:
    input r0 as address.private;
    input r1 as u64.private;

    finalize self.parent r0 r1;

finalize transfer_program:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;

    decrement balances[r0] by r2;
    increment balances[r1] by r2;

function get_balance:
    input r0 as address.private;

    cast balances[r0] into r1 as u64;

    output r1 as u64;
```

```
import token_one.aleo; // can be copy-pasted from token.aleo
import token_two.aleo; // can be copy-pasted from token.aleo

program amm.aleo;

mapping shares:
    owner as address.public;
    amount as u64.public;

function deposit_token_two:
    input r0 as u64.private;

    call token_two.aleo/transfer swap.aleo r0; // Deposit into pool
    call token_two.aleo/get_balance swap.aleo into r1; // Get balance of pool

    mul r0 4294967296u64 into r2; // Multiply deposit by 2^32 to prevent underflow
    div r2 r1 into r3; // Divide deposit by total pool 

    finalize self.caller r0;

finalize deposit_token_two:
    input r0 as address.public;
    input r1 as u64.public;

    increment shares[r0] by r1; // keep track of individual shares
    increment shares[swap.aleo] by r1; // keep track of total shares

function withdraw_token_two:
    input r0 as u64.private; // Shares to withdraw
    call token_two.aleo/get_balance swap.aleo into r1; // Get balance of pool
    cast shares[swap.aleo] into r2 as u64; // Total shares in the pool

    // Get to transfer: shares * pool_balance / total_shares
    mul r0 r1 into r3;
    div r3 r2 into r4;

    call token_two.aleo/transfer_program self.caller r4;

    finalize self.caller r1;

finalize withdraw_token_two:
    input r0 as address.public;
    input r1 as u64.public;

    decrement shares[r0] by r1; // keep track of individual shares
    decrement shares[swap.aleo] by r1; // keep track of total shares

function convert_token_one_to_token_two:
    input r0 as u64.private;

    mul r0 2u64 into r1; // Mocking a price of 1 token_one = 2 token_two
    sub r1 1u64 into r2; // Charge some fee for conversion

    call token_one.aleo/transfer swap.aleo r0;
    call token_two.aleo/transfer_program self.caller r2;

    finalize self.parent r0 r1;
```

`self.parent` should default to the address of the calling program if there is one. If there isn't a calling program, it should result in the same address as `self.caller`.

In our AMM example, we define toy token and amm programs to demonstrate how `self.parent` would be used to enable a program to own assets. In `token.aleo`, a user can transfer assets to a program (`amm.aleo`) by calling `transfer` and assets can be transferred out of the pool by calling `transfer_program`. Effectively, `self.parent` gives `amm.aleo` exclusive control to decide how its balance in `token.aleo` is decremented. In our case, we show how a toy AMM could enable pool deposits/lp share issuance, lp share redemption, and swaps.   

### Test Cases

```
program bar.aleo;

function get_bar:
    output self.parent as address.public;
```

```
program foo.aleo;


function get_foo:
    call bar.aleo/get_address into r0;

    output r0 as address.public;
```

`aleo run get_foo` -> `address(foo.aleo)`
`aleo run get_bar` -> `address(self.caller)`

## Dependencies

This will impact snarkVM and everything that has snarkVM as a dependency.

### Backwards Compatibility

As this is a new feature, no programs should be impacted by adding a new opcode.

## Security & Compliance

There should be no regulatory concerns. 

## References

Explanation of [tx.origin vs msg.sender in ethereum](https://ethereum.stackexchange.com/questions/1891/whats-the-difference-between-msg-sender-and-tx-origin)
