import token_registry.aleo;

struct TokenInfo {
    name: u128,
    symbol: u128,
    decimals: u8,
    supply: u128,
    max_supply: u128,
}

struct TokenAllowance {
    account: address,
    spender: address,
}

interface ARC20 {
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn shield(public amount: u128) -> (token_registry.aleo/Token, Final);
    fn unshield(input: token_registry.aleo/Token, amount: u128) -> (
        token_registry.aleo/Token,
        token_registry.aleo/Token,
        Final,
    );
    fn transfer_private(input: token_registry.aleo/Token, to: address, amount: u128) -> (
        token_registry.aleo/Token,
        token_registry.aleo/Token,
    );
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
}

// Custom token ID wrapped by this program (distinct from CREDITS_RESERVED_TOKEN_ID)
const WRAPPED_TOKEN_ID: field = 99999field;

program wrapped_token_registry.aleo: ARC20 {
    @noupgrade
    constructor() {}

    mapping balances: address => u128;
    mapping token_info: bool => TokenInfo;
    mapping allowances: field => u128;

    fn deposit_token_public(public amount: u128) -> Final {
        let tr_final = token_registry.aleo/transfer_public_as_signer(
            WRAPPED_TOKEN_ID,
            self.address,
            amount,
        );
        let depositor = self.signer;
        return final {
            tr_final.run();
            let prev = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, prev + amount);
        };
    }

    fn deposit_token_private(
        input: token_registry.aleo/Token,
        amount: u128,
    ) -> (token_registry.aleo/Token, Final) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        assert(input.amount >= amount);
        let (change_token, _) = token_registry.aleo/transfer_private(input, self.address, amount);
        let depositor = self.signer;
        return (
            change_token,
            final {
                let prev = balances.get_or_use(depositor, 0u128);
                balances.set(depositor, prev + amount);
            },
        );
    }

    fn withdraw_token_public(amount: u128) -> Final {
        let withdrawer = self.caller;
        let tr_final = token_registry.aleo/transfer_public(WRAPPED_TOKEN_ID, withdrawer, amount);
        return final {
            let prev = balances.get(withdrawer);
            balances.set(withdrawer, prev - amount);
            tr_final.run();
        };
    }

    fn withdraw_token_public_signer(amount: u128) -> Final {
        let withdrawer = self.signer;
        let tr_final = token_registry.aleo/transfer_public(WRAPPED_TOKEN_ID, withdrawer, amount);
        return final {
            let prev = balances.get(withdrawer);
            balances.set(withdrawer, prev - amount);
            tr_final.run();
        };
    }

    fn withdraw_token_private(amount: u128) -> (token_registry.aleo/Token, Final) {
        let withdrawer = self.signer;
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(
            WRAPPED_TOKEN_ID,
            withdrawer,
            amount,
            false,
        );
        return (
            token_out,
            final {
                let prev = balances.get(withdrawer);
                balances.set(withdrawer, prev - amount);
                tr_final.run();
            },
        );
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let prev_caller = balances.get(caller);
            balances.set(caller, prev_caller - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }

    fn shield(public amount: u128) -> (token_registry.aleo/Token, Final) {
        let caller = self.caller;
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(
            WRAPPED_TOKEN_ID,
            caller,
            amount,
            false,
        );
        return (
            token_out,
            final {
                let prev = balances.get(caller);
                balances.set(caller, prev - amount);
                tr_final.run();
            },
        );
    }

    fn unshield(
        input: token_registry.aleo/Token,
        amount: u128,
    ) -> (token_registry.aleo/Token, token_registry.aleo/Token, Final) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        assert(input.amount >= amount);
        let (change_token, transfer_token) = token_registry.aleo/transfer_private(
            input,
            input.owner,
            amount,
        );
        return (change_token, transfer_token, final {});
    }

    fn transfer_private(
        input: token_registry.aleo/Token,
        to: address,
        amount: u128,
    ) -> (token_registry.aleo/Token, token_registry.aleo/Token) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        let result = token_registry.aleo/transfer_private(input, to, amount);
        return result;
    }

    fn approve_public(public spender: address, public amount: u128) -> Final {
        let allowance_key = BHP256::hash_to_field(
            TokenAllowance { account: self.caller, spender: spender },
        );
        return final {
            let current = allowances.get_or_use(allowance_key, 0u128);
            allowances.set(allowance_key, current + amount);
        };
    }

    fn unapprove_public(public spender: address, public amount: u128) -> Final {
        let allowance_key = BHP256::hash_to_field(
            TokenAllowance { account: self.caller, spender: spender },
        );
        return final {
            let current = allowances.get(allowance_key);
            allowances.set(allowance_key, current - amount);
        };
    }

    fn transfer_from_public(
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let allowance_key = BHP256::hash_to_field(
            TokenAllowance { account: owner, spender: self.caller },
        );
        return final {
            let current = allowances.get(allowance_key);
            allowances.set(allowance_key, current - amount);
            let prev_owner = balances.get(owner);
            balances.set(owner, prev_owner - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }
}
