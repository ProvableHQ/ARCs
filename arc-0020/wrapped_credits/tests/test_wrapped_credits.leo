// The 'test_wrapped_credits' test program.
import wrapped_credits.aleo;

program test_wrapped_credits.aleo {
    // transfer_public matches TransferPublic interface (compliant_token_template.aleo)
    // Signature: fn transfer_public(public recipient: address, public amount: u128) -> Final
    // Note: May fail at runtime without deployed state (insufficient balance)
    @test
    fn test_transfer_public_compiles() -> Final {
        let f = wrapped_credits.aleo::transfer_public(
            aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t,
            100u128,
        );
        return final { f.run(); };
    }

    @noupgrade
    constructor() {}
}
