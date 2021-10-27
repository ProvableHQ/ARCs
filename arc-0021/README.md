---
arc: 21
title: Node types and their networking properties
authors: The Aleo Team <hello@aleo.org>
topic: Meta
status: Living
reviewers: Howard Wu <howard@aleo.org>
created: 2020-02-07
---

## Overview

There are different types of Aleo nodes: client nodes, miner nodes, beacons, sync providers and crawler nodes, each designed with a specific purpose and characteristics.

## Motivation

Currently there is no clear specification delineating how each node type should behave on the network, this ARC aims to provide clarity by defining the expectations for each.

## Design

We focus on the network specifics of each node type.

### Peering properties at a glance

| node type     | upper peering limit                                     | lower peering limit                                                              |
| ------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------- |
| client/miner  | `max-peers`                                             | `min-peers`                                                                      |
| beacon        | 80% `max-peers`, remaining 20% free for new connections | `0`, doesn't eagerly connect but maintains connections with other beacons        |
| sync provider | 80% `max-peers`, remaining 20% free for new connections | `0`, doesn't eagerly connect but maintains connections with other sync providers |
| crawler       | 80% `max-peers`, remaining 20% free for new connections | `min-peers`                                                                      |

### Client nodes

Client nodes are the default nodes of the network. They store the blockchain and propagate peers, blocks and transactions.

They maintain connections based on the configured peering limits (`min-peers` and `max-peers`). If they are below `min-peers`, they try connecting to the configured beacon addresses. If they are above `max-peers`, they disconnect from peers (most recently added first) until they are below the limit.

Client nodes only propagate routable peers; if there are none, the node doesn't fall back to other sets as is the case with beacons.

### Miner nodes

Miner nodes are started with `--is-miner`.

Miner nodes are client nodes with mining enabled. From a network perspective, their behaviour is identical to client nodes, except they also propagate the blocks they have mined themselves.

### Beacon nodes

Beacon nodes are the main entry points into the network. They aim to provide new nodes with peer lists containing active and routable addresses, including sync providers. They don't run with a sync layer enabled and thus don't store or propagate any chain state.

They maintain 20% of their peering capacity free below the `max-peers` limit to accept new connections and don't connect to any peers on their own initiative. In other words, `min-peers` is ignored for these nodes. They also maintain connections with a few other beacons in order to propagate peer lists.

Beacons select peers to include in their peer lists from the peerbook in a specific order, moving to the next set only if the previous was empty.

1. Connected and routable peers.
2. Connected peers that may or may not be routable.
3. Disconnected peers that may or may not be routable.

### Sync provider nodes

Sync provider nodes are dedicated Aleo-run sync providers. They aim to provide new nodes in the network with a reliable source of the chain state.

Much like beacons, they maintain 20% of their peering capacity free below the `max-peers` limit to accept new connections and don't connect to any peers on their own initiative. In other words, `min-peers` is ignored for these nodes. They do, however, periodically connect to other randomly-selected sync providers in order to keep chain state in sync.

### Crawler nodes

Crawler nodes crawl the network for connections and expose centrality measurements and other network metrics generated from the connections via the `getnetworkgraph` rpc endpoint.

They maintain 20% of their peering capacity free below the `max-peers` limit and strive to maintain `min-peers` connections at all times. Thus, the crawling capacity of a crawler node, that is to say the number of short-lived connections the node uses to crawl the network on each peer cycle, is the delta between 80% of the `max-peers` and the `min-peers` limit. Typically, the node keeps the "crawled" connections open long enough to request peer lists from its peers.

Crawlers only propagate routable addresses.

### TBD: crawlers and beacons working together?

- Should they maintain long-standing connections with other beacons or crawlers?
- The centrality measurements gathered by the crawler node could be used to improve the peer lists provided by the beacons?
- Sync provider load balancing? Cc Fabiano.

## Backwards Compatibility

Beacons and sync providers are backwards compatible with our current bootnodes.

Other aspects will need to be considered if we want crawlers and nodes to work together, i.e. extending the network protocol but this should also be backwards compatible.

## Reference Implementations

Ethereum bootnodes [don't carry a sync layer](https://github.com/ethereum/go-ethereum):

> Stripped down version of our Ethereum client implementation that only takes part in the network node discovery protocol, but does not run any of the higher level application protocols. It can be used as a lightweight bootstrap node to aid in finding peers in private networks.

Bitcoin only uses hard-coded seed nodes as a [last resort](https://en.bitcoin.it/wiki/Bitcoin_Core_0.11_(ch_4):_P2P_Network#Peer_discovery):

> The idea is to move away from seed nodes as soon as possible, to avoid overloading those nodes. Once the local node has enough addresses (presumably learned from the seed nodes), the connection thread will close any seed node connections.

