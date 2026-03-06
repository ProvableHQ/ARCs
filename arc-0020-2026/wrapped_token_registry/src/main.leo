import token_registry.aleo;

// Interface matching compliant_token_template.aleo transfer signatures (PR 29151)
interface Transferrable {
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_public_to_private(public to: address, public amount: u128) -> (token_registry.aleo/Token, Final);
    fn transfer_private(input: token_registry.aleo/Token, to: address, amount: u128) -> (token_registry.aleo/Token, token_registry.aleo/Token);
}

// Custom token ID wrapped by this program (distinct from CREDITS_RESERVED_TOKEN_ID)
const WRAPPED_TOKEN_ID: field = 99999field;

program wrapped_token_registry.aleo : Transferrable {
    @noupgrade
    constructor() {}

    mapping balances: address => u128;

    fn deposit_token_public(public amount: u128) -> Final {
        let tr_final = token_registry.aleo/transfer_public_as_signer(WRAPPED_TOKEN_ID, self.address, amount);
        let depositor = self.signer;
        return final {
            tr_final.run();
            let prev = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, prev + amount);
        };
    }

    fn deposit_token_private(input: token_registry.aleo/Token, amount: u128) -> (token_registry.aleo/Token, Final) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        assert(input.amount >= amount);
        let (change_token, _) = token_registry.aleo/transfer_private(input, self.address, amount);
        let depositor = self.signer;
        return (change_token, final {
            let prev = balances.get_or_use(depositor, 0u128);
            balances.set(depositor, prev + amount);
        });
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
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(WRAPPED_TOKEN_ID, withdrawer, amount, false);
        return (token_out, final {
            let prev = balances.get(withdrawer);
            balances.set(withdrawer, prev - amount);
            tr_final.run();
        });
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

    fn transfer_public_to_private(public to: address, public amount: u128) -> (token_registry.aleo/Token, Final) {
        let caller = self.caller;
        let (token_out, tr_final) = token_registry.aleo/transfer_public_to_private(WRAPPED_TOKEN_ID, to, amount, false);
        return (token_out, final {
            let prev = balances.get(caller);
            balances.set(caller, prev - amount);
            tr_final.run();
        });
    }

    fn transfer_private(input: token_registry.aleo/Token, to: address, amount: u128) -> (token_registry.aleo/Token, token_registry.aleo/Token) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        let result = token_registry.aleo/transfer_private(input, to, amount);
        return result;
    }
}
