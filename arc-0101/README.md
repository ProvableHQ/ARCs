---
arc: 101
title: Requirements and Evaluation Criteria for Validators
authors: zack_xb
discussion: https://github.com/ProvableHQ/ARCs/discussions/82
topic: Meta
status: Living
created: 2024-12-13
---

## Introduction

As the Aleo network grows and matures, ensuring a robust, secure, and equitable validator ecosystem is paramount. 
This ARC sets forth a proposed standard for validators participating in the Aleo Network, detailing guidelines and evaluation criteria that strive to maintain network reliability, resilience, and fairness. 
These guidelines have been developed in close collaboration between the Aleo Network Foundation (ANF) and the Aleo community, drawing on insights gained from ongoing network operations and community feedback. 
The purpose of this ARC is to establish transparent, measurable requirements and encourage a merit-based validator selection and evaluation process. 
By adhering to these guidelines, validators can help safeguard the network’s long-term stability and align with Aleo’s mission of fostering a decentralised and secure ecosystem.

## Validator Requirements Guideline

1. Performance Requirements
   - Network Uptime: Validators must maintain a high level of availability. Extended downtime should not exceed 12 hours.
   - Node Maintenance: Validators must maintain Canary, Testnet and Mainnet validator nodes and 3 client nodes.
   - Monitoring Metrics: Validators must regularly submit both Testnet and Mainnet validator metrics for ongoing assessment of performance and reliability.
   - Consensus Liveliness & Recovery: Validators must actively participate in consensus and promptly recover if disconnected, ensuring the continuity and correctness of the ledger.
   - Client Synchronization: Validators must successfully complete required synchronization tests following network upgrades to confirm the network’s operational readiness within 24 hours of announcement.

2. Security Requirements
   - Penetration Testing & Security Audits: Validators must conduct and furnish results of regular penetration tests and security audits, at a minimum on an annual basis or as requested by the ANF.
   - Failover & Infrastructure Resilience: Validators must maintain robust security measures, including backup nodes, monitoring and alerting systems, firewalls, and secure key management solutions to mitigate risks and safeguard network integrity.

3. Tokenomics Requirements
   - Stake Limitations:
   - Validators must not exceed 25% of the total network stake.
   - Validators must maintain a minimum stake of 10,000,000 Aleo Credits (or the current minimum stake) to remain active.

4. Hardware Requirements
   - Minimum Specifications: Validators must meet or exceed hardware parameters set by the ANF, including:
   - CPU: 64 cores (128 cores or more preferred)
   - RAM: 256GiB (384GiB or more preferred)
   - Storage: 4TB (6TB or more preferred)
   - Network: 500Mbps minimum upload/download bandwidth

5. Participation Requirements
   - Maintenance & Support: Validators must respond to requests for upgrades within 24 hours and complete such upgrades within the specified timeframe. They must also remain responsive (within 24 hours) for urgent network issues and coordination events.
   - Node Operations: Participation in Canary, Testnet, Mainnet node and Mainnet Client node operations is required to ensure ongoing network quality.
   - Governance & Community Engagement: Validators must participate in at least 80% of governance votes and regularly attend coordination calls. Missing more than 15% of the calls in any quarter without prior notice is considered a violation of these guidelines.

## Validator Evaluation Criteria for Foundation Delegation

The ANF will periodically evaluate validators based on the following criteria. Each category carries weight and contributes to the overall assessment of a validator’s contributions and reliability:

1. Validator operation requirements (as outlined above)
2. Technical Contribution Open-source code contributions to Aleo network. Development or maintenance of validator tools. (e.g., Dashboards, Documentation, Guides). Operation of reliable RPC endpoints and similar infrastructure services.
3. Ecosystem Contribution Development and deployment of dApps on the Aleo ecosystem. Creation and distribution of educational content, tutorials, and community materials. Hosting or contributing to events (workshops, meetups) that grow the community and developer base.
4. Participation & Communication Timely and clear communication with the ANF and community. Participation in governance discussions and responsiveness to critical network updates.
5. Strategic Importance Geographic diversity to ensure a globally distributed and resilient validator set. Engagement with local ecosystems, key market players, and community builders. Business development efforts that foster ecosystem partnerships and network growth.
6. Long-Term Collaborations (Vendors, Partners, Grantees) Participation in events and marketing initiatives that promote the Aleo network. Demonstrated long-term commitment to ecosystem development and improvement.
7. Governance Active voting behaviour and thoughtful input on governance proposals. Constructive participation in community decision-making processes.

## Conclusion

By setting forth these guidelines and evaluation criteria, we aim to strengthen the Aleo validator community, ensuring that participants meet the highest standards of performance, security, fairness, and ecosystem engagement. 
This ARC serves as a foundational reference for validators, the ANF, and the community, facilitating transparent evaluation and ongoing improvement of the Aleo network. 
We invite feedback and comments on this ARC from the Aleo community. Your insights, questions, and suggestions will help refine these guidelines and ensure they serve the best interests of the network and its participants. 
Together, we will continue to build a secure, inclusive, and sustainable Aleo ecosystem.
