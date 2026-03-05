// registry_wrapper.aleo — ARC-0020 wrapper for token_registry.aleo. Implements ARC20.
//
// Supports multiple tokens: token_id is passed through to all underlying calls and stored
// on Token records. join asserts both records share the same token_id.
// Vault invariant: wrapper's registry balance per token_id = sum of outstanding Token amounts.

import credits_clone.aleo;
import token_registry.aleo;
import token_interface.aleo;

program registry_wrapper.aleo : token_interface.aleo/ARC20 {

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

}
