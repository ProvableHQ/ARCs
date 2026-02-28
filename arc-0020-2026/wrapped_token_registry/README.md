# wrapped_token_registry.aleo

Stateless wrapper around `token_registry.aleo` that implements the `TransferPublic` interface (same as `wrapped_credits.aleo`).

## Purpose

Provides a uniform `transfer_public(public recipient: address, public amount: u128) -> Final` interface for the credits-reserved token in the token registry. This allows programs that expect the `TransferPublic` interface to work with either `wrapped_credits.aleo` or `wrapped_token_registry.aleo` interchangeably.

## Dependencies

- `token_registry.aleo` (local, `../token_registry`)

## Token

Wraps the `CREDITS_RESERVED_TOKEN_ID` token in the token registry. Balances are stored in `token_registry.aleo`; this program holds no state and merely forwards calls.
