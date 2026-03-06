// credits_wrapper.aleo — ARC-0020 wrapper for credits_clone.aleo. Implements ARC20.
//
// Three-layer architecture:
//   Layer 1 (Bridge):   deposit / withdraw  — moves credits between user's credits_clone account and vault
//   Layer 2 (Public):   transfer_public / transfer_public_as_signer — internal balances mapping, no underlying call
//   Layer 3 (Private):  shield / unshield / join / split / transfer_private — Token records
//
// token_id is ignored (single-token program). amount is cast u128 → u64 for all credits_clone calls.
// Vault invariant: wrapper's credits_clone balance = sum(balances entries) + sum(outstanding Token amounts).

import credits_clone.aleo;
import token_interface.aleo;

program credits_wrapper.aleo : token_interface.aleo/ARC20 + token_interface.aleo/Bridge {

    // amount stored as u128 for interface uniformity; cast to u64 on every credits_clone call.
    record Token {
        owner: address,
        amount: u128,
    }

    // Internal public balance ledger. Funded via deposit, drained via withdraw.
    mapping balances: address => u128;

    // Moves user's credits_clone public balance into the wrapper vault and credits balances[signer].
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn deposit(public token_id: field, public amount: u128) -> Final {
        let amt: u64 = amount as u64;
        let signer: address = self.signer;
        let f: Final = credits_clone.aleo/transfer_public_as_signer(self.address, amt);
        return final {
            f.run();
            let current: u128 = balances.get_or_use(signer, 0u128);
            balances.set(signer, current + amount);
        };
    }

    // Withdraws from balances[caller] and sends credits from the vault to caller.
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn withdraw(public token_id: field, public amount: u128) -> Final {
        let amt: u64 = amount as u64;
        let caller: address = self.caller;
        let f: Final = credits_clone.aleo/transfer_public(caller, amt);
        return final {
            f.run();
            let current: u128 = balances.get(caller);
            balances.set(caller, current - amount);
        };
    }

    // Withdraws from balances[signer] and sends credits from the vault to signer.
    // Use when calling through a dispatcher (self.caller = dispatcher, not user).
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn withdraw_as_signer(public token_id: field, public amount: u128) -> Final {
        let amt: u64 = amount as u64;
        let signer: address = self.signer;
        let f: Final = credits_clone.aleo/transfer_public(signer, amt);
        return final {
            f.run();
            let current: u128 = balances.get(signer);
            balances.set(signer, current - amount);
        };
    }

    // Pure internal transfer — debits balances[caller], credits balances[recipient]. No underlying call.
    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let caller: address = self.caller;
        return final {
            let sender_bal: u128 = balances.get(caller);
            balances.set(caller, sender_bal - amount);
            let recipient_bal: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, recipient_bal + amount);
        };
    }

    // Pure internal transfer — debits balances[signer], credits balances[recipient]. No underlying call.
    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let signer: address = self.signer;
        return final {
            let sender_bal: u128 = balances.get(signer);
            balances.set(signer, sender_bal - amount);
            let recipient_bal: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, recipient_bal + amount);
        };
    }

    fn join(r1: Token, r2: Token) -> Token {
        return Token { owner: r1.owner, amount: r1.amount + r2.amount };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first: Token = Token { owner: input.owner, amount: amount };
        let second: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (first, second);
    }

    // Debits balances[signer] and creates a Token record — no underlying call.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let signer: address = self.signer;
        let token: Token = Token { owner: recipient, amount: amount };
        return (token, final {
            let current: u128 = balances.get(signer);
            balances.set(signer, current - amount);
        });
    }

    // Consumes Token record, credits balances[recipient] — no underlying call.
    fn unshield(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (change, final {
            let current: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, current + amount);
        });
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
