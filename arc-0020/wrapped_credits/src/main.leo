import credits.aleo;

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
    record Metadata {
        owner: address,
        sender: address,
        ..
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Metadata, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final);
    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Token, Final);

    // Interoperability
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public amount: u128) -> (Token, Final);
}

// MintableToken extends ARC20 with mint/burn operations.
interface MintableToken: ARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public amount: u128) -> Final;
    fn burn_private(input: Token) -> Final;
}

program wrapped_credits.aleo: MintableToken {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
    }

    record Metadata {
        owner: address,
        sender: address,
    }

    mapping balances: address => u128;
    mapping token_info: bool => TokenInfo;
    mapping allowances: TokenAllowance => u128;

    fn deposit_credits_public(public amount: u64) -> Final {
        let credits_finalization = credits.aleo/transfer_public_as_signer(self.address, amount);
        // Mint wrapped credits to the depositor (the signer), while the underlying
        // Aleo credits are held by this program's address.
        let depositor = self.signer;
        return final {
            credits_finalization.run();
            let previous_balance = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, previous_balance + amount as u128);
        };
    }

    fn deposit_credits_private(
        input_record: credits.aleo/credits,
        amount: u64,
    ) -> (credits.aleo/credits, Token, Final) {
        let (change, credits_finalization) = credits.aleo/transfer_private_to_public(
            input_record,
            self.address,
            amount,
        );
        let mint_output = Token { owner: self.signer, amount: amount as u128 };
        return (change, mint_output, final {
            credits_finalization.run();
        });
    }

    fn withdraw_credits_public(amount: u64) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.caller, amount);
        let withdrawer = self.caller;
        return final {
            let previous_balance = balances.get(withdrawer);
            balances.set(withdrawer, previous_balance - amount as u128);
            credits_finalization.run();
        };
    }

    fn withdraw_credits_public_signer(amount: u64) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.signer, amount);
        let withdrawer = self.signer;
        return final {
            let previous_balance = balances.get(withdrawer);
            balances.set(withdrawer, previous_balance - amount as u128);
            credits_finalization.run();
        };
    }

    fn withdraw_credits_private(
        input_token: Token,
        amount: u64,
    ) -> (credits.aleo/credits, Token, Final) {
        let (output, credits_finalization) = credits.aleo/transfer_public_to_private(
            input_token.owner,
            amount,
        );
        let change_token = Token {
            owner: input_token.owner,
            amount: input_token.amount - amount as u128,
        };
        return (output, change_token, final {
            credits_finalization.run();
        });
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let previous_balance_caller = balances.get(caller);
            balances.set(caller, previous_balance_caller - amount);
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

    fn shield(public amount: u128) -> (Token, Final) {
        let signer = self.signer;
        let token = Token { owner: signer, amount };
        return (
            token,
            final {
                let previous_balance_caller = balances.get(signer);
                balances.set(signer, previous_balance_caller - amount);
            },
        );
    }

    fn unshield(input: Token, amount: u128) -> (Token, Token, Final) {
        assert(input.amount >= amount);
        let (credits_record, credits_finalization) = credits.aleo/transfer_public_to_private(
            input.owner,
            amount as u64,
        );
        let (_, conv_final) = credits.aleo/transfer_private_to_public(
            credits_record,
            input.owner,
            amount as u64,
        );
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        let zero_token = Token { owner: input.owner, amount: 0u128 };
        return (
            change_token,
            zero_token,
            final {
                credits_finalization.run();
                conv_final.run();
            },
        );
    }

    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token) {
        assert(input.owner == self.signer);
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        let new_token = Token { owner: to, amount };
        return (change_token, new_token);
    }

    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Metadata, Final) {
        assert(input.owner == self.signer);
        let change_token = Token { owner: input.owner, amount: input.amount - amount };
        let metadata = Metadata { owner: input.owner, sender: input.owner };
        return (
            change_token,
            metadata,
            final {
                let previous_balance_receiver = balances.get(to);
                balances.set(to, previous_balance_receiver + amount);
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
            assert(current >= amount);
            allowances.set(key, current - amount);
            let prev_owner = balances.get(owner);
            balances.set(owner, prev_owner - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }

    fn transfer_from_public_to_private(
        public owner: address,
        public amount: u128,
    ) -> (Token, Final) {
        let spender = self.caller;
        let key = TokenAllowance { account: owner, spender: spender };
        let token = Token { owner: spender, amount };
        return (
            token,
            final {
                let current = allowances.get(key);
                assert(current >= amount);
                allowances.set(key, current - amount);
                let prev_owner = balances.get(owner);
                balances.set(owner, prev_owner - amount);
            },
        );
    }

    fn transfer_public_as_signer(to: address, amount: u128) -> Final {
        let signer = self.signer;
        return final {
            let previous_balance_signer = balances.get(signer);
            balances.set(signer, previous_balance_signer - amount);
            let previous_balance_receiver = balances.get_or_use(to, 0u128);
            balances.set(to, previous_balance_receiver + amount);
        };
    }

    // MintableToken interface
    fn mint_public(public recipient: address, public amount: u128) -> Final {
        let credits_finalization = credits.aleo/transfer_public_as_signer(self.address, amount as u64);
        let depositor = self.signer;
        return final {
            credits_finalization.run();
            let previous_balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, previous_balance + amount);
        };
    }

    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final) {
        let signer = self.signer;
        let token = Token { owner: recipient, amount };
        return (
            token,
            final {
                let previous_balance = balances.get(signer);
                balances.set(signer, previous_balance - amount);
            },
        );
    }

    fn burn_public(public amount: u128) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.caller, amount as u64);
        let burner = self.caller;
        return final {
            let previous_balance = balances.get(burner);
            balances.set(burner, previous_balance - amount);
            credits_finalization.run();
        };
    }

    fn burn_private(input: Token) -> Final {
        assert(input.owner == self.signer);
        let (_, credits_finalization) = credits.aleo/transfer_public_to_private(
            input.owner,
            input.amount as u64,
        );
        return final {
            credits_finalization.run();
        };
    }
}
