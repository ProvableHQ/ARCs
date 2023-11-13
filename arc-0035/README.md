---
arc: 0034
title: Enable to set beneficiary for validator
authors: Ghostant1017
discussion: 
topic: Protocol
status: Draft
created: 13/11/2023
---

## Abstract

In AleoBFT, validators benefit from bonding `credits.aleo/credits` into the program `credits.aleo`. Others can delegate to bond `credits.aleo/credits` to one of the `credits.aleo/committee` to get reward by staking. However, the validators can call `credits.aleo/unbond_delegator_as_validator` to unbond any delegator that is bonded to them. If validators allow other people to bond with them , their own rewards are diluted, which does not incentivize validators to accept other people's pledges.

In this ARC, we propose to add a beneficiary for validator, which means that, the PoS rewards will not be directly sent to the bonded address.All rewards will go to an external account or a contract account. And if the beneficiary is set as a contract account, the validator could customize the logic distribute the rewards.It enables the validator to charge service fee from users and incentive validators to attract users to delegate credits to them.

  


## Specification

<!-- Define key terminology here. -->

1.Add a extra field in `credits.aleo/struct committee_state`

```aleo
struct committee_state:
		// The beneficiary of the validator where the PoS rewards will be distributed to.
		beneficiary as address;
    // The amount of microcredits bonded to the validator, by the validator and its delegators.
    microcredits as u64;
    // The boolean flag indicating if the validator is open to stakers.
    is_open as boolean;
```

2.Change the logic in `fn staking_rewards`

```rust
let beneficiaries: HashMap::<Address, u64> = HashMap::new();
cfg_iter!(stakers)
        .map(|(staker, (beneficiary, validator, stake))| {
						if beneficiary != validator {
              	// Distribute the rewards to the `beneficiary`
          }
}
```

3.Update the logic in `fn ensure_stakers_matches`

### Test Cases

1.Test the reward distribution when `beneficiary == validator`

2.Test the reward distribution when `beneficiary != validator`

- Check the committee map
- Check the bond map
- Check the balance map




## Reference Implementations

Not yet

## Dependencies

This proposal will only affect the snarkVM.



### Backwards Compatibility

We need to think carefully about the incentive-economy model of PoS to avoid implications for backward compatibility




## Security & Compliance

There should be no regulatory concerns.




## References


