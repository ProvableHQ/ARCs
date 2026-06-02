interface IARC20 {
    record Token {
        owner: address,
        amount: u128,
        ..
    }
    //=============================================================
    //               TRANSFER FUNCTIONS
    //=============================================================
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(private input: Token, private recipient: address, private amount: u128) -> (Token, Token);
    fn transfer_private_to_public(private input: Token, public recipient: address, private amount: u128) -> (Token, Final);
    fn transfer_public_to_private(private recipient: address, public amount: u128) -> (Token, Final);
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(
        public owner: address,
        private recipient: address,
        public amount: u128,
    ) -> (Token, Final);

    //=============================================================
    //               APPROVAL FUNCTIONS
    //=============================================================
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;

    //=============================================================
    //               JOIN/SPLIT FUNCTIONS
    //=============================================================
    fn join(private input_1: Token, private input_2: Token) -> Token;
    fn split(private input: Token, private amount: u128) -> (Token, Token);

    //=============================================================
    //                VIEW FUNCTIONS
    //=============================================================
    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}