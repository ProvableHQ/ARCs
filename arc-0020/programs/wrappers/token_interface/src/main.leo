// token_interface.aleo
//
// ARC-0020 formal interface definitions for token wrapper programs.
//
// Three interfaces with inheritance:
//   CoreWrapper      — implemented by all three wrappers (5 functions)
//   ExtendedWrapper  — implemented by credits_wrapper and registry_wrapper (+2)
//   CompliantWrapper — implemented by stablecoin_wrapper (+3 compliant functions)
//
// Leo 3.4.0 enforcement limitation:
//   Functions that use wrapper-owned record types (join, split, transfer_public_to_private,
//   transfer_private_to_public, transfer_private, and all compliant variants) cannot be
//   formally enforced via interface because Leo requires exact record type identity across
//   programs and prohibits creating external records.
//
//   Formally enforced (no record params/returns in signatures):
//     - transfer_public
//     - transfer_public_as_signer
//
//   Informally specified (documented here, implemented per-wrapper by convention):
//     - join, split, transfer_public_to_private
//     - transfer_private_to_public, transfer_private (ExtendedWrapper)
//     - compliant_transfer_to_public, compliant_transfer_private,
//       compliant_transfer_with_creds (CompliantWrapper)
//
// Vault pattern (enforced informally):
//   Public ops:  User → wrapper → underlying program (direct delegation, no records)
//   Vault-in:    transfer_public_to_private → underlying.transfer_public_as_signer(self.address, amt)
//                  + wrapper creates Token { owner: recipient, amount }
//   Vault-out:   transfer_private_to_public → wrapper consumes record
//                  → underlying.transfer_public(recipient, amt)
//   Private ops: join / split / transfer_private — purely local record ops, no underlying call
//
// Invariant: wrapper's balance on underlying program = sum of all outstanding wrapper Token amounts.

import merkle_tree.aleo;

// ---------------------------------------------------------------------------
// CoreWrapper — all wrappers implement
// ---------------------------------------------------------------------------
// Formally enforced functions (no record types in signatures):
//   1. transfer_public          — debit self.caller on underlying
//   2. transfer_public_as_signer — debit self.signer on underlying
//
// Informally specified functions (wrapper-owned records, not cross-program enforceable):
//   3. join(r1: Token, r2: Token) -> Token
//   4. split(input: Token, amount: u128) -> (Token, Token)
//   5. transfer_public_to_private(public token_id: field, recipient: address, public amount: u128) -> (Token, Final)
//      vault-in: underlying.transfer_public_as_signer(self.address, amount)
interface CoreWrapper {
    record Token;

    fn transfer_public(public token_id: field, public recipient: address, public amount: u128) -> Final;
    fn transfer_public_as_signer(public token_id: field, public recipient: address, public amount: u128) -> Final;
}

// ---------------------------------------------------------------------------
// ExtendedWrapper — credits_wrapper and registry_wrapper implement
// ---------------------------------------------------------------------------
// Inherits CoreWrapper (functions 1-2 enforced, 3-5 informal).
// Adds informally specified functions:
//   6. transfer_private_to_public(public recipient: address, public amount: u128, input: Token) -> (Token, Final)
//      vault-out: underlying.transfer_public(recipient, amount)
//   7. transfer_private(recipient: address, amount: u128, input: Token) -> (Token, Token, Final)
//      local: create change + transfer records; final { assert(true); }
interface ExtendedWrapper : CoreWrapper {
}

// ---------------------------------------------------------------------------
// CompliantWrapper — stablecoin_wrapper implements
// ---------------------------------------------------------------------------
// Inherits CoreWrapper (functions 1-2 enforced, 3-5 informal).
// Adds record prototypes for compliance records.
// Informally specified compliant functions:
//   8. compliant_transfer_to_public(
//        public recipient: address, public amount: u128,
//        input: Token, public proofs: [merkle_tree.aleo/MerkleProof; 2]
//      ) -> (ComplianceRecord, Token, Final)
//      vault-out + compliance: consume record, create ComplianceRecord,
//      call underlying.transfer_public(recipient, amount) to unvault.
//      finalize: verify Merkle root, check not paused.
//
//   9. compliant_transfer_private(
//        recipient: address, public amount: u128,
//        input: Token, public proofs: [merkle_tree.aleo/MerkleProof; 2]
//      ) -> (ComplianceRecord, Token, Token, Final)
//      local: create change + transfer + ComplianceRecord.
//      finalize: verify Merkle root, check not paused.
//
//  10. compliant_transfer_with_creds(
//        recipient: address, public amount: u128,
//        input: Token, credentials: Credentials
//      ) -> (ComplianceRecord, Token, Token, Credentials, Final)
//      local: create change + transfer + ComplianceRecord + renewed Credentials.
//      finalize: verify credentials root, check not paused.
interface CompliantWrapper : CoreWrapper {
    record ComplianceRecord;
    record Credentials;
}

// ---------------------------------------------------------------------------
// Mintable — single-token registry wrappers that hardcode a token_id
// ---------------------------------------------------------------------------
// Extends ExtendedWrapper with minting capability for a specific token.
// Implementations supply a HARDCODED_TOKEN_ID constant and delegate to
// token_registry.aleo with that fixed id.
//
// Design: the wrapper admin must hold MINTER_ROLE on token_registry for
// HARDCODED_TOKEN_ID.  No token_id parameter is required in the Mintable
// signatures — the token is fixed at deploy time.
//
// Formally enforced:
//   8. mint_public(public recipient: address, public amount: u128) -> Final
//      delegates to token_registry/mint_public(HARDCODED_TOKEN_ID, recipient, amount, 0u32).
//
// Informally specified (record return type — cannot be cross-program enforced):
//   9. mint_private(recipient: address, public amount: u128) -> (Token, Final)
//      vault-in mint: creates wrapper Token record + mints to self.address on registry.
interface Mintable : ExtendedWrapper {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    // fn mint_private(recipient: address, public amount: u128) -> (Token, Final);
    // Informally specified — record return type prevents cross-program enforcement.
}

// ---------------------------------------------------------------------------
// Marker program — interfaces above are the payload.
// Programs import this file to reference the interfaces.
// ---------------------------------------------------------------------------
program token_interface.aleo {
    fn noop() {}
}
