---
arc: 46
title: "Staking for Puzzle Solution Submissions"
authors:
  - howardwu
  - raychu86
discussion:
  - "https://github.com/ProvableHQ/ARCs/discussions/76"
topic: Protocol
status: Final
created: 2025-05-25
---

## Abstract

This ARC proposes a mechanism requiring provers on the Aleo Network to stake a specific amount of Aleo credits to be eligible to submit a specific number of solutions per epoch. This feature is programmatic, with a stepwise increase in the required amount of stake over a two-year period following the activation of this ARC.

The goal of this ARC is to align prover incentives with the overall network’s health, and gradually adjust up economic requirements for provers as the network matures.

## Motivation

This ARC ensures the network incentivizes all participants to improve the health and security of the Aleo Network. As such, this proposal addresses several key objectives:

- **Sybil Resistance** — Aligning stake with number of solutions per epoch ensures that provers cannot bypass this new cryptoeconomic mechanism by creating new identities on-chain. In addition, this new cryptoeconomic mechanism makes it economically costly for malicious actors to create numerous identities (Sybil attacks) to flood the network with malformed solutions.
- **BFT Security** — The proposed timetable ensures that provers gradually increase their stake participation to achieve at least the availability threshold of the Aleo Network within 2 years. This ensures that provers contribute to the underlying security of the Aleo Network.
- **Economic Growth** — A transparent schedule increase in the staking requirement allows the network to adapt to its growing value and security needs without introducing sudden economic impacts or shocks. By ensuring provers contribute to staking, this ensures that their earned rewards are then directly utilized by the Aleo Network itself.

## Specification

As the Aleo Network grows, ensuring long-term security, stability, and fair participation is critical to the success of the ecosystem.

Currently, provers are able to participate in Proof of Succinct Work and earn puzzle rewards without any entry or exit requirements. This ARC contemplates introducing entry requirements for provers, and while exit requirements are desirable, they are out of scope for this ARC at this time.

To participate as a prover on the Aleo network, this ARC proposes requiring the prover to stake a minimum number of Aleo credits (X) to submit 1 solution per epoch. As such, if the prover wishes to submit 2 solutions per epoch, they must stake 2\*X Aleo credits on the Aleo network. This approach ensures that pools do not gain any advantage over individual provers, ensuring fairness for all parties submitting solutions. As expected, once the prover submits their allotment of solutions per epoch, all subsequent solutions submitted by the prover will be rejected.

At this time, there is no requirement that the prover must stake to any specific validator. Rather, in consensus, the protocol will enforce that the prover submitting solutions has an adequate amount of stake that is bonded to a validator on the Aleo Network.

The staking requirement will increase in a stepwise function over 2 years on a quarterly basis. Namely, each quarter, the amount of stake required to submit 1 solution per epoch will increase for provers.

The following outlines the timetable for introducing the stepwise staking requirements for provers to continue participating on the Aleo Network:

| Effective Date         | Quarter | Stake Required Per Solution Per Epoch |
|------------------------|---------|---------------------------------------|
| Activation (Month 0)   | Q0      | 100,000                               |
| Month 3                | Q1      | 250,000                               |
| Month 6                | Q2      | 500,000                               |
| Month 9                | Q3      | 750,000                               |
| Month 12               | Q4      | 1,000,000                             |
| Month 15               | Q5      | 1,250,000                             |
| Month 18               | Q6      | 1,500,000                             |
| Month 21               | Q7      | 2,000,000                             |
| Month 24               | Q8      | 2,500,000                             |

A security goal of this ARC is to ensure that provers stake at least 33% of the total token supply by the end of the 2 year timeframe. This ensures the network maintains the interest of provers as an availability guarantee for the puzzle itself, as the network adheres to standard Byzantine fault tolerance principles.

## FAQs

The following are commonly asked questions that are intended to provide clarity for this new cryptoeconomic mechanism.

**When will this staking requirement for provers begin?**  
While this ARC will require the governance process to pass it, we hope to start this as soon as Summer 2025.

**The amount of Aleo credits required to stake feels unfair and/or excessive. Why were these amounts chosen?**  
The candid answer is that some participants sell their earned Aleo credits after they have been rewarded, and some pools have been known to facilitate the sale of Aleo credits after they have been distributed. If the participants kept their earned rewards, they would have adequate tokens to begin participating in Proof of Succinct Work with this new proposal. As an early ecosystem, it is imperative to prioritize participants with adequate resources to support and contribute back to the network, while disincentivizing participants who wish to take advantage of a growing ecosystem. In this manner, this ARC will benefit long-term stakeholders of the Aleo Network, improving overall network health.

**Who does this ARC benefit most and why?**  
This ARC benefits three parties: validators, provers, & long-term token holders of Aleo credits. For many validators, they should expect to receive delegations from provers as part of the rollout of this ARC over the next 2 years. For provers, they will earn additional staking yield from their token rewards via the staking process. For long-term token holders of Aleo credits, they should have increased confidence that network tokens are being used to secure the Aleo Network and delegated appropriately to the network. As the staking requirements increase over the next 2 years, long-term holders should recognize the security and health benefits of this gradual rollout for the ecosystem.

## Reference Implementations

A snarkVM implementation is currently nearing final completion as of May 25, 2025. A live preview of this ARC implementation can be found here for your review: `ProvableHQ/snarkVM#2734`.

## Dependencies

The primary changes will occur in snarkVM, and impact snarkOS alongside all provers and pools currently participating on the Aleo Network.

## Backwards Compatibility

This ARC introduces a new cryptoeconomic mechanism and will require a network upgrade. It is not backwards compatible with previous network state when staking for solution submissions was not required. As such, validators must upgrade in unison for this ARC to take effect.
