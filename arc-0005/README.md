---
arc: 5
title: Reduce Execution Fees by 90% and Introduce Priority Fees
authors: kpandl, vicsn
discussion: https://github.com/ProvableHQ/ARCs/discussions/92
topic: Protocol
status: Final
created: 2025-03-12
---

## Abstract

The use of zero knowledge cryptography in Aleo enables a highly scalable blockchain network. However, those scalability benefits have not translated into low fees on the Aleo network - yet. Because of a large focus on security, high fees have served as an additional layer of defense against Denial of Service attacks. The time has come to deliver on the promise of zero-knowledge proofs, and to make transactions cheap.

Technically, this will soon be possible because of the [spend limits](https://github.com/ProvableHQ/snarkOS/pull/3471) which are introduced, acting as another layer of defense against high compute. As such, this ARC proposes to reduce compute-related costs by a factor of `25x`, which will significantly bring down average transaction costs by up to 92%.

We suggest to land this feature for release v3.6.0, which means testnet wallets will have to upgrade by May 13th and mainnet wallets by May 20th.

## Background

The current fee model is very simple. Transactions which are submitted to the Aleo ledger consume resources on the network, and should therefore be priced accordingly. Transactions can either be deployments or executions.

### Deployment base fees

* There is a size cost, determined by the amount of raw bytes of your program.
* There is a namespace cost, the smaller your program name the more you pay. There is no namespace cost if your program name is 10 characters or longer.
* There is a synthesize cost to process your program. The more complicated operations which your program has, the more time it takes for the network to convert this to a circuit to create zero knowledge proofs for. This cost is compute related.

### Execution base fees

This is what you pay for executing program functions on the Aleo network.
* There is a size cost, determined by the amount of raw bytes of your program.
* This is a finalize cost, determined by the amount of operations in your function's finalize scope. This cost is compute related.
* There is no execution cost, because verifying the associated zero knowledge proof is very fast.

## Specification

Initially, the compute costs can be reduced in snarkVM by introducing a `const COST_FACTOR` set to `25` as part of the network trait. snarkVM then uses the cost factor to compute fees of deployments and executions:
* A new function `deployment_cost_v2` will divide the `synthesis_cost` by the `COST_FACTOR`. Note that `storage_cost` and `namespace_cost` remain the same.
* A new function `execution_cost_v3` will divide the `finalize_cost` by the `COST_FACTOR`. Note that the `storage_cost` remains the same.

Both new functions deployment_cost_v2 and execution_cost_v3 can become effective at a certain block height in the near future.

Because fees are now much lower, we can also re-introduce priority fees in snarkOS. This will require another migration rule.

Clarifying by repository:
* snarkVM: We introduce a `const COST_FACTOR` which reduces compute-related fees by `25x`
* snarkOS: Because fees are now so low, we re-introduce priority fees in snarkOS. [Related PR 2977](https://github.com/ProvableHQ/snarkOS/pull/2977)

### Test cases

In snarkVM, we add a unit test to ensure the transaction fees are reduced as expected.

In snarkOS, we add a unit test to ensure a transaction with a high priority fee is moved ahead of the mempool queue.

In addition, we do extensive stress testing.

## Experimental evaluation

We experimentally implemented the snarkVM PR and analyzed fees of commonly used functions.

### Deployments

| Tx type                        | Price before [microcredits] | Price after [microcredits] | Reduction [%] |
|--------------------------------|-----------------------------|----------------------------|---------------|
| credits1.aleo                   | 134,619,400                 | 115,123,243                | 14.4          |
| grant_disbursement_arcane.aleo | 13,805,525                  | 8,953,181                  | 35.1          |

### Executions

| Tx type                       | Price before [microcredits] | Price after [microcredits] | Reduction [%] |
|-------------------------------|-----------------------------|----------------------------|---------------|
| credits.aleo transfer_public  | 34,060                      | 2,725                      | 91.9          |
| credits.aleo transfer_private | 2,242                       | 2,242                      | 0             |

As seen in the data, especially execution costs can be reduced massively. This is of large benefit for the users of the Aleo blockchain, since the vast majority of transactions are execution transactions (~12 Million executions vs. ~200 deployments). It is expected that transfer_private transactions remain at the same price, as their only costs are the storage costs determined by the transaction size.

For most functions where the execution fee is reduced, we expect the reduction to be in the range of 91 to 98.4%.

## Dependencies

This PR relies on [snarkOS PR #3471 (spend limits)](https://github.com/ProvableHQ/snarkOS/pull/3471) to be merged.

## Backwards Compatibility

Although old fees may technically still be sufficient, transaction generators / wallets / transaction cannons should ensure from the network upgrade onwards that they:
* Use the new lower base fee computed from `deployment_cost_v2` and `execution_cost_v3`.
* Offer a pathway for users to submit priority fees to increase the speed of inclusion, potentially even offering an interface to observe the average recent priority fee on the network to facilitate efficient bidding. 

## Security & Compliance

Testing of the PR, in conjunction with the batch proposal spend limits, shall ensure that new compute loads can be handled by validators and clients.

## Out of scope

There is an abundance of literature on fee markets and mechanism design. The proposal in this ARC is simple to audit and adopt, and is an essential step on the road towards more complex out of scope upgrades, such as `EIP1559` or blockspace tokenization.

## References

* [snarkOS PR #2977 on processing unconfirmed transactions by priority fee and age](https://github.com/ProvableHQ/snarkOS/pull/2977)
* [snarkOS PR #3471 on batch proposal spend limits](https://github.com/ProvableHQ/snarkOS/pull/3471)