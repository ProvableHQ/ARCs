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
    fn transfer_private_to_public(input: Token, public recipient: address, public amount: u128) -> (Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);
    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}

const WRAPPED_TOKEN_ID: field = 99999field;

fn default_token_info() -> TokenInfo {
    return TokenInfo {
        name: 18019742092562515u128, // "wTokReg"
        symbol: 4933470u128, // "wTR"
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

program wrapped_token_registry.aleo: IARC20 {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
    }

    mapping balances: address => u128;
    mapping allowances: TokenAllowance => u128;
    storage token_info: TokenInfo;

    view fn balance_of(account: address) -> u128 {
        return balances.get_or_use(account, 0u128);
    }

    view fn allowance(owner: address, spender: address) -> u128 {
        let key = TokenAllowance { account: owner, spender: spender };
        return allowances.get_or_use(key, 0u128);
    }

    view fn supply() -> u128 {
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
        return 'wTokReg';
    }

    view fn symbol() -> identifier {
        let touch: TokenInfo = token_info.unwrap_or(default_token_info());
        return 'wTR';
    }

    // ----------------------------------------------------------------------
    // Wrapper-specific deposit / withdraw helpers (not part of IARC20)
    // ----------------------------------------------------------------------
    fn deposit_token_public_signer(public amount: u128) -> Final {
        let depositor = self.signer;
        let tr_final = token_registry.aleo::transfer_public_as_signer(
            WRAPPED_TOKEN_ID,
            self.address,
            amount,
        );
        return final {
            let prev = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, prev + amount);
            add_supply(amount);
            tr_final.run();
        };
    }

    fn withdraw_token_public(public amount: u128) -> Final {
        let withdrawer = self.caller;
        let tr_final = token_registry.aleo::transfer_public(WRAPPED_TOKEN_ID, withdrawer, amount);
        return final {
            let prev = balances.get(withdrawer);
            balances.set(withdrawer, prev - amount);
            sub_supply(amount);
            tr_final.run();
        };
    }

    fn withdraw_token_public_signer(public amount: u128) -> Final {
        let withdrawer = self.signer;
        let tr_final = token_registry.aleo::transfer_public(WRAPPED_TOKEN_ID, withdrawer, amount);
        return final {
            let prev = balances.get(withdrawer);
            balances.set(withdrawer, prev - amount);
            sub_supply(amount);
            tr_final.run();
        };
    }

    fn withdraw_token_private(public amount: u128) -> (token_registry.aleo::Token, Final) {
        let withdrawer = self.signer;
        let (token_out, tr_final) = token_registry.aleo::transfer_public_to_private(
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
                sub_supply(amount);
                tr_final.run();
            },
        );
    }

    // ----------------------------------------------------------------------
    // Transfers
    // ----------------------------------------------------------------------
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let prev_caller = balances.get(caller);
            balances.set(caller, prev_caller - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }

    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let signer = self.signer;
        return final {
            let prev_signer = balances.get(signer);
            balances.set(signer, prev_signer - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final) {
        let token = Token { owner: recipient, amount };
        let caller = self.caller;
        return (
            token,
            final {
                let prev = balances.get(caller);
                balances.set(caller, prev - amount);
            },
        );
    }

    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token) {
        let change = Token { owner: input.owner, amount: input.amount - amount };
        let transfer = Token { owner: recipient, amount: amount };
        return (change, transfer);
    }

    fn transfer_private_to_public(
        input: Token,
        public recipient: address,
        public amount: u128,
    ) -> (Token, Final) {
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change_token,
            final {
                let prev = balances.get_or_use(recipient, 0u128);
                balances.set(recipient, prev + amount);
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

    fn join(input_1: Token, input_2: Token) -> Token {
        assert_eq(input_1.owner, input_2.owner);
        return Token { owner: input_1.owner, amount: input_1.amount + input_2.amount };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let first = Token { owner: input.owner, amount: amount };
        let second = Token { owner: input.owner, amount: input.amount - amount };
        return (first, second);
    }
}
