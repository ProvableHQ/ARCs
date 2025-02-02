---
arc: 0031
title: Improving mappings
authors: evan@demoxlabs.xyz, mike@demoxlabs.xyz
discussion: [ARC-0031: Improving mappings](https://github.com/AleoHQ/ARCs/discussions/20)
topic: Application
status: Draft
created: 10-05-2022
---

## Abstract

Mappings are how Aleo programs store public state. To make them more useful, we should:
1. Load the value of mappings directly. 
2. Store the value of mappings directly.
3. Support structs & strings as mapping data types.

## Specification

1. A function should be able to load the value of a mapping directly. 

```
mapping balances:
    key owner as address.public;
    value amount as u64.public;

function get_balance:
    input r0 as address.public;
    load balances[r0] into r1;

    output r1 as u64.public;
```

2. A finalize statement should support storing the value of a mapping directly
```
mapping balances:
    key owner as address.public;
    value amount as u64.public;

function store_balance:
    input r0 as address.public;
    input r1 as u64.public;

    finalize r0 r1;

finalize store_balance:
    input r0 as address.public;
    input r1 as u64.public;

    store balances[r0] r1;
```

3. Mapping should support structs & strings

```
struct nft:
    id as u64.public;
    collection_id as u64.public;
    url as string.public;
    metadata as string.public;

mapping nft_owners:
    key owner as address.public;
    value nft_item as nft.public;

function mint_nft:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as u64.public;
    input r3 as string.public;
    input r4 as string.public;

    cast r1 r2 r3 r4 into r5 as nft;

    finalize r0 r5;

finalize mint_nft:
    input r0 as address.public;
    input r1 as nft;

    store nft_owners[r0] r1;
```

4. The REST API should support endpoints to fetch the mapping.

## Dependencies

This will impact snarkVM and everything that has snarkVM as a dependency.

### Backwards Compatibility

As this is a new feature, no programs should be impacted by adding a new opcode.

## Security & Compliance

There should be no regulatory concerns. 
