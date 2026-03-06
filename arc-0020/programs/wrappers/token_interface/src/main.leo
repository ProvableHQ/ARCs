// token_interface.aleo — ARC-0020 interface definitions for token wrapper programs.
//
// Hierarchy:
//   PublicToken                         — formally enforced
//   PrivateToken                        — informally specified (record types block Leo enforcement)
//   PrivateCompliant : PrivateToken     — compliance variant; adds ComplianceRecord, Credentials
//   ARC20 : PublicToken + PrivateToken
//   ARC21 : PublicToken + PrivateCompliant
//   Bridge                              — formally enforced; deposit/withdraw vault boundary
//   MintPublic                          — formally enforced
//   MintPrivate : PrivateToken          — informally specified
//   MintPrivateCompliant : PrivateCompliant — informally specified
//   Allowance                           — formally enforced
//
// Informally specified functions (Leo cannot enforce cross-program record type identity):
//   PrivateToken:
//     join(Token, Token) -> Token
//     split(Token, u128) -> (Token, Token)
//     transfer_private(address, u128, Token) -> (Token, Token, Final)
//   ARC20:
//     shield(field, address, u128) -> (Token, Final)
//     unshield(address, u128, Token) -> (Token, Final)
//   ARC21:
//     shield(field, address, u128) -> (ComplianceRecord, Token, Final)
//     unshield(address, u128, Token, [MerkleProof; 2]) -> (ComplianceRecord, Token, Final)
//   MintPrivate:        mint_private(field, address, u128) -> (Token, Final)
//   MintPrivateCompliant: mint_private(field, address, u128) -> (ComplianceRecord, Token, Final)
//
// Vault invariant: wrapper's balance on underlying program = sum of all outstanding Token amounts.

import merkle_tree.aleo;

interface PublicToken {
    fn transfer_public(public token_id: field, public recipient: address, public amount: u128) -> Final;
    fn transfer_public_as_signer(public token_id: field, public recipient: address, public amount: u128) -> Final;
}

// record Token; declared here, implemented per-wrapper.
interface PrivateToken {
    record Token;
}

// Adds compliance tracking records; transfer_private takes merkle_proofs and returns ComplianceRecord.
interface PrivateCompliant : PrivateToken {
    record ComplianceRecord;
    record Credentials;
}

// shield: vault-in — transfers public balance to wrapper, creates Token record.
// unshield: vault-out — consumes Token record, releases public balance.
interface ARC20 : PublicToken + PrivateToken {
}

// Compliant variants of shield/unshield return ComplianceRecord; unshield takes merkle_proofs.
interface ARC21 : PublicToken + PrivateCompliant {
}

// deposit: moves signer's underlying public balance into the wrapper vault.
// withdraw: moves caller's wrapper balance back to the underlying program (self.caller).
// withdraw_as_signer: same as withdraw but uses self.signer; correct for dispatcher calls.
// stablecoin_wrapper cannot implement Bridge (different return types) — intentionally a hybrid.
interface Bridge {
    fn deposit(public token_id: field, public amount: u128) -> Final;
    fn withdraw(public token_id: field, public amount: u128) -> Final;
    fn withdraw_as_signer(public token_id: field, public amount: u128) -> Final;
}

// mint_public: token_id is ignored; implementations use HARDCODED_TOKEN_ID.
interface MintPublic {
    fn mint_public(public token_id: field, public recipient: address, public amount: u128) -> Final;
}

// mint_private: vault-in mint — mints to self.address on underlying, creates Token record.
interface MintPrivate : PrivateToken {
}

// mint_private: same as MintPrivate but returns (ComplianceRecord, Token, Final).
interface MintPrivateCompliant : PrivateCompliant {
}

interface Allowance {
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
}

// Marker program — interfaces above are the payload.
program token_interface.aleo {
    fn noop() {}
}
