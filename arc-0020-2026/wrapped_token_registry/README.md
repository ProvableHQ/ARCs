# wrapped_token_registry.aleo

Stateless wrapper around `token_registry.aleo` implementing the `Transferrable` interface (same as `wrapped_credits.aleo`).

**Interface:** `transfer_public`, `transfer_public_to_private`, `transfer_private`.

**Token:** Wraps custom token ID `99999field` (not CREDITS_RESERVED_TOKEN_ID). No state; forwards to `token_registry.aleo`.

**Dependency:** `token_registry.aleo` (local)
