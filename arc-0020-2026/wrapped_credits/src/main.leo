import credits.aleo;

program wrapped_credits.aleo {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
    }

    mapping balances: address => u128;

    fn deposit_credits_public(
        public amount: u64
    ) -> Final {
        let credits_finalization = credits.aleo/transfer_public_as_signer(self.address, amount);

        return final {
            credits_finalization.run();
            let previous_balance = balances.get(self.address).unwrap_or(0);
            balances.set(self.address, previous_balance + amount);
        };
    }

    fn deposit_credits_private(
        input_record: credits.aleo/credits,
        amount: u64
    ) -> (credits.aleo/credits, Final, Token) {
        // TODO: can we destructure the tuple immediately?
        let transfer_output: (credits.aleo/credits, Final) = credits.aleo/transfer_private_to_public(input_record, self.address, amount);
        let mint_output = Token {
             owner: self.signer,
             amount: amount as u128
        };
        return (transfer_output.0, transfer_output.1, mint_output);
    }

    fn withdraw_credits_public(
        amount: u64
    ) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.caller, amount);
        return final {
            let previous_balance = balances.get(self.address).unwrap();
            balances.set(self.address, previous_balance - amount); // TODO: do we error automatically on underflow?
            credits_finalization.run();
        };
    }

    fn withdraw_credits_public_signer(
        amount: u64
    ) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.signer, amount);
        return final {
            let previous_balance = balances.get(self.address).unwrap();
            balances.set(self.address, previous_balance - amount); // TODO: do we error automatically on underflow?
            credits_finalization.run();
        };
    }

    fn withdraw_credits_private(
        input_token: Token,
        amount: u64
    ) -> (credits.aleo/credits, Final, Token) {
        let transfer_output: (credits.aleo/credits, Final) = credits.aleo/transfer_public_to_private(input_token.owner, amount);
        let change_token = Token {
            owner: input_token.owner,
            amount: input_token.amount - amount as u128
        };

        return (transfer_output.0, transfer_output.1, change_token);
    }

    fn transfer_public(to: address, amount: u128) -> Final {
        return final {
            let previous_balance_caller = balances.get(self.caller).unwrap();
            balances.set(self.caller, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
            let previous_balance_receiver = balances.get(to).unwrap_or(0);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        };
    }

    fn transfer_public_to_private(to: address, amount: u128) -> (Final, Token) {
        let token = Token {
            owner: to,
            amount
        };
        return (final {
            let previous_balance_caller = balances.get(self.caller).unwrap();
            balances.set(self.caller, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
        }, token);
    }

    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token) {
        assert(input.owner == self.signer);

        let change_token = Token {
            owner: input.owner,
            amount: input.amount - amount
        };

        let new_token = Token {
            owner: to,
            amount
        };

        return (change_token, new_token);
    }

    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Final, Token) {
        assert(input.owner == self.signer);

        let change_token = Token {
            owner: input.owner,
            amount: input.amount - amount
        };

        return (final {
            let previous_balance_receiver = balances.get(to).unwrap_or(0);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        }, change_token);
    }

    fn transfer_public_as_signer(to: address, amount: u128) -> Final {
        return final {
            let previous_balance_caller = balances.get(self.signer).unwrap();
            balances.set(self.signer, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
            let previous_balance_receiver = balances.get(to).unwrap_or(0);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        };
    }
}