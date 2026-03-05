// credits_wrapper.aleo
//
// ARC-0020 unified interface wrapper for credits_clone.aleo.
// Implements token_interface.aleo/ExtendedWrapper (formally: functions 1-2;
// informally: functions 3-7 by convention).
//
// Vault pattern:
//   - Wrapper owns its Token records (credits_clone.aleo/credits are never exposed).
//   - Vault balance: credits_wrapper.aleo's account on credits_clone.aleo equals
//     the sum of all outstanding wrapper Token record amounts.
//   - Vault-in  (transfer_public_to_private): calls credits_clone/transfer_public_as_signer
//       to move user's credits → wrapper's account, then creates a wrapper Token record.
//   - Vault-out (transfer_private_to_public): consumes wrapper Token record, calls
//       credits_clone/transfer_public to move wrapper's credits → recipient's account.
//   - Local ops (join, split, transfer_private): purely local record manipulation,
//       no underlying call; vault balance unchanged.
//
// Type adaptations:
//   - token_id parameter: ignored (credits is a single-token program)
//   - amount: u128 → u64 cast for all credits_clone calls

import credits_clone.aleo;
import token_interface.aleo;

program credits_wrapper.aleo : token_interface.aleo/ExtendedWrapper {

    // Wrapper-owned token record.
    // amount stored as u128 for interface uniformity; cast to u64 for credits_clone calls.
    record Token {
        owner: address,
        amount: u128,
    }

    // ---------------------------------------------------------------------------
    // Formally enforced by token_interface.aleo/ExtendedWrapper
    // ---------------------------------------------------------------------------

    // 1. transfer_public — debits self.caller on credits_clone.
    //    Usage: when the WRAPPER itself holds public credits and transfers them out.
    //    (In the vault context, self.caller = wrapper = vault holder.)
    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let amt: u64 = amount as u64;
        let f: Final = credits_clone.aleo/transfer_public(recipient, amt);
        return final { f.run(); };
    }

    // 2. transfer_public_as_signer — debits self.signer (original tx signer).
    //    Usage: when the USER holds public credits and transfers them directly.
    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let amt: u64 = amount as u64;
        let f: Final = credits_clone.aleo/transfer_public_as_signer(recipient, amt);
        return final { f.run(); };
    }

    // ---------------------------------------------------------------------------
    // Informally conformant (record-based; not cross-program interface-enforced)
    // ---------------------------------------------------------------------------

    // 3. join — local: combine two wrapper Token records into one.
    //    No underlying call; vault balance unchanged.
    fn join(r1: Token, r2: Token) -> Token {
        return Token { owner: r1.owner, amount: r1.amount + r2.amount };
    }

    // 4. split — local: split one wrapper Token record into two.
    //    No underlying call; vault balance unchanged.
    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (first, second);
    }

    // 5. transfer_public_to_private — vault-in.
    //    Moves amount from user's public credits (via self.signer) into the wrapper's vault,
    //    then creates a wrapper Token record for the intended recipient.
    //    After this call: wrapper's credits balance += amount; new Token record minted.
    fn transfer_public_to_private(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let amt: u64 = amount as u64;
        let token: Token = Token { owner: recipient, amount: amount };
        // self.address is credits_wrapper.aleo — this vaults the user's credits.
        let f: Final = credits_clone.aleo/transfer_public_as_signer(self.address, amt);
        return (token, final { f.run(); });
    }

    // 6. transfer_private_to_public — vault-out.
    //    Consumes a wrapper Token record, then releases the amount from the wrapper's
    //    vault to the recipient's public credits account.
    //    After this call: wrapper's credits balance -= amount; Token record burned.
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        let amt: u64 = amount as u64;
        // self.caller == credits_wrapper.aleo in credits_clone — debits vault balance.
        let f: Final = credits_clone.aleo/transfer_public(recipient, amt);
        return (change, final { f.run(); });
    }

    // 7. transfer_private — local: move amount between wrapper Token records.
    //    No underlying call; vault balance unchanged.
    //    The trivial Final satisfies the interface return type convention.
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
