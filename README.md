<h1 align="center">Aleo Request for Comments (ARCs)</h1>

<p align="center">
    <a href="https://github.com/AleoHQ/ARCs/actions"><img src="https://github.com/AleoHQ/ARCs/workflows/CI/badge.svg"></a>
    <a href="https://discord.gg/wURR8A7vEe"><img src="https://img.shields.io/discord/700454073459015690?logo=discord"/></a>
</p>

Aleo Request for Comments (ARCs) are protocol-level, network-level, and application-level standards for the Aleo ecosystem.

## ✍️ Getting Started

To create a new ARC proposal:
1. Open a [Github Discussion](https://github.com/AleoHQ/ARCs/discussions/categories/arcs) with your proposal using template [ARC-0000](./arc-0000) and an available ARC number.
2. File a [Pull Request](https://github.com/AleoHQ/ARCs/pulls) with your proposal in a new subdirectory.

### Progressing an ARC

An ARC will start as a "Draft" and progress through the following stages:

Once a proposal is up:
1. The community will discuss and review the proposal. A maintainer will monitor the ARC and change its status to "Active" once it is ready.
   a. ARCs will be prioritized by number of votes and whether a prototype exists.
   b. ARCs will be discussed during certain community calls. Proposers will have the opportunity to join and participate in the discussion.
   c. Up to this point, the ARC can be withdrawn by the proposer or withdrawn by the maintainers if there is no activity for a long time.
2. A governor or a team member of the Aleo Network Foundation (ANF) will create a formal proposal on Aleo governance (https://vote.aleo.org/) and initiate the voting process.
3. The community will vote on the proposal for approval.
4. If the proposal is accepted, its status will be updated to "Accepted" and the associated pull request will be merged into the ARCs repo. If the proposal is rejected, the status will be reverted to "Draft".
5. The relevant parties should complete the implementation. Updates can be made to the ARC as needed through new PRs, which do not need votes.
6. Once the implementation is finalized, the status will change from "Accepted" to "Final" or "Living", depending on the nature of the proposal. The associated discussion will be closed.

A proposal can be "Deprecated" if it is replaced by a new proposal.

### Statuses

See [ARC-0001](./arc-0001) for a detailed explanation of the statuses.

## 📜 License

This library is licensed under either of the following licenses, at your discretion.

 * [Apache License Version 2.0](LICENSE-APACHE)
 * [MIT License](LICENSE-MIT)

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you,
as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.

[rfcs]: https://en.wikipedia.org/wiki/Request_for_Comments
[contact]: mailto:support@aleo.org

