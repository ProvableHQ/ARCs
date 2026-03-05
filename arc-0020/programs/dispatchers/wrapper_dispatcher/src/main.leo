// wrapper_dispatcher.aleo
//
// ARC-0020 dispatcher routing to token wrapper programs for use by DeFi protocols
// (DEXs, multisigs, vaults) that need a single stable API across multiple tokens.
//
// Design:
//   - Callers supply token_id + program_id. network_id is hardcoded to NETWORK_ALEO.
//   - token_routes mapping enforces that program_id is a registered wrapper for token_id.
//     Validation runs in finalize; an unregistered program_id reverts the transaction.
//   - Route validation applies to public-state functions (1, 2, 5) where token_id is
//     a public parameter. Record-only ops (join, split, transfer_private_to_public,
//     transfer_private) are not validated via mapping — the AVM enforces record type
//     identity at execution time, preventing cross-wrapper record misuse.
//
// Usage for a DEX or multisig:
//   1. Token issuers call register_route(token_id, wrapper_program_id) once.
//   2. DeFi protocols call any of the 7 functions with (token_id, ..., program_id).
//      The dispatcher validates the route and forwards to the correct wrapper.
//
// Architecture:
//   DeFi protocol → wrapper_dispatcher → _dynamic_call →
//     {credits,registry,stablecoin}_wrapper → vault ops / underlying program

program wrapper_dispatcher.aleo {

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  const NETWORK_ALEO: field = 1868917857field;

  // ---------------------------------------------------------------------------
  // Route registry
  // ---------------------------------------------------------------------------

  // token_id → approved wrapper program_id.
  // Set once by the token issuer; validated on every public-state call.
  mapping token_routes: field => field;

  // Register (or update) the approved wrapper for a token_id.
  // In production this would be access-controlled; for the ARC demo it is open.
  fn register_route(
    public token_id: field,
    public program_id: field
  ) -> Final {
    return final {
      token_routes.set(token_id, program_id);
    };
  }

  // ---------------------------------------------------------------------------
  // Field encodings for wrapper function names (ASCII, little-endian byte packing).
  // ---------------------------------------------------------------------------

  // "transfer_public"
  const FUNC_TRANSFER_PUBLIC: field = 516175629116388850284097790795674228field;

  // "transfer_public_as_signer"
  const FUNC_TRANSFER_PUBLIC_AS_SIGNER: field = 718076685225955844079766916816982442103848756111050079826548field;

  // "join"
  const FUNC_JOIN: field = 1852403562field;

  // "split"
  const FUNC_SPLIT: field = 499984920691field;

  // "transfer_public_to_private"
  const FUNC_TRANSFER_PUBLIC_TO_PRIVATE: field = 163031276046149327277138208237194600527678254627957973064970868field;

  // "transfer_private_to_public"
  const FUNC_TRANSFER_PRIVATE_TO_PUBLIC: field = 159748619646624572882733203183532374243803035081386454010655348field;

  // "transfer_private"
  const FUNC_TRANSFER_PRIVATE: field = 134856310785155548303824185267685782132field;

  // ===========================================================================
  // Public-state functions — include route validation in finalize
  // ===========================================================================

  // 1. transfer_public — debits self.caller on the wrapper
  fn transfer_public(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, NETWORK_ALEO, FUNC_TRANSFER_PUBLIC, token_id, recipient, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // 2. transfer_public_as_signer — debits self.signer (the transaction signer)
  fn transfer_public_as_signer(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, NETWORK_ALEO, FUNC_TRANSFER_PUBLIC_AS_SIGNER, token_id, recipient, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // 5. transfer_public_to_private — vault-in; returns wrapper token record
  fn transfer_public_to_private(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, NETWORK_ALEO, FUNC_TRANSFER_PUBLIC_TO_PRIVATE, token_id, recipient, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  // ===========================================================================
  // Record-only functions — no route validation (AVM enforces record type identity)
  // ===========================================================================

  // 3. join — combines two records of the same token into one
  fn join(
    r1: dyn record,
    r2: dyn record,
    public program_id: field
  ) -> dyn record {
    let r: dyn record = _dynamic_call::[dyn record](program_id, NETWORK_ALEO, FUNC_JOIN, r1, r2);
    return r;
  }

  // 4. split — splits one record into two
  fn split(
    r: dyn record,
    amount: u128,
    public program_id: field
  ) -> (dyn record, dyn record) {
    let (r1, r2): (dyn record, dyn record) = _dynamic_call::[dyn record, dyn record](program_id, NETWORK_ALEO, FUNC_SPLIT, r, amount);
    return (r1, r2);
  }

  // 6. transfer_private_to_public — vault-out; returns change record
  fn transfer_private_to_public(
    public recipient: address,
    public amount: u128,
    r: dyn record,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r_out, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, NETWORK_ALEO, FUNC_TRANSFER_PRIVATE_TO_PUBLIC, recipient, amount, r);
    return (r_out, final { f.run(); });
  }

  // 7. transfer_private — returns (change, transfer_record, Final)
  fn transfer_private(
    recipient: address,
    amount: u128,
    r: dyn record,
    public program_id: field
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, NETWORK_ALEO, FUNC_TRANSFER_PRIVATE, recipient, amount, r);
    return (r1, r2, final { f.run(); });
  }

}
