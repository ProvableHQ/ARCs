// Dummy exchange demonstrating ARC20 interoperability via dynamic dispatch.
//
// Instead of importing a specific token program, this uses `_dynamic_call` to
// interact with *any* ARC20 token by its program ID at runtime.
//
// Requires Leo compiler with dynamic dispatch support.
// If your compiler does not support `_dynamic_call`, see the static-import
// version in git history (prior to this commit).

program dummy_exchange.aleo {
    // ARC20 function selectors for dynamic dispatch.
    const NETWORK_ALEO: field = 1868917857field;
    const TRANSFER_FROM_PUBLIC_ID: field = 567541106188061564941814004975800285532843504244field;
    const TRANSFER_PUBLIC_ID: field = 516175629116388850284097790795674228field;

    // Pull tokens from `owner` to `recipient` via allowance (approve_public must be called first).
    // Works with any ARC20 token — the caller passes the token's program ID.
    fn transfer_from(
        public token_id: field,
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let f: Final = _dynamic_call::[Final](
            token_id, NETWORK_ALEO, TRANSFER_FROM_PUBLIC_ID,
            owner, recipient, amount
        );
        return final {
            f.run();
        };
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
        let pull: Final = _dynamic_call::[Final](
            token_in, NETWORK_ALEO, TRANSFER_FROM_PUBLIC_ID,
            self.signer, self.address, amount_in
        );
        // Send token_out to signer from this program's balance
        let push: Final = _dynamic_call::[Final](
            token_out, NETWORK_ALEO, TRANSFER_PUBLIC_ID,
            self.signer, amount_out
        );
        return final {
            pull.run();
            push.run();
        };
    }
}
