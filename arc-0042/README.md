---
arc: 42 
title: Adjust block reward algorithm to make sure inflation is stable
authors: Haruka Ma
discussion: https://github.com/ProvableHQ/ARCs/discussions/76
topic: Protocol
status: Final 
created: 2024-09-09
---

## Update

This ARC has been refined, implemented, and incorporated into snarkVM [here](https://github.com/ProvableHQ/snarkVM/pull/2569).

## Abstract

The AleoBFT consensus doesn't guarantee a stable block interval, but the current block reward algorithm assumes the block interval is fixed at 10 seconds, and is emitting rewards regardless of actual block intervals. This makes the 5% annual reward target almost unattainable: shorter block intervals causes higher reward frequency and higher annual reward, and vice versa.

As an example, if the block interval is 3 seconds throughout a full year, the effective inflation rate from base block reward would be 16.67% instead of 5%.

This ARC proposes changes to the block reward algorithm so it could adjust the per-block reward according to the actual block interval, therefore achieving the 5% annual target without being affected by fluctuations of the validator network.


## Specification

Proposed new block reward algorithm and implementation:

```rs
/// Calculate the block reward, given the total supply, block interval, coinbase reward, and transaction fees.
///     R_staking = floor((0.05 * S) * min(I, 60) / S_Y) + CR / 3 + TX_F.
///     S = Total supply.
///     I = Seconds since last block.
///     S_Y = Seconds in a year (31536000).
///     CR = Coinbase reward.
///     TX_F = Transaction fees.
pub fn block_reward(
    total_supply: u64,
    secs_since_last_block: i64,
    coinbase_reward: u64,
    transaction_fees: u64,
) -> u64 {
    // Compute the annual reward: (0.05 * S).
    let annual_reward = total_supply / 20;
    // Compute the block reward: (0.05 * S) * min(I, 60) / S_Y.
    let block_reward = annual_reward * secs_since_last_block.min(60) as u64 / 31536000;
    // Return the sum of the block reward, coinbase reward, and transaction fees.
    block_reward + (coinbase_reward / 3) + transaction_fees
}
```

The proposed algorithm takes the actual block interval into account, emitting less reward if block interval is short, and vice versa.

Note the block interval is capped to 60 seconds in the calculation; this is set mainly to remedy situations like chain halts or the gap between genesis timestamp and first block (only applicable to future chain resets for testnets) so there won't be a sudden large sum of credits being rewarded in one block. The 60 seconds here is just an arbitrary number; actual interval cap should be discussed further.

Also note the block interval is guaranteed to be greater than zero on the consensus level.

### Test Cases

Tested with the above code on local devnet:
![image](https://github.com/user-attachments/assets/6b0ffd7e-9d89-4de3-bf4a-b091e4c3f4ee)


## Dependencies

snarkVM. Potentially other products that relies on the implementation.

### Backwards Compatibility

Implementing this ARC requires the snarkVM and snarkOS to have a proper soft fork mechanism.


## Security & Compliance

The proposed algorithm affects the tokenomics, albeit it's trying to bring the chain back to the intended state.

### Conflict of interests among validators

This section lists some situations the author could think of.

1. As the block reward linearly increases with the block interval, validators might want to hold the block generation until the interval cap is reached. The only incentive here could be to save some CPU cycles related to block generation, as in the end the total block rewards will be the same regardless of the blocks generated in a given period. Plus, holding back the blocks might cause additional puzzle solutions to abort, as there could be at most 4 solutions in a block, and considering puzzle rewards contributes to the block reward as well, doing this could actually harm the income of validators.
2. Validators might collude to generate blocks with fake timestamps in order to inflate the rewards. In short-term, this might give validators more rewards. However, by being dishonest, validators will be harming the credibility of the chain; therefore in the long run, this would harm the investment done by validators considering the entry barrier of becoming one. Setting the interval cap to the previously intended block interval (10 seconds) might deter this as well.


## References

N/A
