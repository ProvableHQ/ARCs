import wrapped_credits.aleo;

// Dummy exchange that spends allowance via transfer_from_public.
// Used to test that approve_public allowance is spendable by a third party.
program dummy_exchange.aleo {
    @noupgrade
    constructor() {}

    fn transfer_from(
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let f = wrapped_credits.aleo::transfer_from_public(owner, recipient, amount);
        return final {
            f.run();
        };
    }
}
