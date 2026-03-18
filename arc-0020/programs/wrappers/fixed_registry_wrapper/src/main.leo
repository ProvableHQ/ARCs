// fixed_registry_wrapper.aleo — ARC-0020 single-token registry wrapper.
// Implements ARC20 + MintPublic + MintPrivate. Hardcodes one token_id at deploy time.
//
// Three-layer architecture:
//   Layer 1 (Bridge):   deposit / withdraw  — moves tokens between user's registry account and vault
//   Layer 2 (Public):   transfer_public / transfer_public_as_signer — internal balances mapping, no underlying call
//   Layer 3 (Private):  shield / unshield / join / split / transfer_private — Token records
//
// Use case: token issuer deploys one instance per token (e.g. USDC, WBTC).
// Deployer must hold MINTER_ROLE on token_registry for HARDCODED_TOKEN_ID.
// mint_public mints directly to recipient (no vault involvement).
// mint_private mints to vault (self.address) and issues a Token record to recipient directly.
// Vault invariant: wrapper's registry balance for HARDCODED_TOKEN_ID = sum(balances entries) + sum(outstanding Token amounts).

import token_registry.aleo;
import token_interface.aleo;

program fixed_registry_wrapper.aleo : token_interface.aleo/ARC20 + token_interface.aleo/MintPublic + token_interface.aleo/MintPrivate + token_interface.aleo/Bridge {

    @noupgrade
    constructor() {}

    // Replace with the actual registered token_id at deploy time.
    const HARDCODED_TOKEN_ID: field = 1field;

    // token_id stored for AVM type identity; always equals HARDCODED_TOKEN_ID.
    record Token {
        owner: address,
        amount: u128,
        token_id: field,
    }

    // Internal public balance ledger. Funded via deposit, drained via withdraw.
    mapping balances: address => u128;

    // Moves user's registry public balance into the wrapper vault and credits balances[signer].
    // token_id is ignored (single-token, uses HARDCODED_TOKEN_ID); present for dispatcher uniformity.
    fn deposit(public token_id: field, public amount: u128) -> Final {
        let signer: address = self.signer;
        let f: Final = token_registry.aleo/transfer_public_as_signer(HARDCODED_TOKEN_ID, self.address, amount);
        return final {
            f.run();
            let current: u128 = balances.get_or_use(signer, 0u128);
            balances.set(signer, current + amount);
        };
    }

    // Withdraws from balances[caller] and sends tokens from the vault to caller.
    // token_id is ignored (single-token, uses HARDCODED_TOKEN_ID); present for dispatcher uniformity.
    fn withdraw(public token_id: field, public amount: u128) -> Final {
        let caller: address = self.caller;
        let f: Final = token_registry.aleo/transfer_public(HARDCODED_TOKEN_ID, caller, amount);
        return final {
            f.run();
            let current: u128 = balances.get(caller);
            balances.set(caller, current - amount);
        };
    }

    // Withdraws from balances[signer] and sends tokens from the vault to signer.
    // Use when calling through a dispatcher (self.caller = dispatcher, not user).
    // token_id is ignored (single-token, uses HARDCODED_TOKEN_ID); present for dispatcher uniformity.
    fn withdraw_as_signer(public token_id: field, public amount: u128) -> Final {
        let signer: address = self.signer;
        let f: Final = token_registry.aleo/transfer_public(HARDCODED_TOKEN_ID, signer, amount);
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

    // authorized_until = 0u32: no external authorization required. Mints directly to recipient.
    // token_id is ignored (single-token, uses HARDCODED_TOKEN_ID); present for dispatcher uniformity.
    fn mint_public(
        public token_id: field,
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

    // Debits balances[signer] and creates a Token record — no underlying call.
    fn shield(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let signer: address = self.signer;
        let token: Token = Token { owner: recipient, amount: amount, token_id: HARDCODED_TOKEN_ID };
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
        let change: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
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
        let transfer_record: Token = Token { owner: recipient, amount: amount, token_id: input.token_id };
        let change_record: Token = Token { owner: input.owner, amount: input.amount - amount, token_id: input.token_id };
        return (transfer_record, change_record, final { assert(true); });
    }

    // Mints to vault (self.address) and issues a Token record to recipient.
    // No balances mapping change: minted tokens go straight to private record, vault balance covers it.
    // token_id is ignored (single-token, uses HARDCODED_TOKEN_ID); present for dispatcher uniformity.
    fn mint_private(
        public token_id: field,
        recipient: address,
        public amount: u128
    ) -> (Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount, token_id: HARDCODED_TOKEN_ID };
        let f: Final = token_registry.aleo/mint_public(HARDCODED_TOKEN_ID, self.address, amount, 0u32);
        return (token, final { f.run(); });
    }

}
