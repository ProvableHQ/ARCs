// registry_wrapper.aleo
//
// ARC-0020 unified interface wrapper for token_registry.aleo.
// Implements token_interface.aleo/ExtendedWrapper (formally: functions 1-2;
// informally: functions 3-7 by convention).
//
// Vault pattern:
//   - Wrapper owns its Token records (token_registry.aleo/Token never exposed).
//   - Vault balance: registry_wrapper.aleo's account on token_registry.aleo (per token_id)
//     equals the sum of all outstanding wrapper Token record amounts for that token_id.
//   - Vault-in  (transfer_public_to_private): calls token_registry/transfer_public_as_signer
//       to move user's registry tokens → wrapper's account, then creates a wrapper Token record.
//   - Vault-out (transfer_private_to_public): consumes wrapper Token record, calls
//       token_registry/transfer_public to move wrapper's tokens → recipient's account.
//   - Local ops (join, split, transfer_private): purely local record manipulation,
//       no underlying call; vault balance unchanged.
//
// Multi-token handling:
//   - token_id is passed through to all underlying calls.
//   - Wrapper Token record carries token_id field to track which token each record represents.
//   - join asserts both records share the same token_id before combining.

import credits_clone.aleo;
import token_registry.aleo;
import token_interface.aleo;

program registry_wrapper.aleo : token_interface.aleo/ExtendedWrapper {

    // Wrapper-owned token record.
    // token_id identifies which registered token this record represents.
    record Token {
        owner: address,
        amount: u128,
        token_id: field,
    }

    // ---------------------------------------------------------------------------
    // Formally enforced by token_interface.aleo/ExtendedWrapper
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
    // Informally conformant (record-based; not cross-program interface-enforced)
    // ---------------------------------------------------------------------------

    // 3. join — local: combine two wrapper Token records of the same token_id.
    //    Asserts both records share the same token_id before combining.
    //    No underlying call; vault balance unchanged.
    fn join(r1: Token, r2: Token) -> Token {
        assert_eq(r1.token_id, r2.token_id);
        return Token { owner: r1.owner, amount: r1.amount + r2.amount, token_id: r1.token_id };
    }

    // 4. split — local: split one wrapper Token record into two, preserving token_id.
    //    No underlying call; vault balance unchanged.
    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount, token_id: input.token_id };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (first, second);
    }

    // 5. transfer_public_to_private — vault-in.
    //    Moves amount from user's public registry tokens (via self.signer) into the wrapper's vault,
    //    then creates a wrapper Token record for the intended recipient.
    //    external_authorization_required is hardcoded to false (wrapper manages auth via vault pattern).
    fn transfer_public_to_private(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: token_id };
        // self.address is registry_wrapper.aleo — this vaults the user's registry tokens.
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, self.address, amount);
        return (token, final { f.run(); });
    }

    // 6. transfer_private_to_public — vault-out.
    //    Consumes a wrapper Token record, then releases the amount from the wrapper's
    //    vault to the recipient's public registry token account.
    //    After this call: wrapper's registry balance for input.token_id -= amount.
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        // self.caller == registry_wrapper.aleo in token_registry — debits vault balance.
        let f: Final = token_registry.aleo/transfer_public(input.token_id, recipient, amount);
        return (change, final { f.run(); });
    }

    // 7. transfer_private — local: move amount between wrapper Token records.
    //    token_id is preserved on both output records.
    //    No underlying call; vault balance unchanged.
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
