---
arc: 20
title: Design for ARC20
authors: The Aleo Team <hello@aleo.org>
discussion: [link](https://github.com/AleoHQ/ARCs/discussions/42)
topic: Application
status: Living
created: 2023-10-31
---

*A big thank you to [Valentin Seehausen](https://github.com/Valentin-Seehausen), [Evan Marshall](https://github.com/evanmarshall), [FullTimeMike](https://github.com/fulltimemike) and authors of the previous two ARC20 specs [Ghostant-1017](https://github.com/ghostant-1017) and [EdVeralli](https://github.com/EdVeralli).*

## Abstract

This ARC introduces a design for minimal Fungible Tokens just like ERC20. It allows for transferring tokens and approving programs to transfer tokens on your behalf.

Given that Aleo does not support interfaces or inheritance, this spec is not enforced by the compiler. However, we invite the community to adhere to these standards in an effort to enhance interoperability between programs.

The previous two ARC20 standards were built on old versions of snarkVM. Now that functionality is stabilizing, we can integrate the community's learnings in a new standard. This minimal initial standard is written in Aleo instructions for simplicity and enhanced auditability. In the future there are many extensions which might be valuable to standardize:
- ERC1155-like multi-token standard
- minting functionality
- multisig or admin functionality

Notes:
- One can approve for more than the existing balance, but spending approved funds from others is of course limited by their balance.
- No metadata is added to the program spec, though deployed program names can suffice as globally unique identifiers.
- An update to snarkVM should soon enable passing an aleo program id as program input to `snarkos developer execute`
- Before committing, this should be audited against the `credits.aleo` program.

## Specification

[token.aleo](./token.aleo)

## Testing

You can test this program on a local devnet. First, set up the devnet. Development private keys and addresses are printed to the terminal. Because the devnet runs in tmux, You can scroll up using `ctrl+b+[`. Be quick because history is limited by default.

```
git clone github.com/aleoHQ/snarkOS
cd snarkOS
git checkout ca3e84c48
./devnet.sh
```

Then run the `test.sh` script from the folder in this ARC repository.
