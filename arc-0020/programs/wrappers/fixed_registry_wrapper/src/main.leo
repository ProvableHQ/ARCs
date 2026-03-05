// fixed_registry_wrapper.aleo
//
// ARC-0020 single-token registry wrapper implementing token_interface.aleo/Mintable.
// Hardcodes a specific token_id, exposing a simplified API without token_id parameters.
//
// Use case: a token issuer deploys one instance per token (USDC, WBTC, etc.).
// The deployer holds MINTER_ROLE on token_registry.aleo for HARDCODED_TOKEN_ID.
//
// Vault pattern (inherited from ExtendedWrapper):
//   Vault-in  (transfer_public_to_private, mint_private):
//     wrapper calls token_registry/transfer_public_as_signer or mint_public
//     with self.address as recipient → accumulates registry balance at wrapper address
//     → wrapper creates Token record for the actual recipient.
//   Vault-out (transfer_private_to_public):
//     wrapper consumes Token record → calls token_registry/transfer_public to
//     release wrapper's registry balance to recipient.
//   Local ops (join, split, transfer_private):
//     pure record manipulation, no underlying call, vault balance unchanged.
//   Public minting (mint_public):
//     delegates directly to token_registry/mint_public with HARDCODED_TOKEN_ID;
//     recipient gets registry balance directly (no vault involvement).
//
// Invariant: wrapper's registry balance for HARDCODED_TOKEN_ID
//   = sum of all outstanding wrapper Token record amounts.

import token_registry.aleo;
import token_interface.aleo;

program fixed_registry_wrapper.aleo : token_interface.aleo/Mintable {

    // Hardcoded token_id for this wrapper instance.
    // Token issuers replace this with the registered token_id for their token.
    const HARDCODED_TOKEN_ID: field = 1field;

    // Wrapper-owned token record.
    // token_id is always HARDCODED_TOKEN_ID; stored for AVM type identity.
    record Token {
        owner: address,
        amount: u128,
        token_id: field,
    }

    // ---------------------------------------------------------------------------
    // Formally enforced by token_interface.aleo/CoreWrapper (via Mintable)
    // ---------------------------------------------------------------------------

    // 1. transfer_public — debits self.caller on token_registry.
    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/transfer_public(token_id, recipient, amount);
        return final { f.run(); };
    }

    // 2. transfer_public_as_signer — debits self.signer (original tx signer).
    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, recipient, amount);
        return final { f.run(); };
    }

    // ---------------------------------------------------------------------------
    // Formally enforced by token_interface.aleo/Mintable
    // ---------------------------------------------------------------------------

    // 8. mint_public — mints tokens to recipient's public registry balance.
    //    No token_id parameter; uses HARDCODED_TOKEN_ID.
    //    Caller must hold MINTER_ROLE on token_registry for HARDCODED_TOKEN_ID.
    //    authorized_until = 0u32 (no external authorization required).
    fn mint_public(
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/mint_public(HARDCODED_TOKEN_ID, recipient, amount, 0u32);
        return final { f.run(); };
    }

    // ---------------------------------------------------------------------------
    // Informally conformant (record-based; not cross-program interface-enforced)
    // ---------------------------------------------------------------------------

    // 3. join — local: combine two wrapper Token records.
    fn join(r1: Token, r2: Token) -> Token {
        assert_eq(r1.token_id, r2.token_id);
        return Token { owner: r1.owner, amount: r1.amount + r2.amount, token_id: r1.token_id };
    }

    // 4. split — local: split one wrapper Token record into two.
    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount, token_id: input.token_id };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (first, second);
    }

    // 5. transfer_public_to_private — vault-in.
    //    Moves amount from user's public registry balance into the wrapper's vault
    //    (via self.signer), then creates a wrapper Token record for recipient.
    fn transfer_public_to_private(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: token_id };
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, self.address, amount);
        return (token, final { f.run(); });
    }

    // 6. transfer_private_to_public — vault-out.
    //    Consumes wrapper Token record and releases amount from wrapper's vault
    //    to recipient's public registry balance.
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        let f: Final = token_registry.aleo/transfer_public(input.token_id, recipient, amount);
        return (change, final { f.run(); });
    }

    // 7. transfer_private — local: move amount between wrapper Token records.
    fn transfer_private(
        recipient: address,
        amount: u128,
        input: Token
    ) -> (Token, Token, Final) {
        let transfer_record: Token = Token { owner: recipient, amount: amount, token_id: input.token_id };
        let change_record: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (transfer_record, change_record, final { assert(true); });
    }

    // 9. mint_private — vault-in mint.
    //    Mints tokens to the wrapper's registry address (increasing vault balance),
    //    then creates a private wrapper Token record for the recipient.
    //    Caller must hold MINTER_ROLE on token_registry for HARDCODED_TOKEN_ID.
    fn mint_private(
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: HARDCODED_TOKEN_ID };
        // Mint to self.address to maintain vault invariant:
        //   wrapper's registry balance += amount
        let f: Final = token_registry.aleo/mint_public(HARDCODED_TOKEN_ID, self.address, amount, 0u32);
        return (token, final { f.run(); });
    }

}
