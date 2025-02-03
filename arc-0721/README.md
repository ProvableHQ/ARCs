---
arc: 721
title: Aleo Non-Fungible Token Standard
authors: Pierre-André LONG - pa@zsociety.io
discussion: https://github.com/ProvableHQ/ARCs/discussions/79
topic: Application
status: Accepted
created: 2024-10-14
---

## Abstract

Several NFT standards have already been proposed on Aleo. This proposal aims at reconciling these approaches to allow the broadest range of use cases made possible by Aleo’s unique privacy features.

Compared to NFTs on public ledgers like Ethereum, Aleo NFTs can independently have:

- Private or public token owner visibility.
- Private or public data associated the token.

Both of those features have implications on feasibility of building applications involving NFTs as a marketplaces, escrow programs… This proposal aims to integrate those features on top of the previous standard proposals while keeping those applications possible.

Example:

- Domain Names - Human-readable names that resolve addresses in the [Aleo Name Service contract](https://github.com/S-T-Soft/aleo-name-service-contract).
- Royalty NFTs - Tradable assets which utility is to claim creator or marketplace royalty fees.
- IOU NFTs - Tradable assets allowing to claim due fungible tokens in a lending agreement, including private loan data.

[The complete code for the standard is available here.](https://github.com/zsolutions-io/aleo-standard-programs/blob/main/arc721/src/main.leo)

## Motivations

### On-chain vs Off-chain data

The proposed standard allows for NFT data to be on-chain, off-chain or a combination of both. Off-chain to reduce the storage fees on the network. On-chain to leverage the possibility of using this data as input/outputs of zk-circuits.

Remark: On-chain data can either consists of a hash of some data or be the data itself directly depending on the use case’s requirement of guarantying access to the data transactionally.

## Specifications

A NFT collection is defined as a program implementing the following specifications.

### Strings

As NFTs heavily rely on the use of strings, either for URL to off-chain data or for data itself, they require to standardize encoding of strings into Aleo plaintexts:

```rust
// Leo
string: [field; 4],
```

```rust
// Aleo instructions
string as [field; 4u32];
```

Length of the array can be freely adapted to match the maximum amount of characters required by the collection.

The choice of fields type is motivated by the fact that they offer close to twice the amount of data for the same constraints as u128. An array of u8, while making application more readable, is even less optimal.

This specification for strings is compatible with ARC21 standard for name and symbol of fungible tokens.

[Here is a Javascript example of convertions between js string and aleo plaintext.](https://github.com/zsolutions-io/aleo-standard-programs/blob/main/arc721/utils/strings.js)

### Data Structure

The data stored within a NFT has the following structure:

```rust
struct attribute {
    trait_type: [field; 4],
    _value: [field; 4],
}

struct data {
    metadata: [field; 4], // URI of offchain metadata JSON
    // (optional) name: [field; 4],
    // (optional) image: [field; 16],
    // (optional) attributes: [attribute; 4],
    // (optional) ...
}
```

An example of such an off-chain metadata JSON can be found [here](https://aleo-public.s3.us-west-2.amazonaws.com/testnet3/privacy-pride/1.json).

Name of the structs don’t necessarily have to match ‘data’ and a’ttribute’, allowing to import several NFT collection program without shadowing. Although, the name of each struct attribute is enforced by the standard. Aleo reserved keywords should be prefixed with an underscore character (as for ‘_value’).

To get the complete data for a NFT, off-chain and on-chain data can simply be merged, for instance in javascript:

```jsx
const nft_data = {
    ...await (await fetch(nft.data.metadata)).json(),
    ...nft.data, // on-chain data overrides off-chain data
}
```

### Private Data and Ownership

As for ARC20-21 tokens, privacy of NFT owner is achieved by representing the token as an Aleo record. It also allows the data of an NFT to remain private, by including it as a private attribute of the record.

Although, to enforce uniqueness, a public identifier for the NFT is necessary. Simply using a hash of the data would introduce 2 problems:

- Two NFTs could not share the same data.
- It would disclose some knowledge about the data: verifying that some data matches would be an instantaneous operation.

For these reasons, we include in the NFT record a scalar element, called edition:

```rust
record NFT {
    private owner: address,
    private data: data,
    private edition: scalar,
}
```

We define the public identifier for the NFT as the commit of its edition to the hash of its data:

```rust
inline commit_nft(
    nft_data: data,
    nft_edition: scalar
) -> field {
    let data_hash: field = BHP256::hash_to_field(nft_data);
    let nft_commit: field = BHP256::commit_to_field(data_hash, nft_edition);
    return nft_commit;
}
```

This “NFT commit” does not disclose any information on the NFT data as long as the edition obfuscator is chosen uniformly randomly in the scalar field.

The following mapping serves to enforce the uniqueness of “NFT commit” identifiers:

```rust
mapping nft_commits: field => bool;
// NFT commit => NFT exists or has existed
```

### Public Ownership

Apart from guarantying non-fungibility, NFT commit also allows to make the owner of the NFT public, while keeping its data private.

This is a key feature on Aleo because it allows program to own NFTs without revealing their data, as programs cannot spend records.

The same as for ARC20-21 tokens, an NFT owner can be made public by mapping NFT commit to said owner:

```rust
mapping nft_owners: field => address;
// NFT commit => NFT owner
```

Although it raises a challenging question, if user A is the private owner of a NFT, and transfers ownership to a public owner user B, how can user B know the actual data behind the public NFT commit.

The proposed solution is to include another record, `NFTView`, defined as:

```rust
record NFTView {
    private owner: address,
    private data: data,
    private edition: scalar,
    private is_view: bool
}
```

This record doesn’t represent private ownership of the NFT, but is a vehicle for the NFT data and is minted to the public receiver of transfers along with NFT ownership.

The conversion from private to public owner can then be implemented as follow:

```rust
async transition transfer_private_to_public(
    private nft: NFT,
    public to: address,
) -> (NFTView, Future) {
    let nft_commit: field = commit_nft(nft.data, nft.edition);
    let nft_view: NFTView = NFTView {
        owner: to,
        data: nft.data,
        edition: nft.edition,
        is_view: true
    };
    let transfer_private_to_public_future: Future =
        finalize_transfer_private_to_public(
            to, nft_commit
        );
    return (
        nft_view,
        transfer_private_to_public_future
    );
}
async function finalize_transfer_private_to_public(
    to: address,
    nft_commit: field,
){
    nft_owners.set(
        nft_commit,
        to
    );
}
```

Remark: `is_view` is always true, and is here just for differentiating `NFTView` from `NFT` in plaintext representations of records.

An ultimate problem remains: what if the public receiver of a transfer is a program? Then NFTView doesn’t help.

To illustrate this problem, let’s imagine we are trying to create a marketplace program. A seller lists the NFT using `transfer_private_to_public`. A buyer then accepts the listing and should receive automatically receive the data corresponding to the NFT. One way to do this, could be to have the seller come back, to disclose the private data to withdraw payment.

This back and forth between the buyer and the seller makes the user experience a lot worse than on traditional NFT marketplaces. Hence the need for a mechanism allowing Aleo programs to store private data and disclose it programmatically. An attempt at contributing solving this problem is [Aleo DCP](https://github.com/zsolutions-io/aleo-dcp), where data is splitted according to a MPC protocol. Here is an [example NFT marketplace program](https://github.com/zsolutions-io/aleo-dcp/blob/main/examples/nft_marketplace/programs/marketplace_example/src/main.leo) with the same “one click buy” user experience as with traditional marketplaces, by leveraging Aleo DCP.

Remark: These last considerations are only relevant to NFTs data that should always remain private.

### Public Data

For collections where data can become public, “publishable collections”, the following mapping and function should be included to tackle the problem stated in last section:

```rust
struct nft_content {
    data: data,
    edition: scalar
}

mapping nft_contents: field => nft_content; 

async transition publish_nft_content(
    public nft_data: data,
    public nft_edition: scalar,
) -> Future {
    let nft_commit: field = commit_nft(nft_data, nft_edition);
    let publish_nft_content_future: Future = finalize_publish_nft_content(
        nft_commit,
        nft_data,
        nft_edition,
    );
    return publish_nft_content_future;
}
async function finalize_publish_nft_content(
    nft_commit: field,
    nft_data: data,
    nft_edition: scalar,
) {
    let public_data: nft_content = nft_content {
        data: nft_data,
        edition: nft_edition
    };
    nft_contents.set(nft_commit, public_data);
}
```

`publish_nft_content` can then be called along with transfers to a program, for instace in marketplace program on listing.

### Re-obfuscation

If a NFT content has been published once, the only way to re-obfuscate it is to transfer it to private again, then use the following function to update the edition, hence the commit of the NFT.

```rust
async transition update_edition_private(
    private nft: NFT,
    private new_edition: scalar,
) -> (NFT, Future) {
    let out_nft: NFT = NFT {
        owner: nft.owner,
        data: nft.data,
        edition: new_edition,
    };
    let nft_commit: field = commit_nft(nft.data, new_edition);

    let update_edition_private_future: Future = finalize_update_edition_private(
        nft_commit
    );
    return (out_nft, update_edition_private_future);
}
async function finalize_update_edition_private(
    nft_commit: field,
) {
    assert(nft_commits.contains(nft_commit).not());
    nft_commits.set(nft_commit, true);
}
```

Previous commit is not removed from `nft_commits` mapping, as it would reveal the previous commit and the new one represent the same data.

### Approvals

As for ARC20 tokens, the standard features an approval mechanism allowing accounts to approve another account to spend their token. It can be a specific asset, or any asset from the collection.

```rust
struct approval {
    approver: address,
    spender: address
}

mapping for_all_approvals: field => bool; 
// Approval hash => Is approved

mapping nft_approvals: field => field;
// NFT commit => Approval hash

async transition set_for_all_approval(
    private spender: address,
    public new_value: bool,
) -> Future {
    let apvl: approval = approval {
        approver: self.caller,
        spender: spender,
    };
    let apvl_hash: field = BHP256::hash_to_field(apvl);
    return finalize_set_for_all_approval(
        apvl_hash, new_value
    );
}
async function finalize_set_for_all_approval(
    apvl_hash: field,
    new_value: bool,
){
    for_all_approvals.set(apvl_hash, new_value);
}

async transition approve_public(
    private spender: address,
    private nft_data: data,
    private nft_edition: scalar,
) -> Future {
    let nft_commit: field = commit_nft(nft_data, nft_edition);

    let apvl: approval = approval {
        approver: self.caller,
        spender: spender,
    };
    let apvl_hash: field = BHP256::hash_to_field(apvl);
    return finalize_approve_public(
        self.caller, apvl_hash, nft_commit,
    );
}
async function finalize_approve_public(
    caller: address,
    apvl_hash: field,
    nft_commit: field,
){
    let owner: address = nft_owners.get(nft_commit);
    assert_eq(owner, caller);
    nft_approvals.set(nft_commit, apvl_hash);
}
```

Once approved, the `transfer_from_public` function can be called by the spender, to transfer a NFT from the approver to a recipient address.

### Settings

A mapping is responsible for the collection level settings:

```rust
mapping general_settings: u8 => field;
// Setting index => Setting value
```

Available settings:

- **`0u8` -** Amount of mintable NFTs (all editions).
- **`1u8` -** Number of total NFTs (first-editions) that can be minted.
- **`2u8` -** Symbol for the NFT.
- **`3u8` -** Base URI for NFT, part 1.
- **`4u8` -** Base URI for NFT, part 2.
- **`5u8` -** Base URI for NFT, part 3.
- **`6u8` -** Base URI for NFT, part 4.
- **`7u8` -** Admin address hash.

## Suggested Improvements

### NFT Registry

Because current version of SnarkOS/SnarkVM does not support dynamic contract calls, the same approach as for fungible tokens of making a NFT registry program would reduce the amount of programs to deploy on the network.

It is trickier than for fungible tokens though, because of the requirement to support arbitrary on-chain data structure for NFTs.

[ARC-0722 proposal discussion can be found here.](https://github.com/AleoNet/ARCs/discussions/80)

### Settings

Instead of using a mapping with one index for each setting value, we could use a cleaner metadata struct for the collection, as ARC-20/21 do.

```
struct CollectionMetadata {
    name: u128, // should this be a field?
    symbol: u128, // should this be a field?
    supply: u128,
    base_uri: [4; field],
    max_supply: u128,
    admin: address
  }
```

## Reference Implementations

Implementation : https://github.com/zsolutions-io/aleo-standard-programs/blob/main/arc721/src/main.leo

## References

https://eips.ethereum.org/EIPS/eip-721

Especially, this work relies almost entirely on Demox Labs team previous work on Art-Factory:
https://github.com/AleoNet/ARCs/discussions/36
@fulltimemike, @evanmarshall, @JohnDonavon, @dagarcia7
