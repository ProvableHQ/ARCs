// fixed_registry_wrapper.aleo — ARC-0020 single-token registry wrapper.
// Implements ARC20 + MintPublic + MintPrivate. Hardcodes one token_id at deploy time.
//
// Use case: token issuer deploys one instance per token (e.g. USDC, WBTC).
// Deployer must hold MINTER_ROLE on token_registry for HARDCODED_TOKEN_ID.
// mint_public mints directly to recipient (no vault); mint_private vaults to self.address.
// Vault invariant: wrapper's registry balance for HARDCODED_TOKEN_ID = sum of outstanding Token amounts.

import token_registry.aleo;
import token_interface.aleo;

program fixed_registry_wrapper.aleo : token_interface.aleo/ARC20 + token_interface.aleo/MintPublic + token_interface.aleo/MintPrivate {

    // Replace with the actual registered token_id at deploy time.
    const HARDCODED_TOKEN_ID: field = 1field;

    // token_id stored for AVM type identity; always equals HARDCODED_TOKEN_ID.
    record Token {
        owner: address,
        amount: u128,
        token_id: field,
    }

    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/transfer_public(token_id, recipient, amount);
        return final { f.run(); };
    }

    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, recipient, amount);
        return final { f.run(); };
    }

    // authorized_until = 0u32: no external authorization required.
    fn mint_public(
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = token_registry.aleo/mint_public(HARDCODED_TOKEN_ID, recipient, amount, 0u32);
        return final { f.run(); };
    }

    fn join(r1: Token, r2: Token) -> Token {
        assert_eq(r1.token_id, r2.token_id);
        return Token { owner: r1.owner, amount: r1.amount + r2.amount, token_id: r1.token_id };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount, token_id: input.token_id };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (first, second);
    }

    // vault-in: moves user's public registry tokens into the wrapper (self.address), creates Token record.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: token_id };
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, self.address, amount);
        return (token, final { f.run(); });
    }

    // vault-out: consumes Token record, releases wrapper's registry tokens to recipient.
    fn unshield(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        let f: Final = token_registry.aleo/transfer_public(input.token_id, recipient, amount);
        return (change, final { f.run(); });
    }

    fn transfer_private(
        recipient: address,
        amount: u128,
        input: Token
    ) -> (Token, Token, Final) {
        let transfer_record: Token = Token { owner: recipient, amount: amount, token_id: input.token_id };
        let change_record: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (transfer_record, change_record, final { assert(true); });
    }

    // vault-in mint: mints to self.address to maintain vault invariant, creates Token record for recipient.
    fn mint_private(
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: HARDCODED_TOKEN_ID };
        let f: Final = token_registry.aleo/mint_public(HARDCODED_TOKEN_ID, self.address, amount, 0u32);
        return (token, final { f.run(); });
    }

}
