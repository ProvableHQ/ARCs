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

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        // Use transfer_public_as_signer so the sender is the transaction signer (user),
        // not this program's address (self.caller would be wrapped_token_registry).
        let tr_final = token_registry.aleo/transfer_public_as_signer(WRAPPED_TOKEN_ID, recipient, amount);
        return final {
            tr_final.run();
        };
    }

    fn transfer_public_to_private(public to: address, public amount: u128) -> (token_registry.aleo/Token, Final) {
        // Use transfer_public_as_signer so the sender is the transaction signer (user),
        // not this program's address (self.caller would be wrapped_token_registry).
        let (token_out, tr_final) = token_registry.aleo/transfer_pub_to_priv_as_signer(WRAPPED_TOKEN_ID, to, amount, false);
        return (token_out, final { tr_final.run(); });
    }

    fn transfer_private(input: token_registry.aleo/Token, to: address, amount: u128) -> (token_registry.aleo/Token, token_registry.aleo/Token) {
        assert(input.owner == self.signer);
        assert(input.token_id == WRAPPED_TOKEN_ID);
        let result = token_registry.aleo/transfer_private(input, to, amount);
        return result;
    }
}
