// wrapper_dispatcher.aleo — ARC-0020 dispatcher for DeFi protocols needing a unified
// token API across multiple tokens (DEXs, multisigs, vaults).
//
// Callers supply token_id + program_id; network_id is hardcoded to 'aleo'.
// token_routes validates that program_id is a registered wrapper for token_id.
// Route validation runs in finalize for all public-state calls, including unshield
// (which writes balances). Pure record-only ops (join, split, transfer_private) are
// not route-validated — the AVM enforces record type identity at execution time.

program wrapper_dispatcher.aleo {

  // token_id → approved wrapper program_id. Validated on every public-state call.
  mapping token_routes: field => field;

  @noupgrade
  constructor() {}

  // In production this should be access-controlled.
  fn register_route(
    public token_id: field,
    public program_id: field
  ) -> Final {
    return final {
      token_routes.set(token_id, program_id);
    };
  }

  // Public-state functions — route-validated in finalize.

  // NOTE: transfer_public uses self.caller inside the wrapper, which equals wrapper_dispatcher when
  // called through this dispatcher — not the end user. This means transfer_public through the
  // dispatcher only works for programs that themselves hold a wrapper balance (program-to-program).
  // Use transfer_public_as_signer for end-user calls through the dispatcher.
  fn transfer_public(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'transfer_public', token_id, recipient, amount);
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
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'transfer_public_as_signer', token_id, recipient, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // Deposit: moves caller's underlying public balance into the wrapper vault.
  // Use for wrappers whose deposit returns Final (credits, registry, fixed_registry).
  fn deposit(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'deposit', token_id, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // Deposit for compliant wrappers (stablecoin) whose deposit returns (ComplianceRecord, Final).
  // The ComplianceRecord output is owned by INVESTIGATOR_ADDRESS and routed to them by the AVM.
  fn deposit_compliant(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'deposit', token_id, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  // Withdraw: moves caller's wrapper balance back to the underlying program.
  // Use for wrappers whose withdraw returns Final (credits, registry, fixed_registry).
  fn withdraw(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'withdraw', token_id, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // Withdraw for compliant wrappers (stablecoin) whose withdraw returns (ComplianceRecord, Final).
  // The ComplianceRecord output is owned by INVESTIGATOR_ADDRESS and routed to them by the AVM.
  fn withdraw_compliant(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'withdraw', token_id, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  // withdraw_as_signer: use instead of withdraw when calling through this dispatcher,
  // so the wrapper uses self.signer (the end user) rather than self.caller (the dispatcher).
  fn withdraw_as_signer(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'withdraw_as_signer', token_id, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  // withdraw_as_signer for compliant wrappers (stablecoin) returning (ComplianceRecord, Final).
  fn withdraw_as_signer_compliant(
    public token_id: field,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'withdraw_as_signer', token_id, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  fn shield(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'shield', token_id, recipient, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  // Record-only functions — AVM enforces record type identity; no route validation needed.
  // Exception: join, split, transfer_private are fully record-bound.
  // unshield writes public state (balances mapping), so it IS route-validated despite consuming a record.

  fn join(
    r1: dyn record,
    r2: dyn record,
    public program_id: field
  ) -> dyn record {
    let r: dyn record = _dynamic_call::[dyn record](program_id, 'aleo', 'join', r1, r2);
    return r;
  }

  fn split(
    r: dyn record,
    amount: u128,
    public program_id: field
  ) -> (dyn record, dyn record) {
    let (r1, r2): (dyn record, dyn record) = _dynamic_call::[dyn record, dyn record](program_id, 'aleo', 'split', r, amount);
    return (r1, r2);
  }

  // token_id is required for route validation: the token_id inside the consumed record is private,
  // so the caller must supply it publicly. AVM record type identity prevents cross-wrapper misuse.
  fn unshield(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    r: dyn record,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r_out, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'unshield', recipient, amount, r);
    return (r_out, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

  fn transfer_private(
    recipient: address,
    amount: u128,
    r: dyn record,
    public program_id: field
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, 'aleo', 'transfer_private', recipient, amount, r);
    return (r1, r2, final { f.run(); });
  }

  // Mint functions — for fixed_registry_wrapper (and similar single-token wrappers).
  // token_id is passed for route validation but ignored inside the wrapper (uses HARDCODED_TOKEN_ID).

  fn mint_public(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    public program_id: field
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, 'aleo', 'mint_public', token_id, recipient, amount);
    return final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    };
  }

  fn mint_private(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public program_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, 'aleo', 'mint_private', token_id, recipient, amount);
    return (r, final {
      let registered: field = token_routes.get(token_id);
      assert_eq(registered, program_id);
      f.run();
    });
  }

}
