// stablecoin_wrapper.aleo — ARC-0020 wrapper for stablecoin_program.aleo. Implements ARC20.
//
// Three-layer architecture:
//   Layer 1 (Bridge):   deposit / withdraw  — moves stablecoins between user's stablecoin account and vault.
//                       stablecoin_program freeze/pause checks enforced here. ComplianceRecords emitted here.
//   Layer 2 (Public):   transfer_public / transfer_public_as_signer — internal balances mapping, no underlying call
//   Layer 3 (Private):  shield / unshield / join / split / transfer_private — Token records, same shape as ARC20
//
// token_id is ignored (single-token program).
// Vault invariant: wrapper's stablecoin balance = sum(balances entries) + sum(outstanding Token amounts).

import stablecoin_program.aleo;
import token_interface.aleo;

program stablecoin_wrapper.aleo : token_interface.aleo/ARC20 {

    // Must match stablecoin_program.aleo/INVESTIGATOR_ADDRESS.
    const INVESTIGATOR_ADDRESS: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    record Token {
        owner: address,
        amount: u128,
    }

    // Audit trail emitted at the deposit/withdraw boundary.
    record ComplianceRecord {
        owner: address,
        sender: address,
        recipient: address,
        amount: u128,
    }

    // Internal public balance ledger. Funded via deposit, drained via withdraw.
    mapping balances: address => u128;

    // Moves user's stablecoin public balance into the wrapper vault and credits balances[signer].
    // stablecoin_program checks: signer not frozen, vault not frozen, not paused.
    // Emits ComplianceRecord to INVESTIGATOR_ADDRESS recording the deposit.
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn deposit(public token_id: field, public amount: u128) -> (ComplianceRecord, Final) {
        let signer: address = self.signer;
        let vault: address = self.address;
        let cr: ComplianceRecord = ComplianceRecord { owner: INVESTIGATOR_ADDRESS, sender: signer, recipient: vault, amount: amount };
        let f: Final = stablecoin_program.aleo/transfer_public_as_signer(vault, amount);
        return (cr, final {
            f.run();
            let current: u128 = balances.get_or_use(signer, 0u128);
            balances.set(signer, current + amount);
        });
    }

    // Withdraws from balances[caller] and sends stablecoins from the vault to caller.
    // stablecoin_program checks: vault not frozen, caller not frozen, not paused.
    // Emits ComplianceRecord to INVESTIGATOR_ADDRESS recording the withdrawal.
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn withdraw(public token_id: field, public amount: u128) -> (ComplianceRecord, Final) {
        let caller: address = self.caller;
        let vault: address = self.address;
        let cr: ComplianceRecord = ComplianceRecord { owner: INVESTIGATOR_ADDRESS, sender: vault, recipient: caller, amount: amount };
        let f: Final = stablecoin_program.aleo/transfer_public(caller, amount);
        return (cr, final {
            f.run();
            let current: u128 = balances.get(caller);
            balances.set(caller, current - amount);
        });
    }

    // Withdraws from balances[signer] and sends stablecoins from the vault to signer.
    // Use when calling through a dispatcher (self.caller = dispatcher, not user).
    // Emits ComplianceRecord to INVESTIGATOR_ADDRESS recording the withdrawal.
    // token_id is ignored (single-token program); present for dispatcher uniformity.
    fn withdraw_as_signer(public token_id: field, public amount: u128) -> (ComplianceRecord, Final) {
        let signer: address = self.signer;
        let vault: address = self.address;
        let cr: ComplianceRecord = ComplianceRecord { owner: INVESTIGATOR_ADDRESS, sender: vault, recipient: signer, amount: amount };
        let f: Final = stablecoin_program.aleo/transfer_public(signer, amount);
        return (cr, final {
            f.run();
            let current: u128 = balances.get(signer);
            balances.set(signer, current - amount);
        });
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

    // Debits balances[signer] and creates a Token record — no underlying call. Same shape as ARC20.
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

    // Consumes Token record, credits balances[recipient] — no underlying call. Same shape as ARC20.
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
