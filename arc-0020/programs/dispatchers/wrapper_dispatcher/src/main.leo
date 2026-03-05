// wrapper_dispatcher.aleo — ARC-0020 dispatcher for DeFi protocols needing a unified
// token API across multiple tokens (DEXs, multisigs, vaults).
//
// Callers supply token_id + program_id; network_id is hardcoded to NETWORK_ALEO.
// token_routes validates that program_id is a registered wrapper for token_id.
// Route validation runs in finalize for public-state calls. Record-only ops
// (join, split, unshield, transfer_private) are not route-validated — the AVM
// enforces record type identity at execution time, preventing cross-wrapper misuse.

program wrapper_dispatcher.aleo {

  const NETWORK_ALEO: field = 1868917857field;

  // token_id → approved wrapper program_id. Validated on every public-state call.
  mapping token_routes: field => field;

  // In production this should be access-controlled.
  fn register_route(
    public token_id: field,
    public program_id: field
  ) -> Final {
    return final {
      token_routes.set(token_id, program_id);
    };
  }

  // Function name field encodings: ASCII bytes, little-endian (byte[0] + byte[1]*256 + ...).
  const FUNC_TRANSFER_PUBLIC: field = 516175629116388850284097790795674228field;           // "transfer_public"
  const FUNC_TRANSFER_PUBLIC_AS_SIGNER: field = 718076685225955844079766916816982442103848756111050079826548field; // "transfer_public_as_signer"
  const FUNC_JOIN: field = 1852403562field;                                                // "join"
  const FUNC_SPLIT: field = 499984920691field;                                             // "split"
  const FUNC_SHIELD: field = 110416720652403field;                                         // "shield"
  const FUNC_UNSHIELD: field = 7236270204675911285field;                                   // "unshield"
  const FUNC_TRANSFER_PRIVATE: field = 134856310785155548303824185267685782132field;        // "transfer_private"

  // Public-state functions — route-validated in finalize.

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

  fn shield(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, NETWORK_ALEO, FUNC_SHIELD, token_id, recipient, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  // Record-only functions — AVM enforces record type identity; no route validation needed.

  fn join(
    r1: dyn record,
    r2: dyn record,
    public program_id: field
  ) -> dyn record {
    let r: dyn record = _dynamic_call::[dyn record](program_id, NETWORK_ALEO, FUNC_JOIN, r1, r2);
    return r;
  }

  fn split(
    r: dyn record,
    amount: u128,
    public program_id: field
  ) -> (dyn record, dyn record) {
    let (r1, r2): (dyn record, dyn record) = _dynamic_call::[dyn record, dyn record](program_id, NETWORK_ALEO, FUNC_SPLIT, r, amount);
    return (r1, r2);
  }

  fn unshield(
    public recipient: address,
    public amount: u128,
    r: dyn record,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r_out, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, NETWORK_ALEO, FUNC_UNSHIELD, recipient, amount, r);
    return (r_out, final { f.run(); });
  }

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
