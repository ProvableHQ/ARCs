import token_registry.aleo;

// Interface matching compliant_token_template.aleo transfer_public signature (PR 29151)
interface TransferPublic {
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
}

// Custom token ID wrapped by this program (distinct from CREDITS_RESERVED_TOKEN_ID)
const WRAPPED_TOKEN_ID: field = 99999field;

program wrapped_token_registry.aleo : TransferPublic {
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
}
