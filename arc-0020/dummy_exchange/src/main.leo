// Dummy exchange demonstrating ARC20 interoperability via interface dispatch.
//
// Uses the IARC20 interface to interact with *any* ARC20 token by its program
// ID (token_id field) at runtime.

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

program dummy_exchange.aleo {
    @noupgrade
    constructor() {}

    // Pull tokens from `owner` to `recipient` via allowance (approve_public must be called first).
    // Works with any ARC20 token — the caller passes the token's program ID.
    fn transfer_from(
        public token_id: field,
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let f: Final = IARC20@(token_id)::transfer_from_public(owner, recipient, amount);
        return final { f.run(); };
    }

    // Example: swap token_in for token_out.
    // Pulls `amount_in` of `token_in` from signer (requires prior approve_public),
    // then sends `amount_out` of `token_out` to signer from this program's balance.
    fn swap(
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out: u128,
    ) -> Final {
        // Pull token_in from signer via allowance
        let pull: Final = IARC20@(token_in)::transfer_from_public(self.signer, self.address, amount_in);
        // Send token_out to signer from this program's balance
        let push: Final = IARC20@(token_out)::transfer_public(self.signer, amount_out);
        return final {
            pull.run();
            push.run();
        };
    }
}
