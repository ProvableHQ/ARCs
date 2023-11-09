---
arc: 0034 # Add the next sequence number
title: Program Interfaces # Title
authors: Pierre-André LONG, contact@aleo.store # Add all Github usernames, emails, and/or full names
discussion: \#43 # Create a 'Github Discussion' titled 'ARC-XXXX: {TITLE}`
topic: Application # Choose: Protocol, Network, or Application
status: Draft
created: 2023/11/07 # Date
---

## Abstract

As of November 1st of 2023, an import instruction must always explicit a specific program id.

This implies that for most usecases manipulating implementations of a standard,
as many instances of the program must be deployed as the amount of standard implementations.

This is the case for instance for applications manipulating ARC-0020/ARC-0721 tokens exchange for example : escrows, auctions, pools.

Interfaces seem to be the most obvious solution to this problem,
extending widely composability on Aleo.

## Specification

In Solidity the following syntax [introduced in version 0.4.11](https://github.com/ethereum/solidity/releases/tag/v0.4.11) is possible for a implementing a simple generic ERC-0020 swap :

```solidity
pragma solidity ^0.8.0;

contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address account) public view returns (uint256);
    function transfer(address recipient, uint256 amount) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function approve(address spender, uint256 amount) public returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract SimpleSwap {
    function swapTokens(
        address fromTokenAddress,
        address toTokenAddress,
        uint256 amount
    ) external {
        ERC20 fromToken = ERC20(fromTokenAddress);
        ERC20 toToken = ERC20(toTokenAddress);
        require(fromToken.transferFrom(msg.sender, address(this), amount), "Transfer from failed");
        require(toToken.transfer(msg.sender, amount), "Transfer to failed");
    }
}
```

<!-- Define key terminology here. -->

<!-- Describe the architecture. -->

An equivalent program in aleo could have the following syntax:

```aleo
interface arc0020.aleo;

mapping balances:
    key as address.public;
    value as u64.public;

function transfer:
    input address.private;
    input u64.private;

    output arc0020.aleo/transfer.future;

finalize transfer:
    input address.public;
    input address.public;
    input u64.public;

function transfer_program:
    input address.private;
    input u64.private;

finalize transfer_program:
    input address.public;
    input address.public;
    input u64.public;


program swap.aleo;

function swap_tokens:
    input r0 as address.private; // From token program address
    input r1 as address.private; // To token program address
    input r2 as u64.private; // From token quantity

    new arc0020.aleo r0 into r3;
    new arc0020.aleo r1 into r4;

    mul r2 1u64 into r5;
    // One for one convertion for simplicity.
    // In reality we could keep track of individual/total shares using a mapping with a struct 
    // including token program address and owner address as key and quantity owned as value
    // and create deposit/withdraw functions, update mapping in finalizes.
    // Then we could deduce the convertion rate.

    call r3/transfer swap.aleo r5 into r6;
    call r4/transfer_program self.signer r5 into r7;

    async swap_tokens r6 r7 into r8;
    output r8 as count_usages.aleo/add_and_subtract.future;

finalize swap_tokens:
    input r0 as arc0020.aleo/transfer.future;
    input r1 as arc0020.aleo/transfer_program.future;
    await r0;
    await r1;
```

## References

Discussions about ARC-0721, focusing on composability on aleo:
<https://docs.google.com/document/d/1VNxEsWrE_2fzJivlwOhVw8lWCJoSeBJz_o6n2_n1vuE/edit>
