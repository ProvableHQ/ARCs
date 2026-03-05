// credits_wrapper.aleo — ARC-0020 wrapper for credits_clone.aleo. Implements ARC20.
//
// token_id is ignored (single-token program). amount is cast u128 → u64 for credits_clone calls.
// Vault invariant: wrapper's credits_clone balance = sum of all outstanding Token amounts.

import credits_clone.aleo;
import token_interface.aleo;

program credits_wrapper.aleo : token_interface.aleo/ARC20 {

    // amount stored as u128 for interface uniformity; cast to u64 on every credits_clone call.
    record Token {
        owner: address,
        amount: u128,
    }

    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let amt: u64 = amount as u64;
        let f: Final = credits_clone.aleo/transfer_public(recipient, amt);
        return final { f.run(); };
    }

    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let amt: u64 = amount as u64;
        let f: Final = credits_clone.aleo/transfer_public_as_signer(recipient, amt);
        return final { f.run(); };
    }

    fn join(r1: Token, r2: Token) -> Token {
        return Token { owner: r1.owner, amount: r1.amount + r2.amount };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (first, second);
    }

    // vault-in: moves user's public credits into the wrapper (self.address), creates Token record.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let amt: u64 = amount as u64;
        let token: Token = Token { owner: recipient, amount: amount };
        let f: Final = credits_clone.aleo/transfer_public_as_signer(self.address, amt);
        return (token, final { f.run(); });
    }

    // vault-out: consumes Token record, releases wrapper's credits to recipient.
    fn unshield(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        let amt: u64 = amount as u64;
        let f: Final = credits_clone.aleo/transfer_public(recipient, amt);
        return (change, final { f.run(); });
    }

    fn transfer_private(
        recipient: address,
        amount: u128,
        input: Token
    ) -> (Token, Token, Final) {
        let transfer_record: Token = Token { owner: recipient, amount: amount };
        let change_record: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (transfer_record, change_record, final { assert(true); });
    }

}
