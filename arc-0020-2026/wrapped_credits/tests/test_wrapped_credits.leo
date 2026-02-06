// The 'test_wrapped_credits' test program.
import wrapped_credits.aleo;
program test_wrapped_credits.aleo {
    @test
    script test_it() {
        let result: u32 = wrapped_credits.aleo/main(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = wrapped_credits.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }

    @noupgrade
    async constructor() {}
}
