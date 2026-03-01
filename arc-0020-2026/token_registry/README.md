# token_registry.aleo

Token registry for wrapped credits and custom tokens. Migrated from [ProvableHQ/aleo-standard-programs](https://github.com/ProvableHQ/aleo-standard-programs).

**Omitted (Leo 3.4):** `burn_private`, `prehook_private`, `transfer_private_to_public` — record inputs require entry points. `credits.aleo` import removed; CREDITS_RESERVED_TOKEN_ID is a constant.

**Functions:** `initialize`, `register_token`, `update_token_management`, `set_role`, `remove_role`, `mint_public`, `mint_private`, `burn_public`, `prehook_public`, `transfer_public`, `transfer_public_as_signer`, `transfer_public_to_private`, `transfer_pub_to_priv_as_signer`, `transfer_from_public_to_private`, `transfer_from_public`, `approve_public`, `unapprove_public`, `transfer_private`, `join`, `split`.

**Tests:** From `arc-0020-2026/tests`: `npm test -- token-registry.test.js`
