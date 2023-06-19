---
arc: 35
title: Design for ARC20
authors: syyanyuhui@gmail.com
discussion: https://github.com/AleoHQ/ARCs/discussions/35
topic: Application
status: Draft
created: 19/6/2023
---

## Abstract

This ARC introduces a design for Fungible Tokens just like ERC20 which is upgradeable and extensible.

**Data Structures**

- **Record Type**
  - **Credential**: `Credential` is a `record` type that includes information about the `token_id`, `owner`, `total_supply`and `supplied` indicates the amount already issued.
  - **Token**: `Token` is a `record` type that includes information about the `owner`, `token_id` , `amount`.
- **Struct**
  - **Order**: `Order` is a struct to store the exchange information.
  - **Pair**: `Pair` is a struct contains `token_id` and `address`.  As leo doesn't support two-dimensional arrary yet, we can work around it. This is the `key` type of `mapping balance`.
- **Mapping**
  - **balance**: `mapping(token_id, address) => u64` stores the public balance on chain.
  - **exist**: `mapping exist: u64 => bool` indicates whether certain `token_id` is registered or not. Maybe we can store the `(address, total_supply)` as the value.

**Core Transitions**

- **register**: This transiton will create a `Credential` which contains a unique `token_id` and determine the `total_supply` at the same time.
- **drop**: This transition destroy a `Credential`.
- **mint**: This transition need a `Credential` as one of inputs to mint the token which has the same `token_id` with `Credential`.
- **transfer**: This transition need a `Token` as one of inputs to transfer tokens to others.
- **split**: This transition splits `Token` into two parts.
- **burn**: This transition will destroy the token.

**Extensional Transtions**

- **exchange**: This transtion input a `Token` to exchange another `token_id` and `amount`.
- ...

**Upgradeable Transitions for V2**

When we want to add more features to ARC20, we can upgrade it to the v2 version using the following method.

- **credentialv1_for_credentialv2**: This transition will destory the `Credential` from `arc20.aleo` and create a new `CredentialV2` from `arc20_v2.aleo` contains the same `token_id`.
- **tokenv1_for_tokenv2**: This transition will destroy the `Token` from `arc20.aleo` and create `TokenV2` with the same `token_id` and `amount`.

## Specification

```
// The 'arc20' program.
program arc20.aleo {
    record Credential {
        owner: address,
        token_id: u64,
        total_supply: u64,
        supplied: u64,
    }
    
    record Token {
        owner: address,
        token_id: u64,
        amount: u64,
    }
		
	mapping exist: u64 => bool;
    mapping balances: Pair => u64;
		
	// register
    transition register(public token_id: u64, public total_supply: u64) -> Credential {
        return Credential {
            owner: self.caller,
            token_id: token_id,
            total_supply: total_supply,
            supplied: 0u64,
        };
    }
    // Finalize to ensure the token_id is unique
    finalize register(token_id: u64) {
        let flag: bool = Mapping::get_or_use(exist, token_id, false);
        assert_eq(flag, false);
        Mapping::set(exist, token_id, true);
    }
    
    transition mint(c: Credential, to: address, amount: u64) -> (Credential, Token) {
        assert(c.supplied + amount <= c.total_supply);
        let new_c: Credential = Credential {
            owner: c.owner,
            token_id: c.token_id,
            total_supply: c.total_supply,
            supplied: amount + c.supplyed
        };
        let t: Token = Token {
            owner: to,
            token_id: c.token_id,
            amount: amount
        };
        return (new_c, t);
    }
    transition transfer(t: Token, to: address, amount: u64) -> (Token, Token)  {
        let t1: Token = Token {
            owner: t.owner,
            token_id: t.token_id,
            amount: t.amount - amount,
        };
        let t2: Token = Token {
            owner: to,
            token_id: t.token_id,
            amount: amount,
        };
        return (t1, t2);
    }

    transition burn(t: Token) {}

    transition exchange(t: Token, expect_token_id: u64, expect_token_amount: u64) {
		// ...
    }
}
```

```
// The 'arc20_v2' program.
import arc20.leo;

program arc20_v2.aleo {
    record CredentialV2 {
        owner: address,
        token_id: u64,
        total_supply: u64,
        supplied: u64,
    }

    record TokenV2 {
        owner: address,
        token_id: u64,
        amount: u64,
    }

    struct PairV2{
        addr: address,
        token_id: u64,
    }
    mapping existV2: u64 => bool;
    mapping balancesV2: PairV2 => u64;

    // Destroy the token_v1 and create token_v2
    transition credentialv1_for_credentialv2(c1: arc20.leo/Credential.record) -> CredentialV2 {
        let c2: CredentialV2 = CredentialV2 {
            owner: c1.owner,
            token_id: c1.token_id,
            total_supply: c1.total_supply,
            supplied: c1.supplied,
        };
        arc20.leo/drop(c1);
        return c2;
    }
    
    transition tokenv1_for_tokenv2(t1: arc20.leo/Token.record) -> TokenV2{
        let t2: TokenV2 = TokenV2 {
            owner: t1.owner,
            token_id: t1.token_id,
            amount: t1.amount,
        };
        arc20.leo/burn(t1);
        return t2;   
    }

    // transfer 
    // mint 
}
```

### Test Cases

Each case outlined in the specification of each feature should be tested.

### Dependencies

Leo's current features already support it.

### Backwards Compatibility

Everyone could choose to stay at `v1` or upgrade to `v2`  or `v3`  `v4`... as they like!

## Security & Compliance

There should be no regulatory concerns. 
