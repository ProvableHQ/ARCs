// registry_wrapper.aleo — ARC-0020 wrapper for token_registry.aleo. Implements ARC20.
//
// Three-layer architecture:
//   Layer 1 (Bridge):   deposit / withdraw  — moves tokens between user's registry account and vault
//   Layer 2 (Public):   transfer_public / transfer_public_as_signer — internal balances mapping, no underlying call
//   Layer 3 (Private):  shield / unshield / join / split / transfer_private — Token records
//
// Supports multiple tokens: token_id is passed to deposit/withdraw and stored on Token records.
// join asserts both records share the same token_id.
// Balances keyed by BHP256::hash_to_field(BalanceKey { account, token_id }) to support multi-token.
// Vault invariant: wrapper's registry balance per token_id = sum(matching balances entries) + sum(outstanding Token amounts).

import token_registry.aleo;
import token_interface.aleo;

program registry_wrapper.aleo : token_interface.aleo/ARC20 + token_interface.aleo/Bridge {

    @noupgrade
    constructor() {}

    // Composite key for the multi-token balances mapping.
    struct BalanceKey {
        account: address,
        token_id: field,
    }

    record Token {
        owner: address,
        amount: u128,
        token_id: field,
    }

    // Internal public balance ledger keyed by BHP256::hash_to_field(BalanceKey).
    mapping balances: field => u128;

    // Moves user's registry public balance into the wrapper vault and credits balances[hash(signer, token_id)].
    fn deposit(public token_id: field, public amount: u128) -> Final {
        let signer: address = self.signer;
        let key: field = BHP256::hash_to_field(BalanceKey { account: signer, token_id: token_id });
        let f: Final = token_registry.aleo/transfer_public_as_signer(token_id, self.address, amount);
        return final {
            f.run();
            let current: u128 = balances.get_or_use(key, 0u128);
            balances.set(key, current + amount);
        };
    }

    // Withdraws from balances[hash(caller, token_id)] and sends tokens from the vault to caller.
    fn withdraw(public token_id: field, public amount: u128) -> Final {
        let caller: address = self.caller;
        let key: field = BHP256::hash_to_field(BalanceKey { account: caller, token_id: token_id });
        let f: Final = token_registry.aleo/transfer_public(token_id, caller, amount);
        return final {
            f.run();
            let current: u128 = balances.get(key);
            balances.set(key, current - amount);
        };
    }

    // Withdraws from balances[hash(signer, token_id)] and sends tokens from the vault to signer.
    // Use when calling through a dispatcher (self.caller = dispatcher, not user).
    fn withdraw_as_signer(public token_id: field, public amount: u128) -> Final {
        let signer: address = self.signer;
        let key: field = BHP256::hash_to_field(BalanceKey { account: signer, token_id: token_id });
        let f: Final = token_registry.aleo/transfer_public(token_id, signer, amount);
        return final {
            f.run();
            let current: u128 = balances.get(key);
            balances.set(key, current - amount);
        };
    }

    // Pure internal transfer — debits balances[hash(caller, token_id)], credits balances[hash(recipient, token_id)].
    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let caller: address = self.caller;
        let sender_key: field = BHP256::hash_to_field(BalanceKey { account: caller, token_id: token_id });
        let recipient_key: field = BHP256::hash_to_field(BalanceKey { account: recipient, token_id: token_id });
        return final {
            let sender_bal: u128 = balances.get(sender_key);
            balances.set(sender_key, sender_bal - amount);
            let recipient_bal: u128 = balances.get_or_use(recipient_key, 0u128);
            balances.set(recipient_key, recipient_bal + amount);
        };
    }

    // Pure internal transfer — debits balances[hash(signer, token_id)], credits balances[hash(recipient, token_id)].
    fn transfer_public_as_signer(
        public token_id: field,
        public recipient: address,
        public amount: u128
    ) -> Final {
        let signer: address = self.signer;
        let sender_key: field = BHP256::hash_to_field(BalanceKey { account: signer, token_id: token_id });
        let recipient_key: field = BHP256::hash_to_field(BalanceKey { account: recipient, token_id: token_id });
        return final {
            let sender_bal: u128 = balances.get(sender_key);
            balances.set(sender_key, sender_bal - amount);
            let recipient_bal: u128 = balances.get_or_use(recipient_key, 0u128);
            balances.set(recipient_key, recipient_bal + amount);
        };
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

    // Debits balances[hash(signer, token_id)] and creates a Token record — no underlying call.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let signer: address = self.signer;
        let key: field = BHP256::hash_to_field(BalanceKey { account: signer, token_id: token_id });
        let token: Token = Token { owner: recipient, amount: amount, token_id: token_id };
        return (token, final {
            let current: u128 = balances.get(key);
            balances.set(key, current - amount);
        });
    }

    // Consumes Token record, credits balances[hash(recipient, token_id)] — no underlying call.
    fn unshield(
        public recipient: address,
        public amount: u128,
        input: Token
    ) -> (Token, Final) {
        let key: field = BHP256::hash_to_field(BalanceKey { account: recipient, token_id: input.token_id });
        let change: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (change, final {
            let current: u128 = balances.get_or_use(key, 0u128);
            balances.set(key, current + amount);
        });
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
