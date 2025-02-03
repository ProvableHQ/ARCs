---
arc: 100
title: Compliance Best Practices for Developers and Operators on Aleo
authors: apruden2008
discussion: https://github.com/ProvableHQ/ARCs/discussions/74
topic: Meta
status: Living
created: 2024-16-06
---

### Introduction ###

The Aleo Network Foundation (“ANF”) as well as the broader community of users and developers has a vested interest in minimizing illicit finance and other extralegal transactions from taking place on the Aleo network. To that end, we set forth the following best practices for bridges and validators to help minimize risks and create a robust network for our infrastructure service providers, developers, and end users.  The Aleo Network Foundation has consulted with experts in the field, industry groups, and our community to inform this proposal.

The below are best practices for bridges and validators because they are the key gating mechanisms.  We propose a set of criteria to require (i) a time lock on funds and assets brought onto the Aleo network, (ii) blacklisting of suspect bridges, actors, and accounts on Aleo, (iii) robust cybersecurity measures to block bad actors, and (iv) monitoring and enforcement mechanisms.  While we will require these best practices of any grantee of ANF, we cannot implement these unilaterally as a provider of a decentralized network.  However, we will employ incentives, ecosystem best practices, and promote tools like blacklists to minimize illicit finance and other illegal transactions on the Aleo network.

### Best Practices for Bridges on Aleo ### 

In the beginning, liquidity on Aleo will come from two sources: centralized exchanges and bridging protocols. We assume as part of this document that centralized exchanges are required to follow the compliance requirements in their respective jurisdictions. Therefore, the recommendations outlined below are designed to be implemented by decentralized *bridge* operators on the Aleo Network.

The best practices for bridge operators on Aleo are:

* Implement a 24-72 hour delay at the point of bridging, to be determined dynamically based on the security environment.
* Set a limit of $10,000 USD/day in equivalent value per address as the starting de minimis amount to mirror the Currency Transaction Report guidelines. Bridges should revisit this $10,000 threshold on a regular basis to reassess if this limit should be higher or lower based on information from enforcement agencies and blockchain forensics firms. As part of the best practices, bridges should also consider delaying lower amounts during extreme situations that require the 72-hour holds.
* Bridges could adopt identity tools like zPass, KYC protocols, etc. to shorten or bypass the lockup periods.
* During this timelock, bridges should screen against illicit funds and malicious actors, such as the following (non-exhaustive):
    * sanctioned addresses listed on OFAC
    * addresses suspected of being in the process of performing DeFi related hacks
    * addresses that have interacted with OFAC-sanctioned addresses
    * addresses involved in previous DeFi related hacks
    * addresses that have received funds from sanctioned wallets
* Guard against transactions from prohibited jurisdictions. Here, we define ‘prohibited jurisdictions’ to include Comprehensively Sanctioned Jurisdictions, as designated by OFAC. However, operators should determine their reasonable risk thresholds for your landscape vis-à-vis their business model and operating landscape. Depending on their landscape, operators are strongly encouraged to include High Risk Jurisdictions by referencing a variety of factors to determine the risk.
* Adopt, at a minimum, standard cybersecurity practices:
    * geofencing to block IP addresses from Comprehensively Sanctioned Jurisdictions at the frontend (website or wallet to access a bridge)
    * blocking wallet addresses that connect with IP addresses from those jurisdictions.
* As part of this best practice, we recommend a two-strikes policy or an appeals process to account for false positive VPN connections, transitory IP addresses, travel pattern discrepancies (e.g., EU citizens traveling to Cuba legally, but flagged by US systems) and other technical errors.
    * blocking known VPN IP addresses indexed to high risk proxies
* Implement real-time monitoring to ensure they are tracking sanctioned and stolen funds lists, from third-party services that monitor on-chain and off-chain data.
* bridges should consider an appeals mechanism in case of technical errors

### Enforcement mechanisms ###

Suggested enforcement mechanisms for the above best practices for bridges:
* We envision a multi-pronged enforcement mechanism:
    * Protocol-level ability to freeze bridges: Validators will have the ability to freeze blacklisted bridges (and programs generally) as part of the protocol (see the section below titled "References/Further Reading")
    * Ecosystem monitoring: We anticipate a custom-built solution that will allow bridges to incorporate real-time data on hacks or other security breaches that could significantly limit the usefulness of the network to illicit actors. We view this as a potentially highly valuable service. The Aleo Network Foundation will also help provide financial support on a case-by-case basis to bridge operators for a limited time-window post-launch.
    * Incentives for bridges that implement best practices: We expect bridges to bear the legal and reputational liability if the bridge or application fails to follow these best practices. However, through the leverage of our grants program and our plan to continually identify bad practices and develop further best practices, we expect to continue to provide support for enforcement activities.

### Proposed Best Practices for Aleo Validators ###

Validators perform the essential role of operating the network by processing transactions, creating new blocks, and holding one another accountable for following the protocol; all in a decentralized way. These

* (Primary) Adopt a blacklist for bridges (community derived, OFAC, and other sources). Validators could also adopt Chainabuse (or similar) as an additional feed for exploit addresses. See bullet 1 of "Enforcement Mechanisms" above.
    * Every validator will maintain a blacklist of programs for which it will not process or propagate transactions. This list will be initialized to `null` at Genesis
    * To prevent a potential network fork, this blacklist should be subject to governance, and ideally consensus should be reached among all stakeholders before any changes to the blacklist are adopted
* Guard against transactions from prohibited jurisdictions. Here, we define ‘prohibited jurisdictions’ to include Comprehensively Sanctioned Jurisdictions, as designated by OFAC. However, operators should determine their reasonable risk thresholds for your landscape vis-à-vis your business model and operating landscape. Depending on their landscape, operators may want to reference High Risk Jurisdictions by referencing a variety of factors to determine the risk.
* Implement, at a minimum, standard cybersecurity practices:
    * geofencing to block IP addresses from Comprehensively Sanctioned Jurisdictions at the frontend (website or wallet to access a bridge)
    * blocking wallet addresses that connect with IP addresses from those jurisdictions.
    * As part of this best practice, we recommend a two-strikes policy or an appeals process to account for false positive VPN connections, transitory IP addresses, travel pattern discrepancies (e.g., EU citizens traveling to Cuba legally, but flagged by US systems) and other technical errors.
    * blocking known VPN IP addresses indexed to high risk proxies
    * implement real-time monitoring to ensure they are tracking sanctioned and stolen funds lists, from third-party services that monitor on-chain and off-chain data.
    * consider an appeals mechanism in case of technical errors

### References / Further Reading ###

* `snarkVM` [PR](https://github.com/AleoNet/snarkVM/pull/2487) implementing the program blacklist
* `snarkOS` [PR](https://github.com/AleoNet/snarkOS/pull/3306) implementing the program blacklist
