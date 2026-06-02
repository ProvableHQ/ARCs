// The 'test_arc22freezelist' test program.
import arc22freezelist.aleo;

program test_arc22freezelist.aleo {
    @test
    @should_fail
    fn test_main_fails() {
        let result: u32 = arc22freezelist.aleo::main(2u32, 3u32);
        assert_eq(result, 3u32);
    }

    @noupgrade
    constructor() {}
}
