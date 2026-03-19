# ARC-20 & ARC-22: Executive Summary

Two standards. ARC-20 is the base fungible token. ARC-22 adds compliance (freeze lists, audit records, roles, pause).

---

## ARC-20: Fungible Token Standard

### Interface

```leo
interface ARC20 {
    record Token;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(input: Token, to: address, amount: u128) -> (Token, Token);
    fn transfer_private_to_public(input: Token, to: address, amount: u128) -> (Token, Final);
    fn shield(public amount: u128) -> (Token, Final);
    fn unshield(input: Token, amount: u128) -> (Token, Token, Final);

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(public owner: address, public amount: u128) -> (Token, Final);
}

// Optional extension
interface MintableToken: ARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn mint_private(public recipient: address, public amount: u128) -> (Token, Final);
    fn burn_public(public amount: u128) -> Final;
    fn burn_private(input: Token) -> Final;
}
```

### Implementing a token

```leo
program my_token.aleo: MintableToken {
    record Token { owner: address, amount: u128 }
    mapping balances: address => u128;
    mapping allowances: TokenAllowance => u128;

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let prev = balances.get(caller);
            balances.set(caller, prev - amount);
            let prev_recv = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_recv + amount);
        };
    }
    // ... remaining functions
}
```

### Calling any ARC20 token (dynamic dispatch)

```leo
// Compiler validates args against interface -- recommended
ARC20@(token_id)/transfer_public(recipient, amount);
ARC20@('wrapped_credits')/approve_public(spender, 100u128);
ARC20@('my_token', 'aleo')/transfer_from_public(owner, recipient, amount);

// Low-level intrinsic -- no interface checking
_dynamic_call::[Final](token_id, network_field, fn_selector_field, ...args);
```

### Swap example (token-agnostic exchange)

```leo
program my_exchange.aleo {
    fn swap(
        public token_in: identifier,
        public token_out: identifier,
        public amount_in: u128,
        public amount_out: u128,
    ) -> Final {
        let pull: Final = ARC20@(token_in)/transfer_from_public(
            self.signer, self.address, amount_in
        );
        let push: Final = ARC20@(token_out)/transfer_public(
            self.signer, amount_out
        );
        return final { pull.run(); push.run(); };
    }
}
```

### Private transfer with type-erased records

```leo
fn deposit_private(
    private token_record: dyn record,
    public token_id: identifier,
    public amount: u128,
) -> (dyn record, Final) {
    let (change, f): (dyn record, Final) =
        ARC20@(token_id)/transfer_private_to_public(token_record, self.address, amount);
    return (change, final { f.run(); });
}
```

### Reference implementations

| Program | What it does |
|---------|-------------|
| `wrapped_credits.aleo` | Wraps `credits.aleo` behind ARC20 + MintableToken |
| `wrapped_token_registry.aleo` | Wraps a `token_registry.aleo` token ID behind ARC20 + MintableToken |
| `dummy_exchange.aleo` | Token-agnostic swap using dynamic dispatch |

### Why wrappers exist

```
credits.aleo:         transfer_public(address, u64)         -- wrong types, wrong record name
token_registry.aleo:  transfer_public(field, address, u128) -- extra token_id param
ARC20:                transfer_public(address, u128)         -- the standard
```

Wrappers hold their own `balances` mapping and bridge via deposit/withdraw.

---

## ARC-22: Compliant Fungible Token Standard

Extends ARC-20 for regulated tokens. Same transfer functions, but private transfers require freeze-list Merkle proofs and emit audit records to a designated investigator.

### Interface

```leo
interface ARC20Compliant {
    record Token;
    record ComplianceRecord;
    record Metadata;

    // Public -- freeze list checked in finalize
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;

    // Private -- sender must prove non-inclusion in freeze list
    fn transfer_private(recipient: address, amount: u128, input_record: Token,
        proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(public recipient: address, public amount: u128,
        input_record: Token, proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (Metadata, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128)
        -> (ComplianceRecord, Token, Final);
    fn transfer_from_public_to_private(public owner: address, recipient: address,
        public amount: u128) -> (ComplianceRecord, Token, Final);
    fn shield(public amount: u128) -> (ComplianceRecord, Token, Final);
    fn unshield(public recipient: address, public amount: u128, input_record: Token,
        proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Final);
}
```

### Records

```leo
record Token { owner: address, amount: u128 }

// Emitted on private transfers -- only investigator can decrypt
record ComplianceRecord { owner: address, amount: u128, sender: address, recipient: address }

// Emitted on transfer_private_to_public (amount/recipient already public)
record Metadata { owner: address, sender: address }
```

`owner` is always `INVESTIGATOR_ADDRESS` (hardcoded, changeable only via multisig-gated upgrade).

### Roles (bitmask)

```
MINTER_ROLE  = 1u16    BURNER_ROLE  = 2u16
PAUSE_ROLE   = 4u16    MANAGER_ROLE = 8u16
```

```leo
// Check role
let role: u16 = address_to_role.get(caller);
assert(role & MINTER_ROLE == MINTER_ROLE);

// Assign combined role (MINTER + MANAGER)
address_to_role.set(addr, 9u16);
```

### Freeze list

Sender proves non-inclusion via two adjacent Merkle leaf proofs showing a gap. Windowed root updates keep previous proofs valid for `BLOCK_HEIGHT_WINDOW` blocks.

```leo
// In transfer_private:
let root: field = verify_non_inclusion(input_record.owner, sender_merkle_proofs);
// finalize checks root matches current or previous freeze_list_root
```

### Dynamic dispatch

```leo
// Public functions work dynamically
ARC20Compliant@(token_id)/transfer_public(recipient, amount);

// Private functions need Merkle proofs -- call directly or via static import
```

### On-chain dependencies

`merkle_tree.aleo`, `multisig_core.aleo`, `freezelist.aleo`

### Reference implementations

| Program | What it does |
|---------|-------------|
| `compliant_token_template.aleo` | Full ARC20Compliant: roles, freeze list, pause, multisig upgrades |
| `freezelist.aleo` | Sorted Merkle tree of frozen addresses with windowed root updates |

---

## Directory layout

```
arc-0020/
  wrapped_credits/          -- ARC20 wrapper for credits.aleo
  wrapped_token_registry/   -- ARC20 wrapper for token_registry.aleo
  token_registry/           -- Multi-token registry (pre-existing)
  dummy_exchange/            -- Dynamic dispatch example
  tests/                    -- 21 shared interface tests

arc-0022/
  compliant_token_template/ -- ARC20Compliant reference implementation
  freezelist/               -- On-chain freeze list
  tests/                    -- 24 compliance tests
```
