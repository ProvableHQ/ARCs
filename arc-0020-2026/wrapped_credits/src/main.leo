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
        amount: u64
    ) -> (credits.aleo/credits, Token, Final) {
        let (change, credits_finalization) = credits.aleo/transfer_private_to_public(input_record, self.address, amount);
        let mint_output = Token {
             owner: self.signer,
             amount: amount as u128
        };
        return (change, mint_output, final { credits_finalization.run(); });

    }

    fn withdraw_credits_public(
        amount: u64
    ) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.caller, amount);
        let withdrawer = self.caller;
        return final {
            let previous_balance = balances.get_or_use(withdrawer, 0u128);
            balances.set(withdrawer, previous_balance - amount as u128); // TODO: do we error automatically on underflow?
            credits_finalization.run();
        };
    }

    fn withdraw_credits_public_signer(
        amount: u64
    ) -> Final {
        let credits_finalization = credits.aleo/transfer_public(self.signer, amount);
        let withdrawer = self.signer;
        return final {
            let previous_balance = balances.get_or_use(withdrawer, 0u128);
            balances.set(withdrawer, previous_balance - amount as u128); // TODO: do we error automatically on underflow?
            credits_finalization.run();
        };
    }

    fn withdraw_credits_private(
        input_token: Token,
        amount: u64
    ) -> (credits.aleo/credits, Token, Final) {
        let (output, credits_finalization) = credits.aleo/transfer_public_to_private(input_token.owner, amount);
        let change_token = Token {
            owner: input_token.owner,
            amount: input_token.amount - amount as u128
        };

        return (output, change_token, final { credits_finalization.run(); });
    }

    fn transfer_public(to: address, amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let previous_balance_caller = balances.get_or_use(caller, 0u128);
            balances.set(caller, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
            let previous_balance_receiver = balances.get_or_use(to, 0u128);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        };
    }

    fn transfer_public_to_private(to: address, amount: u128) -> (Token, Final) {
        let token = Token {
            owner: to,
            amount
        };
        let caller = self.caller;
        return (token, final {
            let previous_balance_caller = balances.get_or_use(caller, 0u128);
            balances.set(caller, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
        });
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

    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Final) {
        assert(input.owner == self.signer);

        let change_token = Token {
            owner: input.owner,
            amount: input.amount - amount
        };

        return (change_token, final {
            let previous_balance_receiver = balances.get_or_use(to, 0u128);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        });
    }

    fn transfer_public_as_signer(to: address, amount: u128) -> Final {
        let signer = self.signer;
        return final {
            let previous_balance_caller = balances.get_or_use(signer, 0u128);
            balances.set(signer, previous_balance_caller - amount); // TODO: do we error automatically on underflow?
            let previous_balance_receiver = balances.get_or_use(to, 0u128);
            balances.set(to, previous_balance_receiver + amount); // TODO: do we error automatically on overflow?
        };
    }
}