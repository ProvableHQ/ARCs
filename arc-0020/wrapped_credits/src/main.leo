import credits.aleo;

// Public state describing the wrapped token.
struct TokenInfo {
    name: u128,
    symbol: u128,
    decimals: u8,
    supply: u128,
    max_supply: u128,
}

// Allowance key.
struct TokenAllowance {
    account: address,
    spender: address,
}

interface IARC20 {
    record Token {
        owner: address,
        amount: u128,
        ..
    }
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(
        public owner: address,
        recipient: address,
        public amount: u128,
    ) -> (Token, Final);
    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, recipient: address, amount: u128) -> (Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);
    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}

interface IARC20Mintable: IARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public owner: address, public amount: u128) -> Final;
    fn burn_private(input: Token, public amount: u128) -> (Token, Final);
}

fn default_token_info() -> TokenInfo {
    return TokenInfo {
        name: 138438205403108515442419u128,
        symbol: 580610435347u128,
        decimals: 6u8,
        supply: 0u128,
        max_supply: 18000000000000000u128,
    };
}

final fn add_supply(amount: u128) {
    let info = token_info.unwrap_or(default_token_info());
    let new_supply = info.supply + amount;
    assert(new_supply <= info.max_supply);
    token_info = TokenInfo {
        name: info.name,
        symbol: info.symbol,
        decimals: info.decimals,
        supply: new_supply,
        max_supply: info.max_supply,
    };
}

final fn sub_supply(amount: u128) {
    let info = token_info.unwrap_or(default_token_info());
    token_info = TokenInfo {
        name: info.name,
        symbol: info.symbol,
        decimals: info.decimals,
        supply: info.supply - amount,
        max_supply: info.max_supply,
    };
}

program wrapped_credits.aleo: IARC20Mintable {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
    }

    mapping balances: address => u128;
    mapping allowances: TokenAllowance => u128;
    storage token_info: TokenInfo;

    // ----------------------------------------------------------------------
    // READ-ONLY ACCESSORS (`view fn`)
    // ----------------------------------------------------------------------
    view fn balance_of(account: address) -> u128 {
        return balances.get_or_use(account, 0u128);
    }

    view fn allowance(owner: address, spender: address) -> u128 {
        let key = TokenAllowance { account: owner, spender: spender };
        return allowances.get_or_use(key, 0u128);
    }

    view fn total_supply() -> u128 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.supply;
    }

    view fn max_supply() -> u128 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.max_supply;
    }

    view fn decimals() -> u8 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.decimals;
    }

    view fn name() -> identifier {
        let touch: TokenInfo = token_info.unwrap_or(default_token_info());
        return 'wCredits';
    }

    view fn symbol() -> identifier {
        let touch: TokenInfo = token_info.unwrap_or(default_token_info());
        return 'wCRD';
    }

    // ----------------------------------------------------------------------
    // Wrapper-specific deposit / withdraw helpers (not part of ARC20)
    // ----------------------------------------------------------------------
    fn deposit_credits_public(public amount: u64) -> Final {
        let credits_finalization = credits.aleo::transfer_public_as_signer(self.address, amount);
        let depositor = self.signer;
        return final {
            credits_finalization.run();
            let previous_balance = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, previous_balance + amount as u128);
            add_supply(amount as u128);
        };
    }

    fn deposit_credits_private(
        input_record: credits.aleo::credits,
        public amount: u64,
    ) -> (credits.aleo::credits, Token, Final) {
        let (change, credits_finalization) = credits.aleo::transfer_private_to_public(
            input_record,
            self.address,
            amount,
        );
        let mint_output = Token { owner: self.signer, amount: amount as u128 };
        return (
            change, mint_output,
            final {
                credits_finalization.run();
                add_supply(amount as u128);
            },
        );
    }

    fn withdraw_credits_public(public amount: u64) -> Final {
        let credits_finalization = credits.aleo::transfer_public(self.caller, amount);
        let withdrawer = self.caller;
        return final {
            let previous_balance = balances.get(withdrawer);
            balances.set(withdrawer, previous_balance - amount as u128);
            sub_supply(amount as u128);
            credits_finalization.run();
        };
    }

    fn withdraw_credits_public_signer(public amount: u64) -> Final {
        let credits_finalization = credits.aleo::transfer_public(self.signer, amount);
        let withdrawer = self.signer;
        return final {
            let previous_balance = balances.get(withdrawer);
            balances.set(withdrawer, previous_balance - amount as u128);
            sub_supply(amount as u128);
            credits_finalization.run();
        };
    }

    fn withdraw_credits_private(
        input_token: Token,
        public amount: u64,
    ) -> (credits.aleo::credits, Token, Final) {
        let (output, credits_finalization) = credits.aleo::transfer_public_to_private(
            input_token.owner,
            amount,
        );
        let change_token = Token {
            owner: input_token.owner,
            amount: input_token.amount - amount as u128,
        };
        return (
            output, change_token,
            final {
                credits_finalization.run();
                sub_supply(amount as u128);
            },
        );
    }

    // ----------------------------------------------------------------------
    // ARC20: transfers
    // ----------------------------------------------------------------------
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let previous_balance_caller = balances.get(caller);
            balances.set(caller, previous_balance_caller - amount);
            let previous_balance_receiver = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, previous_balance_receiver + amount);
        };
    }

    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let signer = self.signer;
        return final {
            let previous_balance_signer = balances.get(signer);
            balances.set(signer, previous_balance_signer - amount);
            let previous_balance_receiver = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, previous_balance_receiver + amount);
        };
    }

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final) {
        let token = Token { owner: recipient, amount };
        let caller = self.caller;
        return (
            token,
            final {
                let previous_balance = balances.get(caller);
                balances.set(caller, previous_balance - amount);
            },
        );
    }

    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token) {
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        let new_token = Token { owner: recipient, amount };
        return (change_token, new_token);
    }

    fn transfer_private_to_public(
        input: Token,
        recipient: address,
        amount: u128,
    ) -> (Token, Final) {
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change_token,
            final {
                let previous_balance_receiver = balances.get_or_use(recipient, 0u128);
                balances.set(recipient, previous_balance_receiver + amount);
            },
        );
    }

    // ----------------------------------------------------------------------
    // ARC20: approvals + transfer_from
    // ----------------------------------------------------------------------
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
            allowances.set(key, current - amount);
            let prev_owner = balances.get(owner);
            balances.set(owner, prev_owner - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }

    fn transfer_from_public_to_private(
        public owner: address,
        private recipient: address,
        public amount: u128,
    ) -> (Token, Final) {
        let spender = self.caller;
        let key = TokenAllowance { account: owner, spender: spender };
        let token = Token { owner: recipient, amount };
        return (
            token,
            final {
                let current = allowances.get(key);
                allowances.set(key, current - amount);
                let prev_owner = balances.get(owner);
                balances.set(owner, prev_owner - amount);
            },
        );
    }

    // ----------------------------------------------------------------------
    // ARC20: join / split
    // ----------------------------------------------------------------------
    fn join(input_1: Token, input_2: Token) -> Token {
        assert_eq(input_1.owner, input_2.owner);
        return Token { owner: input_1.owner, amount: input_1.amount + input_2.amount };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first = Token { owner: input.owner, amount: amount };
        let second = Token { owner: input.owner, amount: input.amount - amount };
        return (first, second);
    }

    // ----------------------------------------------------------------------
    // mint / burn functionality
    // ----------------------------------------------------------------------
    fn mint_public(public recipient: address, public amount: u128) -> Final {
        return final {
            let previous_balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, previous_balance + amount);
            add_supply(amount);
        };
    }

    fn mint_private(recipient: address, public amount: u128) -> (Token, Final) {
        let token = Token { owner: recipient, amount };
        return (
            token,
            final {
                add_supply(amount);
            },
        );
    }

    fn burn_public(public owner: address, public amount: u128) -> Final {
        return final {
            let previous_balance = balances.get(owner);
            balances.set(owner, previous_balance - amount);
            sub_supply(amount);
        };
    }

    fn burn_private(input: Token, public amount: u128) -> (Token, Final) {
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change_token,
            final {
                sub_supply(amount);
            },
        );
    }
}
