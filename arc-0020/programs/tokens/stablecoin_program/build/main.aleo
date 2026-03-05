import multisig_core.aleo;
import merkle_tree.aleo;
import freezelist_program.aleo;
program stablecoin_program.aleo;

record Token:
    owner as address.private;
    amount as u128.private;

record ComplianceRecord:
    owner as address.private;
    amount as u128.private;
    sender as address.private;
    recipient as address.private;

record Credentials:
    owner as address.private;
    freeze_list_root as field.private;

struct ChecksumEdition:
    checksum as [u8; 32u32];
    edition as u16;

struct TokenInfo:
    name as u128;
    symbol as u128;
    decimals as u8;
    supply as u128;
    max_supply as u128;

struct TokenAllowance:
    account as address;
    spender as address;

mapping token_info:
    key as boolean.public;
    value as TokenInfo.public;

mapping balances:
    key as address.public;
    value as u128.public;

mapping allowances:
    key as field.public;
    value as u128.public;

mapping address_to_role:
    key as address.public;
    value as u16.public;

mapping pause:
    key as boolean.public;
    value as boolean.public;

function get_signing_op_id_for_deploy:
    input r0 as [u8; 32u32].private;
    input r1 as u16.private;
    cast r0 r1 into r2 as ChecksumEdition;
    hash.bhp256 r2 into r3 as field;
    output r3 as field.private;

function update_role:
    input r0 as address.public;
    input r1 as u16.private;
    async update_role self.caller r0 r1 into r2;
    output r2 as stablecoin_program.aleo/update_role.future;

finalize update_role:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u16.public;
    get address_to_role[r0] into r3;
    and r3 8u16 into r4;
    is.eq r4 8u16 into r5;
    assert.eq r5 true;
    is.eq r0 r1 into r6;
    branch.eq r6 false to end_then_0_62;
    and r2 8u16 into r7;
    is.eq r7 8u16 into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_63;
    position end_then_0_62;
    position end_otherwise_0_63;
    set r2 into address_to_role[r1];

function initialize:
    input r0 as u128.public;
    input r1 as u128.public;
    input r2 as u8.public;
    input r3 as u128.public;
    input r4 as address.public;
    async initialize self.caller r4 r0 r1 r2 r3 into r5;
    output r5 as stablecoin_program.aleo/initialize.future;

finalize initialize:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as u128.public;
    input r4 as u8.public;
    input r5 as u128.public;
    contains token_info[true] into r6;
    assert.eq r6 false;
    assert.eq r0 aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    set 8u16 into address_to_role[r1];
    cast r2 r3 r4 0u128 r5 into r7 as TokenInfo;
    set r7 into token_info[true];
    set false into pause[true];

function get_credentials:
    input r0 as [merkle_tree.aleo/MerkleProof; 2u32].private;
    call merkle_tree.aleo/verify_non_inclusion self.signer r0 into r1;
    cast self.signer r1 into r2 as Credentials.record;
    async get_credentials r1 into r3;
    output r2 as Credentials.record;
    output r3 as stablecoin_program.aleo/get_credentials.future;

finalize get_credentials:
    input r0 as field.public;
    get freezelist_program.aleo/freeze_list_root[1u8] into r1;
    get freezelist_program.aleo/block_height_window[true] into r2;
    is.neq r1 r0 into r3;
    branch.eq r3 false to end_then_0_64;
    get freezelist_program.aleo/freeze_list_root[2u8] into r4;
    assert.eq r0 r4;
    get freezelist_program.aleo/root_updated_height[true] into r5;
    add r5 r2 into r6;
    gt r6 block.height into r7;
    assert.eq r7 true;
    branch.eq true true to end_otherwise_0_65;
    position end_then_0_64;
    position end_otherwise_0_65;

function mint_public:
    input r0 as address.public;
    input r1 as u128.public;
    async mint_public self.caller r1 r0 into r2;
    output r2 as stablecoin_program.aleo/mint_public.future;

finalize mint_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as address.public;
    get address_to_role[r0] into r3;
    and r3 1u16 into r4;
    is.eq r4 1u16 into r5;
    assert.eq r5 true;
    get pause[true] into r6;
    assert.eq r6 false;
    get token_info[true] into r7;
    add r7.supply r1 into r8;
    lte r8 r7.max_supply into r9;
    assert.eq r9 true;
    get.or_use balances[r2] 0u128 into r10;
    add r1 r10 into r11;
    set r11 into balances[r2];
    cast r7.name r7.symbol r7.decimals r8 r7.max_supply into r12 as TokenInfo;
    set r12 into token_info[true];

function mint_private:
    input r0 as address.private;
    input r1 as u128.public;
    cast r0 r1 into r2 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc r0 into r3 as ComplianceRecord.record;
    async mint_private self.caller r1 into r4;
    output r3 as ComplianceRecord.record;
    output r2 as Token.record;
    output r4 as stablecoin_program.aleo/mint_private.future;

finalize mint_private:
    input r0 as address.public;
    input r1 as u128.public;
    get address_to_role[r0] into r2;
    and r2 1u16 into r3;
    is.eq r3 1u16 into r4;
    assert.eq r4 true;
    get pause[true] into r5;
    assert.eq r5 false;
    get token_info[true] into r6;
    add r6.supply r1 into r7;
    lte r7 r6.max_supply into r8;
    assert.eq r8 true;
    cast r6.name r6.symbol r6.decimals r7 r6.max_supply into r9 as TokenInfo;
    set r9 into token_info[true];

function burn_public:
    input r0 as address.public;
    input r1 as u128.public;
    async burn_public self.caller r0 r1 into r2;
    output r2 as stablecoin_program.aleo/burn_public.future;

finalize burn_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    get address_to_role[r0] into r3;
    and r3 2u16 into r4;
    is.eq r4 2u16 into r5;
    assert.eq r5 true;
    get pause[true] into r6;
    assert.eq r6 false;
    get balances[r1] into r7;
    sub r7 r2 into r8;
    set r8 into balances[r1];
    get token_info[true] into r9;
    sub r9.supply r2 into r10;
    cast r9.name r9.symbol r9.decimals r10 r9.max_supply into r11 as TokenInfo;
    set r11 into token_info[true];

function burn_private:
    input r0 as Token.record;
    input r1 as u128.public;
    sub r0.amount r1 into r2;
    cast r0.owner r2 into r3 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 r0.owner aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r4 as ComplianceRecord.record;
    async burn_private self.caller r1 into r5;
    output r4 as ComplianceRecord.record;
    output r3 as Token.record;
    output r5 as stablecoin_program.aleo/burn_private.future;

finalize burn_private:
    input r0 as address.public;
    input r1 as u128.public;
    get address_to_role[r0] into r2;
    and r2 2u16 into r3;
    is.eq r3 2u16 into r4;
    assert.eq r4 true;
    get pause[true] into r5;
    assert.eq r5 false;
    get token_info[true] into r6;
    sub r6.supply r1 into r7;
    cast r6.name r6.symbol r6.decimals r7 r6.max_supply into r8 as TokenInfo;
    set r8 into token_info[true];

function transfer_public:
    input r0 as address.public;
    input r1 as u128.public;
    async transfer_public self.caller r0 r1 into r2;
    output r2 as stablecoin_program.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r3;
    assert.eq r3 false;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r4;
    assert.eq r4 false;
    get pause[true] into r5;
    assert.eq r5 false;
    get balances[r0] into r6;
    sub r6 r2 into r7;
    set r7 into balances[r0];
    get.or_use balances[r1] 0u128 into r8;
    add r8 r2 into r9;
    set r9 into balances[r1];

function transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u128.public;
    async transfer_public_as_signer self.signer r0 r1 into r2;
    output r2 as stablecoin_program.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r3;
    assert.eq r3 false;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r4;
    assert.eq r4 false;
    get pause[true] into r5;
    assert.eq r5 false;
    get balances[r0] into r6;
    sub r6 r2 into r7;
    set r7 into balances[r0];
    get.or_use balances[r1] 0u128 into r8;
    add r8 r2 into r9;
    set r9 into balances[r1];

function approve_public:
    input r0 as address.public;
    input r1 as u128.public;
    cast self.caller r0 into r2 as TokenAllowance;
    hash.bhp256 r2 into r3 as field;
    async approve_public r3 r1 into r4;
    output r4 as stablecoin_program.aleo/approve_public.future;

finalize approve_public:
    input r0 as field.public;
    input r1 as u128.public;
    get pause[true] into r2;
    assert.eq r2 false;
    get.or_use allowances[r0] 0u128 into r3;
    add r3 r1 into r4;
    set r4 into allowances[r0];

function unapprove_public:
    input r0 as address.public;
    input r1 as u128.public;
    cast self.caller r0 into r2 as TokenAllowance;
    hash.bhp256 r2 into r3 as field;
    async unapprove_public r3 r1 into r4;
    output r4 as stablecoin_program.aleo/unapprove_public.future;

finalize unapprove_public:
    input r0 as field.public;
    input r1 as u128.public;
    get pause[true] into r2;
    assert.eq r2 false;
    get allowances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into allowances[r0];

function transfer_from_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r0 self.caller into r3 as TokenAllowance;
    hash.bhp256 r3 into r4 as field;
    async transfer_from_public r0 r1 r4 r2 into r5;
    output r5 as stablecoin_program.aleo/transfer_from_public.future;

finalize transfer_from_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r4;
    assert.eq r4 false;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r5;
    assert.eq r5 false;
    get pause[true] into r6;
    assert.eq r6 false;
    get allowances[r2] into r7;
    sub r7 r3 into r8;
    set r8 into allowances[r2];
    get balances[r0] into r9;
    sub r9 r3 into r10;
    set r10 into balances[r0];
    get.or_use balances[r1] 0u128 into r11;
    add r11 r3 into r12;
    set r12 into balances[r1];

function transfer_public_to_private:
    input r0 as address.private;
    input r1 as u128.public;
    cast r0 r1 into r2 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 self.caller r0 into r3 as ComplianceRecord.record;
    async transfer_public_to_private self.caller r1 into r4;
    output r3 as ComplianceRecord.record;
    output r2 as Token.record;
    output r4 as stablecoin_program.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as address.public;
    input r1 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r2;
    assert.eq r2 false;
    get pause[true] into r3;
    assert.eq r3 false;
    get balances[r0] into r4;
    sub r4 r1 into r5;
    set r5 into balances[r0];

function transfer_from_public_to_private:
    input r0 as address.public;
    input r1 as address.private;
    input r2 as u128.public;
    cast r1 r2 into r3 as Token.record;
    cast r0 self.caller into r4 as TokenAllowance;
    hash.bhp256 r4 into r5 as field;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r2 r0 r1 into r6 as ComplianceRecord.record;
    async transfer_from_public_to_private r0 r5 r2 into r7;
    output r6 as ComplianceRecord.record;
    output r3 as Token.record;
    output r7 as stablecoin_program.aleo/transfer_from_public_to_private.future;

finalize transfer_from_public_to_private:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r3;
    assert.eq r3 false;
    get pause[true] into r4;
    assert.eq r4 false;
    get allowances[r1] into r5;
    sub r5 r2 into r6;
    set r6 into allowances[r1];
    get balances[r0] into r7;
    sub r7 r2 into r8;
    set r8 into balances[r0];

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as Token.record;
    input r3 as [merkle_tree.aleo/MerkleProof; 2u32].private;
    call merkle_tree.aleo/verify_non_inclusion r2.owner r3 into r4;
    sub r2.amount r1 into r5;
    cast r2.owner r5 into r6 as Token.record;
    cast r0 r1 into r7 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 r2.owner r0 into r8 as ComplianceRecord.record;
    async transfer_private r4 into r9;
    output r8 as ComplianceRecord.record;
    output r6 as Token.record;
    output r7 as Token.record;
    output r9 as stablecoin_program.aleo/transfer_private.future;

finalize transfer_private:
    input r0 as field.public;
    get pause[true] into r1;
    assert.eq r1 false;
    get freezelist_program.aleo/freeze_list_root[1u8] into r2;
    get freezelist_program.aleo/block_height_window[true] into r3;
    is.neq r2 r0 into r4;
    branch.eq r4 false to end_then_0_66;
    get freezelist_program.aleo/freeze_list_root[2u8] into r5;
    assert.eq r0 r5;
    get freezelist_program.aleo/root_updated_height[true] into r6;
    add r6 r3 into r7;
    gt r7 block.height into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_67;
    position end_then_0_66;
    position end_otherwise_0_67;

function transfer_private_to_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as Token.record;
    input r3 as [merkle_tree.aleo/MerkleProof; 2u32].private;
    call merkle_tree.aleo/verify_non_inclusion r2.owner r3 into r4;
    sub r2.amount r1 into r5;
    cast r2.owner r5 into r6 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 r2.owner r0 into r7 as ComplianceRecord.record;
    async transfer_private_to_public r4 r0 r1 into r8;
    output r7 as ComplianceRecord.record;
    output r6 as Token.record;
    output r8 as stablecoin_program.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    get pause[true] into r3;
    assert.eq r3 false;
    get freezelist_program.aleo/freeze_list_root[1u8] into r4;
    get freezelist_program.aleo/block_height_window[true] into r5;
    is.neq r4 r0 into r6;
    branch.eq r6 false to end_then_0_68;
    get freezelist_program.aleo/freeze_list_root[2u8] into r7;
    assert.eq r0 r7;
    get freezelist_program.aleo/root_updated_height[true] into r8;
    add r8 r5 into r9;
    gt r9 block.height into r10;
    assert.eq r10 true;
    branch.eq true true to end_otherwise_0_69;
    position end_then_0_68;
    position end_otherwise_0_69;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r11;
    assert.eq r11 false;
    get.or_use balances[r1] 0u128 into r12;
    add r12 r2 into r13;
    set r13 into balances[r1];

function set_pause_status:
    input r0 as boolean.private;
    async set_pause_status self.caller r0 into r1;
    output r1 as stablecoin_program.aleo/set_pause_status.future;

finalize set_pause_status:
    input r0 as address.public;
    input r1 as boolean.public;
    get address_to_role[r0] into r2;
    and r2 4u16 into r3;
    is.eq r3 4u16 into r4;
    assert.eq r4 true;
    set r1 into pause[true];

function join:
    input r0 as Token.record;
    input r1 as Token.record;
    add r0.amount r1.amount into r2;
    cast r0.owner r2 into r3 as Token.record;
    output r3 as Token.record;

function split:
    input r0 as Token.record;
    input r1 as u128.private;
    cast r0.owner r1 into r2 as Token.record;
    sub r0.amount r1 into r3;
    cast r0.owner r3 into r4 as Token.record;
    output r2 as Token.record;
    output r4 as Token.record;

function transfer_private_with_creds:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as Token.record;
    input r3 as Credentials.record;
    sub r2.amount r1 into r4;
    cast r2.owner r4 into r5 as Token.record;
    cast r0 r1 into r6 as Token.record;
    cast aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px r1 r2.owner r0 into r7 as ComplianceRecord.record;
    cast r3.owner r3.freeze_list_root into r8 as Credentials.record;
    async transfer_private_with_creds r3.freeze_list_root into r9;
    output r7 as ComplianceRecord.record;
    output r5 as Token.record;
    output r6 as Token.record;
    output r8 as Credentials.record;
    output r9 as stablecoin_program.aleo/transfer_private_with_creds.future;

finalize transfer_private_with_creds:
    input r0 as field.public;
    get pause[true] into r1;
    assert.eq r1 false;
    get freezelist_program.aleo/freeze_list_root[1u8] into r2;
    get freezelist_program.aleo/block_height_window[true] into r3;
    is.neq r2 r0 into r4;
    branch.eq r4 false to end_then_0_70;
    get freezelist_program.aleo/freeze_list_root[2u8] into r5;
    assert.eq r0 r5;
    get freezelist_program.aleo/root_updated_height[true] into r6;
    add r6 r3 into r7;
    gt r7 block.height into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_71;
    position end_then_0_70;
    position end_otherwise_0_71;

constructor:
    gt edition 0u16 into r0;
    branch.eq r0 false to end_then_0_72;
    cast checksum edition into r1 as ChecksumEdition;
    hash.bhp256 r1 into r2 as field;
    cast stablecoin_program.aleo r2 into r3 as multisig_core.aleo/WalletSigningOpId;
    hash.bhp256 r3 into r4 as field;
    contains multisig_core.aleo/completed_signing_ops[r4] into r5;
    assert.eq r5 true;
    branch.eq true true to end_otherwise_0_73;
    position end_then_0_72;
    position end_otherwise_0_73;
