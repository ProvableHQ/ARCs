// stablecoin_wrapper.aleo
//
// ARC-0020 unified interface wrapper for stablecoin_program.aleo.
// Implements token_interface.aleo/ExtendedWrapper — same interface as
// credits_wrapper and registry_wrapper, enabling unified dispatch.
//
// Design: the wrapper is a stateful application vault. It does not add
// compliance or freeze-list checks of its own. When delegating to
// stablecoin_program.aleo, that program's internal checks (freeze list,
// pause state) apply naturally. Local record operations carry no extra checks;
// access control is the responsibility of the application deploying the wrapper.
//
// Vault pattern:
//   - Wrapper owns its Token records (stablecoin_program.aleo/Token never exposed).
//   - Vault balance: stablecoin_wrapper.aleo's account on stablecoin_program equals
//     the sum of all outstanding wrapper Token record amounts.
//   - Vault-in  (transfer_public_to_private): calls stablecoin/transfer_public_as_signer
//       to move user's stablecoins → wrapper's account, then creates a wrapper Token record.
//       (stablecoin internally checks: signer not frozen, wrapper address not frozen, not paused)
//   - Vault-out (transfer_private_to_public): consumes wrapper Token record, calls
//       stablecoin/transfer_public to release wrapper's stablecoins → recipient's account.
//       (stablecoin internally checks: wrapper address not frozen, recipient not frozen, not paused)
//   - Local ops (join, split, transfer_private): purely local record manipulation.
//       Private sender freeze status is not verified — accepted limitation of the standard interface.
//
// Type adaptations:
//   - token_id parameter: ignored (stablecoin is a single-token program)

import stablecoin_program.aleo;
import token_interface.aleo;

program stablecoin_wrapper.aleo : token_interface.aleo/ExtendedWrapper {

    // Wrapper-owned token record.
    record Token {
        owner: address,
        amount: u128,
    }

    // ---------------------------------------------------------------------------
    // Formally enforced by token_interface.aleo/ExtendedWrapper
    // ---------------------------------------------------------------------------

    // 1. transfer_public — debits self.caller on stablecoin_program.
    //    Stablecoin internally checks: caller not frozen, recipient not frozen, not paused.
    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = stablecoin_program.aleo/transfer_public(recipient, amount);
        return final { f.run(); };
    }

    // 2. transfer_public_as_signer — debits self.signer (original tx signer).
    //    Stablecoin internally checks: signer not frozen, recipient not frozen, not paused.
    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let f: Final = stablecoin_program.aleo/transfer_public_as_signer(recipient, amount);
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
    //    Moves amount from user's public stablecoins (via self.signer) into the wrapper's vault,
    //    then creates a wrapper Token record for the intended recipient.
    //    Stablecoin internally checks: signer not frozen, wrapper address not frozen, not paused.
    fn transfer_public_to_private(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount };
        // self.address is stablecoin_wrapper.aleo — this vaults the user's stablecoins.
        let f: Final = stablecoin_program.aleo/transfer_public_as_signer(self.address, amount);
        return (token, final { f.run(); });
    }

    // 6. transfer_private_to_public — vault-out.
    //    Consumes a wrapper Token record, then releases the amount from the wrapper's
    //    vault to the recipient's public stablecoin account.
    //    Stablecoin internally checks: wrapper address not frozen, recipient not frozen, not paused.
    //    Note: private sender (input.owner) freeze status is not verified — accepted limitation.
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        // self.caller == stablecoin_wrapper.aleo in stablecoin_program — debits vault balance.
        let f: Final = stablecoin_program.aleo/transfer_public(recipient, amount);
        return (change, final { f.run(); });
    }

    // 7. transfer_private — local: move amount between wrapper Token records.
    //    No underlying call; vault balance unchanged.
    //    Private sender/recipient freeze status is not verified — accepted limitation.
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
