// stablecoin_wrapper.aleo — ARC-0020 wrapper for stablecoin_program.aleo. Implements ARC21.
//
// token_id is ignored (single-token program). stablecoin_program enforces freeze-list and
// pause checks on all underlying calls; local record ops (join, split, transfer_private)
// do not verify private sender freeze status — accepted limitation of the vault model.
// Vault invariant: wrapper's stablecoin balance = sum of all outstanding Token amounts.

import stablecoin_program.aleo;
import token_interface.aleo;

program stablecoin_wrapper.aleo : token_interface.aleo/ARC21 {

    record Token {
        owner: address,
        amount: u128,
    }

    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = stablecoin_program.aleo/transfer_public(recipient, amount);
        return final { f.run(); };
    }

    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = stablecoin_program.aleo/transfer_public_as_signer(recipient, amount);
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

    // vault-in: moves user's public stablecoins into the wrapper (self.address), creates Token record.
    // stablecoin_program checks: signer not frozen, wrapper not frozen, not paused.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount };
        let f: Final = stablecoin_program.aleo/transfer_public_as_signer(self.address, amount);
        return (token, final { f.run(); });
    }

    // vault-out: consumes Token record, releases wrapper's stablecoins to recipient.
    // stablecoin_program checks: wrapper not frozen, recipient not frozen, not paused.
    fn unshield(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        let f: Final = stablecoin_program.aleo/transfer_public(recipient, amount);
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
