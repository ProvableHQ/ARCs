---
arc: 1
title: ARC Proposal Guidelines
authors: The Aleo Team <hello@aleo.org>
discussion:
topic: Meta
status: Living
created: 2020-02-07
---

## Abstract

Aleo Request for Comments (ARCs) are protocol-level, network-level, and application-level standards for the Aleo ecosystem.

## Specification

ARC standards proposals should be labeled with one of the following categories:
  - `Protocol`: all core features, system parameters, consensus upgrades, and cryptographic protocols
  - `Network`: all communication protocols, message formats, and RPC standards
  - `Application`: all application-level standards and conventions
  - `Meta`: all informational and general-purpose notices

### Process

```mermaid
graph LR
    subgraph authors
        draft([Draft]) --> active([Active])
    end

    draft([Draft]) -.-> withdrawn([Withdrawn])
    
    subgraph standards
        active([Active]) --> decision{Decision}
        decision{Decision} --> accepted([Accepted])
    end
    
    decision{Decision} -.-> rejected([Draft])

    subgraph standards
        accepted([Accepted]) --> final([Final])
        accepted([Accepted]) --> living([Living])
        final([Final]) -.-> deprecated([Deprecated])
    end
```

`Draft` refers to a proposal that is currently undergoing development and is not ready for review.

`Active` refers to a proposal with a reference implementation that is ready for review.

`Withdrawn` refers to a proposal that was previously marked as `Draft`, or `Active`.

`Accepted` refers to a proposal that has been approved by the community and is ready for implementation.

`Final` refers to a proposal that was `Accepted`, and the reference implementation has been incorporated into Aleo. 

`Deprecated` refers to a proposal that has been superseded or replaced by a new proposal that is now marked as `Final`.

`Living` refers to a proposal that was `Accepted` and intended to remain as a living document.
