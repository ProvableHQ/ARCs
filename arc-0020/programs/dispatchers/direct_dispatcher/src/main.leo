// direct_dispatcher.aleo
//
// ARC-0020 low-level generic dispatcher.
//
// Unlike wrapper_dispatcher (which routes to wrapper programs with hardcoded
// func_ids), direct_dispatcher accepts program_id + network_id + func_id at
// runtime, routing to any ARC-0020-compatible program or underlying token program.
//
// Functions are organized by SIGNATURE SHAPE — each function handles a distinct
// combination of input types and output types.
//
// Callers encode the target function name as a field value using ASCII byte packing:
//   field = byte[0] + byte[1]*256 + byte[2]*256^2 + ...
//
// on-chain token routes are stored in the token_routes mapping, keyed by token_id.
//
// Phase 1: → Final                          (functions 1–8)
// Phase 2: → dyn record                     (functions 9–10)
// Phase 3: → (dyn record, dyn record)       (functions 11–12)
// Phase 4: → (dyn record, Final)            (functions 13–17)
// Phase 5: → (dyn record, dyn record, Final)(functions 18–21)
// Phase 6: → (r, r, r, Final)               (functions 22–24)
// Phase 7: → (r, r, r, r, Final)            (functions 25–26)
// Phase 8: → (r, r, r, r, r, Final)         (functions 27–29)

program direct_dispatcher.aleo {

  // ---------------------------------------------------------------------------
  // Struct mirrors
  // ---------------------------------------------------------------------------

  // Mirrors merkle_tree.aleo/MerkleProof — field layout must be identical.
  struct MerkleProof {
    siblings: [field; 16],
    leaf_index: u32,
  }

  // Mirrors token_registry.aleo/TokenOwner — used as mapping key.
  struct TokenOwner {
    account: address,
    token_id: field,
  }

  // ---------------------------------------------------------------------------
  // On-chain routing table
  // ---------------------------------------------------------------------------

  // Identifies a program and its dispatch convention.
  struct TokenRoute {
    program_id: field,
    network_id: field,
    convention: u8,  // 0 = CoreWrapper, 1 = ExtendedWrapper, 2 = raw
  }

  // token_id → routing info. Set by token admins via register_route.
  mapping token_routes: field => TokenRoute;

  fn register_route(
    public token_id: field,
    public program_id: field,
    public network_id: field,
    public convention: u8
  ) -> Final {
    return final {
      let route: TokenRoute = TokenRoute {
        program_id: program_id,
        network_id: network_id,
        convention: convention,
      };
      token_routes.set(token_id, route);
    };
  }

  // ---------------------------------------------------------------------------
  // Network ID
  // ---------------------------------------------------------------------------
  const NETWORK_ALEO: field = 1868917857field;

  // ===========================================================================
  // Phase 1: → Final
  // Covers: transfer_public, transfer_public_as_signer, initialize,
  //         set_pause_status, mint_public, burn_public, register_token, etc.
  // ===========================================================================

  // 1. (field, address, u128) → Final
  //    e.g. transfer_public(token_id, recipient, amount)
  fn dispatch_f_a_u(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: field,
    public arg1: address,
    public arg2: u128
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1, arg2);
    return final { f.run(); };
  }

  // 2. (address, u128) → Final
  //    e.g. transfer_public(recipient, amount) — single-token programs
  fn dispatch_a_u(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u128
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1);
    return final { f.run(); };
  }

  // 3. (address, u64) → Final
  //    e.g. credits transfer_public(recipient, microcredits)
  fn dispatch_a_u64(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u64
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1);
    return final { f.run(); };
  }

  // 4. (address) → Final
  //    e.g. claim_unbond_public(staker)
  fn dispatch_a(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0);
    return final { f.run(); };
  }

  // 5. (bool) → Final
  //    e.g. set_pause_status(pause_status), set_validator_state(is_open)
  fn dispatch_bool(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: bool
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0);
    return final { f.run(); };
  }

  // 6. (address, address, u128) → Final
  //    e.g. transfer_from_public(owner, recipient, amount)
  fn dispatch_a_a_u(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: address,
    public arg2: u128
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1, arg2);
    return final { f.run(); };
  }

  // 7. (field, address, address, u128) → Final
  //    e.g. token_registry transfer_from_public(token_id, owner, recipient, amount)
  fn dispatch_f_a_a_u(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: field,
    public arg1: address,
    public arg2: address,
    public arg3: u128
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1, arg2, arg3);
    return final { f.run(); };
  }

  // 8. (address, u16) → Final
  //    e.g. update_role(new_address, role)
  fn dispatch_a_u16(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u16
  ) -> Final {
    let f: Final = _dynamic_call::[Final](program_id, network_id, func_id, arg0, arg1);
    return final { f.run(); };
  }

  // ===========================================================================
  // Phase 2: → dyn record
  // Covers: join
  // ===========================================================================

  // 9. (record, record) → record
  //    e.g. join(r1, r2)
  fn dispatch_r_r_to_r(
    r0: dyn record,
    r1: dyn record,
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> dyn record {
    let r: dyn record = _dynamic_call::[dyn record](program_id, network_id, func_id, r0, r1);
    return r;
  }

  // 10. (record) → record
  //     e.g. single-input record transformation
  fn dispatch_r_to_r(
    r0: dyn record,
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> dyn record {
    let r: dyn record = _dynamic_call::[dyn record](program_id, network_id, func_id, r0);
    return r;
  }

  // ===========================================================================
  // Phase 3: → (dyn record, dyn record)
  // Covers: split, transfer_private
  // ===========================================================================

  // 11. (record, u128) → (record, record)
  //     e.g. split(input, amount)
  fn dispatch_r_u_to_rr(
    r0: dyn record,
    amount: u128,
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> (dyn record, dyn record) {
    let (r1, r2): (dyn record, dyn record) = _dynamic_call::[dyn record, dyn record](program_id, network_id, func_id, r0, amount);
    return (r1, r2);
  }

  // 12. (record, u64) → (record, record)
  //     e.g. credits split(input, amount_u64)
  fn dispatch_r_u64_to_rr(
    r0: dyn record,
    amount: u64,
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> (dyn record, dyn record) {
    let (r1, r2): (dyn record, dyn record) = _dynamic_call::[dyn record, dyn record](program_id, network_id, func_id, r0, amount);
    return (r1, r2);
  }

  // ===========================================================================
  // Phase 4: → (dyn record, Final)
  // Covers: transfer_public_to_private, transfer_private_to_public,
  //         transfer_private_to_public (credits u64 variant), authorize
  // ===========================================================================

  // 13. (field, address, u128) → (record, Final)
  //     e.g. transfer_public_to_private(token_id, recipient, amount)
  fn dispatch_f_a_u_to_r_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: field,
    arg1: address,
    public arg2: u128
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, arg0, arg1, arg2);
    return (r, final { f.run(); });
  }

  // 14. (address, u128) → (record, Final)
  //     e.g. single-token transfer_public_to_private(recipient, amount)
  fn dispatch_a_u_to_r_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, arg0, arg1);
    return (r, final { f.run(); });
  }

  // 15. (address, u128, record) → (record, Final)
  //     e.g. transfer_private_to_public(recipient, amount, input)
  fn dispatch_a_u_r_to_r_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u128,
    r0: dyn record
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0);
    return (r, final { f.run(); });
  }

  // 16. (address, u64, record) → (record, Final)
  //     e.g. credits transfer_private_to_public(recipient, amount_u64, input)
  fn dispatch_a_u64_r_to_r_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u64,
    r0: dyn record
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0);
    return (r, final { f.run(); });
  }

  // 17. (address, u64) → (record, Final)
  //     e.g. credits transfer_public_to_private(recipient, amount_u64)
  fn dispatch_a_u64_to_r_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u64
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, arg0, arg1);
    return (r, final { f.run(); });
  }

  // ===========================================================================
  // Phase 5: → (dyn record, dyn record, Final)
  // Covers: transfer_private, compliant_transfer_to_public,
  //         mint_private, burn_private
  // ===========================================================================

  // 18. (address, u128, record) → (record, record, Final)
  //     e.g. transfer_private(recipient, amount, input)
  fn dispatch_a_u_r_to_rr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0);
    return (r1, r2, final { f.run(); });
  }

  // 19. (address, u128) → (record, record, Final)
  //     e.g. mint_private(recipient, amount) → (ComplianceRecord, Token, Final)
  fn dispatch_a_u_to_rr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1);
    return (r1, r2, final { f.run(); });
  }

  // 20. (address, u128, record, [MerkleProof; 2]) → (record, record, Final)
  //     e.g. compliant_transfer_to_public(recipient, amount, input, proofs)
  fn dispatch_a_u_r_proofs_to_rr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    public arg0: address,
    public arg1: u128,
    r0: dyn record,
    public proofs: [MerkleProof; 2]
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, proofs);
    return (r1, r2, final { f.run(); });
  }

  // 21. (record, u128) → (record, record, Final)
  //     e.g. burn_private(input_record, amount) → (ComplianceRecord, Token, Final)
  fn dispatch_r_u_to_rr_f(
    r0: dyn record,
    public arg1: u128,
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, network_id, func_id, r0, arg1);
    return (r1, r2, final { f.run(); });
  }

  // ===========================================================================
  // Phase 6: → (dyn record, dyn record, dyn record, Final)
  // Covers: transfer_private (with compliance), compliant_transfer_private
  // ===========================================================================

  // 22. (address, u128, record) → (record, record, record, Final)
  //     e.g. stablecoin transfer_private(recipient, amount, input) → (Compliance, change, transfer, Final)
  fn dispatch_a_u_r_to_rrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record
  ) -> (dyn record, dyn record, dyn record, Final) {
    let (r1, r2, r3, f): (dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0);
    return (r1, r2, r3, final { f.run(); });
  }

  // 23. (address, u128, record, [MerkleProof; 2]) → (record, record, record, Final)
  //     e.g. compliant_transfer_private(recipient, amount, input, proofs)
  fn dispatch_a_u_r_proofs_to_rrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record,
    public proofs: [MerkleProof; 2]
  ) -> (dyn record, dyn record, dyn record, Final) {
    let (r1, r2, r3, f): (dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, proofs);
    return (r1, r2, r3, final { f.run(); });
  }

  // 24. (address, u128, record, record) → (record, record, record, Final)
  //     e.g. transfer_private_with_creds variant (3 record outputs)
  fn dispatch_a_u_r_r_to_rrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record,
    r1: dyn record
  ) -> (dyn record, dyn record, dyn record, Final) {
    let (ra, rb, rc, f): (dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, r1);
    return (ra, rb, rc, final { f.run(); });
  }

  // ===========================================================================
  // Phase 7: → (dyn record, dyn record, dyn record, dyn record, Final)
  // Covers: compliant_transfer_with_creds
  // ===========================================================================

  // 25. (address, u128, record, record) → (record, record, record, record, Final)
  //     e.g. compliant_transfer_with_creds(recipient, amount, input, credentials)
  fn dispatch_a_u_r_r_to_rrrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record,
    r1: dyn record
  ) -> (dyn record, dyn record, dyn record, dyn record, Final) {
    let (ra, rb, rc, rd, f): (dyn record, dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, r1);
    return (ra, rb, rc, rd, final { f.run(); });
  }

  // 26. (address, u128, record, [MerkleProof; 2]) → (record, record, record, record, Final)
  //     e.g. compliant op returning 4 records
  fn dispatch_a_u_r_proofs_to_rrrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record,
    public proofs: [MerkleProof; 2]
  ) -> (dyn record, dyn record, dyn record, dyn record, Final) {
    let (ra, rb, rc, rd, f): (dyn record, dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, proofs);
    return (ra, rb, rc, rd, final { f.run(); });
  }

  // ===========================================================================
  // Phase 8: → (r, r, r, r, r, Final)
  // Covers: transfer_private_with_creds (compliance + change + transfer + creds + Final)
  // ===========================================================================

  // 27. (address, u128, record, record) → (record, record, record, record, record, Final)
  //     e.g. transfer_private_with_creds → (Compliance, change, transfer, Credentials, Final)
  fn dispatch_a_u_r_r_to_rrrrr_f(
    public program_id: field,
    public network_id: field,
    public func_id: field,
    arg0: address,
    public arg1: u128,
    r0: dyn record,
    r1: dyn record
  ) -> (dyn record, dyn record, dyn record, dyn record, dyn record, Final) {
    let (ra, rb, rc, rd, re, f): (dyn record, dyn record, dyn record, dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, dyn record, dyn record, dyn record, Final](program_id, network_id, func_id, arg0, arg1, r0, r1);
    return (ra, rb, rc, rd, re, final { f.run(); });
  }

  // 28. (record, [MerkleProof; 2]) → (record, record, Final)
  //     e.g. get_credentials(merkle_proofs) → (Credentials, Final) via shape
  fn dispatch_r_proofs_to_rr_f(
    r0: dyn record,
    public proofs: [MerkleProof; 2],
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> (dyn record, dyn record, Final) {
    let (r1, r2, f): (dyn record, dyn record, Final) = _dynamic_call::[dyn record, dyn record, Final](program_id, network_id, func_id, r0, proofs);
    return (r1, r2, final { f.run(); });
  }

  // 29. ([MerkleProof; 2]) → (record, Final)
  //     e.g. get_credentials(sender_merkle_proofs) → (Credentials, Final)
  fn dispatch_proofs_to_r_f(
    public proofs: [MerkleProof; 2],
    public program_id: field,
    public network_id: field,
    public func_id: field
  ) -> (dyn record, Final) {
    let (r, f): (dyn record, Final) = _dynamic_call::[dyn record, Final](program_id, network_id, func_id, proofs);
    return (r, final { f.run(); });
  }

}
