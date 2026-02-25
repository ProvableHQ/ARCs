# Compliant Token Template

This directory contains the [compliant_token_template.aleo](https://github.com/sealance-io/compliant-transfer-aleo) and its dependencies from the [sealance-io/compliant-transfer-aleo](https://github.com/sealance-io/compliant-transfer-aleo) repository.

## Programs

| Program | Description |
|---------|-------------|
| `merkle_tree.aleo` | Merkle tree utilities for freeze list proofs |
| `multisig_core.aleo` | k-of-n multisig scheme for Aleo and ECDSA signers |
| `sealance_freezelist_registry.aleo` | Freeze list registry for compliant tokens |
| `compliant_token_template.aleo` | Compliant token with freeze list, allowances, and compliance records |

## Compilation

These programs use Leo syntax that is compiled by [doko-js](https://github.com/sealance-io/dokojs) in the upstream repository. To compile:

```bash
# From the compliant-transfer-aleo repo root:
npm install -g @sealance-io/dokojs@1.0.1 --ignore-scripts
dokojs compile
```

Alternatively, clone the full [compliant-transfer-aleo](https://github.com/sealance-io/compliant-transfer-aleo) repository and run `npm run compile` after installing dokojs globally.

## Deployment Order (for devnet)

For `leo deploy --recursive --devnet`, deploy in this order:

1. `merkle_tree` (no deps)
2. `multisig_core` (no deps)
3. `sealance_freezelist_registry` (depends on merkle_tree, multisig_core)
4. `compliant_token_template` (depends on sealance_freezelist_registry, multisig_core)

## Devnet Tests

One devnet-enabled test per function:

1. **From compliant-transfer-aleo repo** (recommended): Run the full test suite:
   ```bash
   git clone https://github.com/sealance-io/compliant-transfer-aleo
   cd compliant-transfer-aleo && npm install
   npm install -g @sealance-io/dokojs@1.0.1 --ignore-scripts
   dokojs compile
   npm run deploy:devnet   # or use testcontainers
   npm run test -- test/compliant_token.test.ts
   ```

2. **Smoke test** (after deploy): From this directory:
   ```bash
   COMPLIANT_TRANSFER_ROOT=/path/to/compliant-transfer-aleo npm run test:devnet
   ```

## Test Logic

Test logic and account setup can be found in the upstream [compliant_token.test.ts](https://github.com/sealance-io/compliant-transfer-aleo/blob/main/test/compliant_token.test.ts). Each function has a corresponding test: `initialize`, `update_role`, `mint_public`, `mint_private`, `burn_public`, `burn_private`, `transfer_public`, `transfer_public_as_signer`, `approve_public`, `unapprove_public`, `transfer_from_public`, `transfer_public_to_private`, `transfer_from_public_to_private`, `transfer_private`, `transfer_private_to_public`, `get_credentials`, `transfer_private_with_creds`, `set_pause_status`, `join`, `split`, `get_signing_op_id_for_deploy`.
