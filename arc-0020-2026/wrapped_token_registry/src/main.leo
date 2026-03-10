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

// ARC20 interface.
interface ARC20 {
    record Token;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Token, Final);
    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Final);
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public amount: u128) -> (Token, Final);
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
}

// Custom token ID wrapped by this program (distinct from CREDITS_RESERVED_TOKEN_ID)
const WRAPPED_TOKEN_ID: field = 99999field;

program wrapped_token_registry.aleo: ARC20 {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
    }

    mapping balances: address => u128;
    mapping token_info: bool => TokenInfo;
    mapping allowances: TokenAllowance => u128;

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

    // deposit_token_private not possible because token_registry doesn't support transfer_private_to_public

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

    fn shield(public amount: u128) -> (Token, Final) {
        let signer = self.signer;
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(
            WRAPPED_TOKEN_ID,
            signer,
            amount,
            false,
        );
        return (
            Token { owner: token_out.owner, amount: token_out.amount },
            final {
                let prev = balances.get(signer);
                balances.set(signer, prev - amount);
                tr_final.run();
            },
        );
    }

    fn unshield(input: Token, amount: u128) -> (Token, Token, Final) {
        assert(input.amount >= amount);
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        let zero_token = Token { owner: input.owner, amount: 0u128 };
        let owner = input.owner;
        return (
            change_token,
            zero_token,
            final {
                let prev = balances.get_or_use(owner, 0u128);
                balances.set(owner, prev + amount);
            },
        );
    }

    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token) {
        assert(input.owner == self.signer);
        assert(input.amount >= amount);
        let change = Token { owner: input.owner, amount: input.amount - amount };
        let transfer = Token { owner: to, amount: amount };
        return (change, transfer);
    }

    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Final) {
        assert(input.owner == self.signer);
        assert(input.amount >= amount);
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change_token,
            final {
                let prev = balances.get_or_use(to, 0u128);
                balances.set(to, prev + amount);
            },
        );
    }

    fn transfer_from_public_to_private(
        public owner: address,
        public amount: u128,
    ) -> (Token, Final) {
        let spender = self.caller;
        let key = TokenAllowance { account: owner, spender: spender };
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(
            WRAPPED_TOKEN_ID,
            spender,
            amount,
            false,
        );
        return (
            Token { owner: token_out.owner, amount: token_out.amount },
            final {
                let current = allowances.get(key);
                assert(current >= amount);
                allowances.set(key, current - amount);
                let prev_owner = balances.get(owner);
                balances.set(owner, prev_owner - amount);
                tr_final.run();
            },
        );
    }

    fn approve_public(public spender: address, public amount: u128) -> Final {
        let key = TokenAllowance { account: self.caller, spender: spender };
        return final {
            let current = allowances.get_or_use(key, 0u128);
            allowances.set(key, current + amount);
        };
    }

    fn unapprove_public(public spender: address, public amount: u128) -> Final {
        let key = TokenAllowance { account: self.caller, spender: spender };
        return final {
            let current = allowances.get(key);
            assert(current >= amount);
            allowances.set(key, current - amount);
        };
    }

    fn transfer_from_public(
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let key = TokenAllowance { account: owner, spender: self.caller };
        return final {
            let current = allowances.get(key);
            assert(current >= amount);
            allowances.set(key, current - amount);
            let prev_owner = balances.get(owner);
            balances.set(owner, prev_owner - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }
}
