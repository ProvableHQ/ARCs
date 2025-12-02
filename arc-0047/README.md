---
arc: 47
title: Limit Aleo's Total Credits Supply to 5 Billion
authors: raychu86
discussion:  https://github.com/ProvableHQ/ARCs/discussions/101
topic: Protocol
status: Active
created: 2025-11-26
signature_domain: aleo-gov-47-v1
pass_threshold: 66
quorum_threshold: 66
voting_start: 13600000
voting_end: 14000000
snapshot: 14000000
---

## Abstract

This ARC proposes establishing a hard cap of **5,000,000,000 Aleo Credits (ALEO)**. The cap will be enforced by halting block rewards and proving rewards at a predetermined block height (based on theoretical maximum issuance).

## Motivation

Under the current Aleo emission schedule, rewards continue indefinitely and total proving emissions are tied directly to network proving activity. This creates several long-term economic challenges:

- **Unbounded inflation** in perpetuity.
- **Limited predictability** around future token supply.
- **Uncertainty for participants** who rely on fixed-supply or capped-supply economic models.

Establishing a 5 billion ALEO maximum supply addresses these issues by providing:

- **Long-term monetary predictability** for the ecosystem.
- **A clearly bounded total supply**, consistent with other fixed-cap digital assets.
- **Stable expectations** for block producers, provers, developers, and users.

## Specification

The Aleo network launched with an initial supply of ~1.5 billion ALEO. All subsequent issuance occurs through block rewards and proving (puzzle) rewards. This ARC does not modify the emission rates of these rewards; instead, it introduces a deterministic point at which both reward streams terminate.

### Deterministic Block Height Cap

We define a block height H such that, even if every block from genesis to **H** paid out the maximum possible proving reward, total issuance could reach, but never exceed **5 billion ALEO**.

- **H = 263,527,685**

At block height **H**, the following MUST occur:

- **Block rewards = 0**
- **Proving rewards = 0**

Because actual proving activity is consistently below the theoretical maximum, **realized supply will almost certainly fall below 5B ALEO** at the cut-off.

Properties of this approach:

- **Simple and deterministic**: No runtime supply checks or tracking are required.
- **Safe under worst-case assumptions**: Even maximum proving throughput cannot push supply above the cap.
- **Implementation-light**: Only a single network upgrade is required.

### Emission Profile

- **Block reward emissions** are expected to produce ~5% annual inflation on the initial 1.5B supply, i.e., roughly 75M ALEO per year.
- **Puzzle reward emissions** vary with proving activity. The emission rate decreases over time and becomes flat at year 9 from genesis.

|                | Block Height | Block Reward (Avg per Block) | Coinbase Reward (Avg per Block) |
|----------------|--------------|------------------------------|----------------------------------|
| Genesis        | 0            | 7.1                          | 20.5                             |
| Year 1         | 10.5M        | 7.1                          | 19.4                             |
| Year 2         | 21M          | 7.1                          | 17.1                             |
| Year 3         | 31.5M        | 7.1                          | 14.8                             |
| Year 4         | 42M          | 7.1                          | 12.6                             |
| Year 5         | 52.6M        | 7.1                          | 10.3                             |
| Year 6         | 63.1M        | 7.1                          | 8.0                              |
| Year 7         | 73.6M        | 7.1                          | 5.7                              |
| Year 8         | 84.1M        | 7.1                          | 3.42                             |
| Year 9         | 94.6M        | 7.1                          | 2.3                              |
| Year 10        | 105.1M       | 7.1                          | 2.3                              |
| Year 11        | 115.6M       | 7.1                          | 2.3                              |
| Year 12        | 126.1M       | 7.1                          | 2.3                              |
| Year 13        | 136.7M       | 7.1                          | 2.3                              |
| Year 14        | 147.2M       | 7.1                          | 2.3                              |
| Year 15        | 157.7M       | 7.1                          | 2.3                              |
| Year 16        | 168.2M       | 7.1                          | 2.3                              |
| Year 17        | 178.7M       | 7.1                          | 2.3                              |
| Year 18        | 189.2M       | 7.1                          | 2.3                              |
| Year 19        | 199.7M       | 7.1                          | 2.3                              |
| Year 20        | 210.2M       | 7.1                          | 2.3                              |
| Year 21        | 220.8M       | 7.1                          | 2.3                              |
| Year 22        | 231.3M       | 7.1                          | 2.3                              |
| Year 23        | 241.

|                | Actual Total Supply | Total Supply (Upper Bound) |
|----------------|----------------------|-----------------------------|
| Genesis        | 1.5B                 | 1.5B                        |
| Year 1         | 1.816B               | 1.848B                      |
| Year 2         | -                    | 2.127B                      |
| Year 3         | -                    | 2.382B                      |
| Year 4         | -                    | 2.613B                      |
| Year 5         | -                    | 2.820B                      |
| Year 6         | -                    | 3.003B                      |
| Year 7         | -                    | 3.162B                      |
| Year 8         | -                    | 3.297B                      |
| Year 9         | -                    | 3.408B                      |
| Year 10        | -                    | 3.507B                      |
| Year 11        | -                    | 3.606B                      |
| Year 12        | -                    | 3.705B                      |
| Year 13        | -                    | 3.804B                      |
| Year 14        | -                    | 3.903B                      |
| Year 15        | -                    | 4.002B                      |
| Year 16        | -                    | 4.100B                      |
| Year 17        | -                    | 4.200B                      |
| Year 18        | -                    | 4.299B                      |
| Year 19        | -                    | 4.398B                      |
| Year 20        | -                    | 4.497B                      |
| Year 21        | -                    | 4.596B                      |
| Year 22        | -                    | 4.695B                      |
| Year 23        | -                    | 4.794B                      |
| Year 24        | -                    | 4.893B                      |
| Year 25        | -                    | 4.991B                      |
| Year 25 Q4+    | -                    | 5B                          |


## Reference Implementations

An implementation can be viewed here for your review - https://github.com/ProvableHQ/snarkVM/pull/3042


## Backward Compatibility

This ARC introduces a new cryptoeconomic mechanism and will require a simple network upgrade. Because this change is planned far in the future, it does not require specifying an explicit consensus-version activation. It is sufficient that node operators upgrade at some point within the ~25-year timeframe. In practice, many other consensus upgrades will occur long before then.

## Future Work

Because the changes are not expected to occur until ~Q4 2049, there is flexibility for adjusting the limit height in the future to be more accurate if there are major changes to network assumptions in the future.
