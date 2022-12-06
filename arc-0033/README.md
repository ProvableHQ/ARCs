---
arc: 33
title: Support for global variables
authors: 826285820@qq.com
discussion: [Support for global variables](https://github.com/AleoHQ/ARCs/discussions/26)
topic: Application
status: Draft
created: 12/6/2022
---

## Abstract

Support for global variables makes leo programs more flexible, just like inside solidity. This will make leo programs more diverse and can be applied to more areas.
In ethereum, we can implement the contract replacement function (by modifying the contract address in the global), and if we implement it in leo, it will greatly increase the activity of leo programs.
For example, if I deploy a board game on top of leo, the current leo's program is not enough to protect the fairness of the game's funds, and a global variable (i.e., the contract deployer) needs to be introduced to collect the funds and distribute the winning and losing funds. This would be the fairest in terms of fairness for all players.

## Specification

Here is an example: `global.aleo`

```leo
program global.aleo {
    let  global_address: address;
    let  withdraw_address: address;
    let  is_set = bool;

    transition deploy(global: address, withdraw: address) -> bool {
        if is_set {
            return false;
        }
        if global == withdraw { // global address can`t equal to withdraw address
            return false;
        }
        global_address = global;
        withdraw_address = withdraw;
        is_set = true;
    }

    transition change_deploy(new_addr: address) -> bool {
        if self.caller != global_address { // only deploy can change it
            return false;
        }
        global_address = new_addr;
    }

    transition change_withdraw(old_withdraw: address, new_withdraw: address) -> bool {
        if self.caller != global_address { // only deploy can change it
            return false;
        }
        if old_withdraw != withdraw_address { // old address must match
            return false;
        }
        withdraw_address = new_withdraw;
    }

    transition get_info() -> (address, address, bool) {
        if self.caller != global_address { // only deploy can get it
            return false;
        }
        return (global_address, withdraw_address, is_set);
    }

    // When testing, please comment out the following code, as they are not perfect.
    transition withdraw(to_addr: address,  amount: u64) -> bool {
        if global_address != self.caller { //only use global address to withdraw
            return false;
        }
        if to_addr == self.caller { //can`t use global address as withdraw user 
            return false;
        }

        ...
        // do some check, amount and so on.
        ...

        transfer(self.caller, to_addr, amount);
    }
    //some other features.
}
```

As you can see, I set three global variables for "global.aleo", `global_address`, `withdraw_address`, and `is_set`, which represent the contract deployer, the contract withdrawal account (for game draws, etc.), and whether or not to set This contract does not involve other functions, but only demonstrates how to use global variables.

### Test Cases

The above contract has no other function than just setting global variables. So we just need to `leo run deploy global_address withdraw_address` to set them and then use `leo run get_info` to see if it gives us the same result as we set.

## Dependencies

This impacts snarkVM, snarkOS, aleo, & leo repositories.

### Backwards Compatibility

As this is a new feature, no programs should be impacted by adding a new opcode.

## Security & Compliance

There should be no regulatory concerns.

## References

Explanation of solidity [example](https://docs.soliditylang.org/en/v0.8.17/solidity-by-example.html)
