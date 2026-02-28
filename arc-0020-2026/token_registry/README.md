# token_registry.aleo

Token registry for wrapped credits and custom tokens, migrated to Leo 3.4 syntax from [ProvableHQ/aleo-standard-programs](https://github.com/ProvableHQ/aleo-standard-programs).

## Leo 3.4 Limitations

This program omits the following functions due to a Leo 3.4 compiler restriction: **only entry point functions can have a record as input**. The following functions take a `Token` record as input and are therefore excluded:

- `burn_private`
- `prehook_private`
- `transfer_private`
- `transfer_private_to_public`

The `credits.aleo` import was removed because it triggers an "Only entry point fns can have a record" error when used as a dependency. The CREDITS_RESERVED_TOKEN_ID is defined as a constant.

## Included Functions

- `initialize` – set up credits reserved token
- `register_token` – register a custom token
- `update_token_management`, `set_role`, `remove_role`
- `mint_public`, `mint_private`
- `burn_public`
- `prehook_public`
- `transfer_public`, `transfer_public_as_signer`
- `approve_public`, `unapprove_public`
- `transfer_from_public`
- `transfer_public_to_private`, `transfer_from_public_to_private`
- `join`, `split`

## Tests

Run from `arc-0020-2026/tests`:

```bash
npm test -- token-registry.test.js
```
