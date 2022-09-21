---
arc: 0003 # Add the next sequence number
title: ARC20_leo # Title
authors: eduardo.veralli # Add all Github usernames, emails, and/or full names
discussion: # Create a 'Github Discussion' titled 'ARC-XXXX: {TITLE}`
topic: Application # Choose: Protocol, Network, or Application
status: Draft
created: 2022-09-21 # Date
---

## Abstract

Implementation of the 6 mandatory rules in Leo Programming Language so that they can be invoked in a Smart contract.

They are: **balance_of**, **total_supply**, **approve**, **transfer_from**, **transfer**, and **allowance**.

ARC20 includes 3 optional rules. They are: **decimals**, **name**, **symbol**.

This is a WIP at [ARC20_leo](https://github.com/Entropy1729/ARC20_leo)
<!-- 
This file serves as the suggested template for new ARC proposals.

We understand that every proposal is different, and the purpose of this template is to help guide you
to ensure your proposal has considered as many aspects as possible.

This section should describe the rationale for this ARC.

What problem does this proposal address? 

If someone only reads this far, what do you want them to know? -->


## Specification

### Mandatory functions

#### To run *balance_of* function:

Input file ARC20_leo/inputs/arc20_leo.in
```
[balanceof]
owner_balance: Balance = Balance {
    owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7,
    gates: 0u64,
    amount: 269u64,
    _nonce: 0group,
};
```

`leo run balance_of`

Console output
```
 • Executing 'arc20_leo.aleo/balance_of'...
 • Executed 'balanceof' (in 11642 ms)

➡️  Output

 • 269u64
```

#### To run *total_supply* function:

Input file ARC20_leo/inputs/arc20_leo.in
```
[total_supply]
amount_supply: u64 = 1729u64;
```

`leo run total_supply`

Console output.
```
 • Executing 'arc20_leo.aleo/total_supply'...
 • Executed 'total_supply' (in 5944 ms)

➡️  Output

 • 1729u64
```

#### To run *approve* function:

Input file ARC20_leo/inputs/arc20_leo.in
```
[approve]
owner: address = aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7;
amount_owner: u64 = 164u64;
spender: address = aleo1mgfq6g40l6zkhsm063n3uhr43qk5e0zsua5aszeq5080dsvlcvxsn0rrau;
amount_desired: u64 = 64u64;
```

`leo run approve`

Console output.
```
 • Executing 'arc20_leo.aleo/approve'...
 • Executed 'approve' (in 9745 ms)

➡️  Output

 • true
```

#### To run *transfer_from* function:

Input file ARC20_leo/inputs/arc20_leo.in
```
[test_transferfrom]
from_balance: Balance = Balance {
    owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7,
    gates: 0u64,
    amount: 25u64,
    _nonce: 0group,
};
from: address = aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7;
to_address: address = aleo1mgfq6g40l6zkhsm063n3uhr43qk5e0zsua5aszeq5080dsvlcvxsn0rrau;
to_gates: u64 = 0u64;
to_amount: u64 =  30u64;
amount: u64 = 5u64;
```
`leo run transfer_from`

Console output.
```
 • Executing 'arc20_leo.aleo/transfer_from'...
 • Executed 'transferfrom' (in 21740 ms)

➡️  Outputs

 • {
  owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7.private,
  gates: 0u64.private,
  amount: 20u64.private,
  _nonce: 6431287615986696097612324621785026814136142669749924915411966793544219414836group.public
}
 • aleo1mgfq6g40l6zkhsm063n3uhr43qk5e0zsua5aszeq5080dsvlcvxsn0rrau
 • 35u64
 • 0u64
```

#### To run *transfer* function:

Input file ARC20_leo/inputs/arc20_leo.in
```
[transfer]
to_balance: Balance = Balance {
    owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7,
    gates: 0u64,
    amount: 25u64,
    _nonce: 0group,
};
to: address = aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7;
amount: u64 = 5u64;
```

`leo run transfer`

Console output.
```
 • Executing 'arc20_leo.aleo/transfer'...
 • Executed 'transfer' (in 14139 ms)

➡️  Output

 • {
  owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7.private,
  gates: 0u64.private,
  amount: 30u64.private,
  _nonce: 5223267181059685515422878880245687591758320347768724919987298470390181053809group.public
}
```

#### To run *allowance* function:
Input file ARC20_leo/inputs/arc20_leo.in
```
[allowance]
owner: address = aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7;
spender: address = aleo1mgfq6g40l6zkhsm063n3uhr43qk5e0zsua5aszeq5080dsvlcvxsn0rrau;
balance_owner: Balance = Balance {
    owner: aleo1ht2a9q0gsd38j0se4t9lsfulxgqrens2vgzgry3pkvs93xrrzu8s892zn7,
    gates: 0u64,
    amount: 250u64,
    _nonce: 0group,
};
amount_remaining: u64 = 78u64;

```

`leo run allowance`

Console output.
```
 • Executing 'arc20_leo.aleo/allowance'...
 • Executed 'allowance' (in 16274 ms)

➡️  Output

 • 78u64
```

###  Optional functions
ARC20 includes 3 optional rules. They are: **decimals**, **name**, and **symbol**.

#### To run *decimals* function:
Input file ARC20_leo/inputs/arc20_leo.in
```
[decimals]
quantity_decimals: u64 = 8u64;
```

`leo run decimals`

Console output.
```
 • Executing 'arc20_leo.aleo/decimals'...
 • Executed 'decimals' (in 4244 ms)

➡️  Output

 • 8u64
```

#### To run *name* function:
Input file ARC20_leo/inputs/arc20_leo.in
```
[name]
is_dummmy: u64 = 0u64;
```

`leo run name`

Console output.
```
 • Executing 'arc20_leo.aleo/name'...
 • Executed 'name' (in 6431 ms)

➡️  Outputs

 • 65u64
 • 76u64
 • 69u64
 • 79u64
```

#### To run *symbol* function:
Input file ARC20_leo/inputs/arc20_leo.in
```
[symbol]
is_dummmy: u64 = 0u64;
```

`leo run symbol`

Console output.
```
 • Executing 'arc20_leo.aleo/symbol'...
 • Executed 'symbol' (in 6450 ms)

➡️  Outputs

 • 76u64
 • 69u64
 • 79u64
```

<!--

This section should outline the technical requirements and considerations for incorporating this proposal as
a new ARC standard.

 Define key terminology here. 

 Describe the architecture.

 Include process diagrams. -->

### Test Cases

#### To run **Test** functions:
In every ARC20 function the input values are declared in ```\input\arc20_leo.in```.

Each Test function uses the algorithm of the original function and compares its output with the values coded into the test function.

In case the comparison is successful, the Test function will return True in a boolean variable.

<!--
This section should introduce any and all critical test cases that need to be considered for the specification.

 Provide any test vectors that should be included in unit and/or integration tests.

 Are there edge cases to be aware of?

 Include test code snippets, if possible. ->


## Reference Implementations

This section should contain links to reference implementations that the community can review to evaluate the
quality, complexity, and completeness of the new ARC standard.

<!-- Link to any relevant Github issues. -->

<!-- Link to any related Github branches and/or pull requests. -->


<!--## Dependencies

This section should list the affected products, projects, and repositories that either directly or indirectly
are affected by this ARC proposal.

<!-- Will this affect the Aleo PM, Aleo Explorer, or Aleo Studio? -->

<!-- Will this affect Aleo, Leo, snarkOS, snarkVM, or any other repositories? -->

<!--### Backwards Compatibility

This section should cover any and all backwards incompatibility risks, along with their severity.

<!-- List all backwards incompatibilities and their severity. -->

<!-- How will the backwards incompatibilities be resolved? -->

<!--
## Security & Compliance

This section should address any security and regulatory concerns if the ARC proposal were incorporated into Aleo.
If you are uncertain, please don't hesitate to ask the core team on Discord.

<!-- Outline any potential security concerns. -->

<!-- Does this proposal introduce regulatory risk? -->

<!--
## References

This section should provide any materials that would help reviewers have better context on the nature of the ARC proposal.

<!-- List any links that would be helpful for context. -->

