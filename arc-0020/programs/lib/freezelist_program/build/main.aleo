import merkle_tree.aleo;
import multisig_core.aleo;
program freezelist_program.aleo;

struct ChecksumEdition:
    checksum as [u8; 32u32];
    edition as u16;

struct WalletSigningOpId:
    wallet_id as address;
    signing_op_id as field;

mapping address_to_role:
    key as address.public;
    value as u16.public;

mapping freeze_list:
    key as address.public;
    value as boolean.public;

mapping freeze_list_index:
    key as u32.public;
    value as address.public;

mapping freeze_list_last_index:
    key as boolean.public;
    value as u32.public;

mapping freeze_list_root:
    key as u8.public;
    value as field.public;

mapping root_updated_height:
    key as boolean.public;
    value as u32.public;

mapping block_height_window:
    key as boolean.public;
    value as u32.public;

function get_signing_op_id_for_deploy:
    input r0 as [u8; 32u32].private;
    input r1 as u16.private;
    cast r0 r1 into r2 as ChecksumEdition;
    hash.bhp256 r2 into r3 as field;
    output r3 as field.private;

function initialize:
    input r0 as address.public;
    input r1 as u32.public;
    async initialize self.caller r0 r1 into r2;
    output r2 as freezelist_program.aleo/initialize.future;

finalize initialize:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u32.public;
    contains freeze_list_root[1u8] into r3;
    assert.eq r3 false;
    assert.eq r0 aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    set 8u16 into address_to_role[r1];
    set r2 into block_height_window[true];
    set 0u32 into freeze_list_last_index[true];
    set 3642222252059314292809609689035560016959342421640560347114299934615987159853field into freeze_list_root[1u8];
    set false into freeze_list[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    set aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into freeze_list_index[0u32];

function update_role:
    input r0 as address.public;
    input r1 as u16.private;
    async update_role self.caller r0 r1 into r2;
    output r2 as freezelist_program.aleo/update_role.future;

finalize update_role:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u16.public;
    get address_to_role[r0] into r3;
    and r3 8u16 into r4;
    is.eq r4 8u16 into r5;
    assert.eq r5 true;
    is.eq r0 r1 into r6;
    branch.eq r6 false to end_then_0_52;
    and r2 8u16 into r7;
    is.eq r7 8u16 into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_53;
    position end_then_0_52;
    position end_otherwise_0_53;
    set r2 into address_to_role[r1];

function update_block_height_window:
    input r0 as u32.public;
    async update_block_height_window self.caller r0 into r1;
    output r1 as freezelist_program.aleo/update_block_height_window.future;

finalize update_block_height_window:
    input r0 as address.public;
    input r1 as u32.public;
    get address_to_role[r0] into r2;
    and r2 16u16 into r3;
    is.eq r3 16u16 into r4;
    assert.eq r4 true;
    set r1 into block_height_window[true];

function update_freeze_list:
    input r0 as address.public;
    input r1 as boolean.public;
    input r2 as u32.public;
    input r3 as field.public;
    input r4 as field.public;
    async update_freeze_list self.caller r3 r4 r0 r1 r2 into r5;
    output r5 as freezelist_program.aleo/update_freeze_list.future;

finalize update_freeze_list:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as boolean.public;
    input r5 as u32.public;
    get address_to_role[r0] into r6;
    and r6 16u16 into r7;
    is.eq r7 16u16 into r8;
    assert.eq r8 true;
    get freeze_list_root[1u8] into r9;
    assert.eq r1 r9;
    set r9 into freeze_list_root[2u8];
    set r2 into freeze_list_root[1u8];
    get.or_use freeze_list[r3] false into r10;
    assert.neq r4 r10;
    set r4 into freeze_list[r3];
    get.or_use freeze_list_index[r5] aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r11;
    branch.eq r4 false to end_then_0_54;
    assert.eq r11 aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    get freeze_list_last_index[true] into r12;
    add r12 1u32 into r13;
    gte r13 r5 into r14;
    assert.eq r14 true;
    lt r12 r5 into r15;
    branch.eq r15 false to end_then_1_56;
    set r5 into freeze_list_last_index[true];
    branch.eq true true to end_otherwise_1_57;
    position end_then_1_56;
    position end_otherwise_1_57;
    set r3 into freeze_list_index[r5];
    branch.eq true true to end_otherwise_0_55;
    position end_then_0_54;
    assert.eq r11 r3;
    set aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into freeze_list_index[r5];
    position end_otherwise_0_55;
    set block.height into root_updated_height[true];

function verify_non_inclusion_pub:
    input r0 as address.public;
    async verify_non_inclusion_pub r0 into r1;
    output r1 as freezelist_program.aleo/verify_non_inclusion_pub.future;

finalize verify_non_inclusion_pub:
    input r0 as address.public;
    get.or_use freeze_list[r0] false into r1;
    assert.eq r1 false;

function verify_non_inclusion_priv:
    input r0 as address.private;
    input r1 as [merkle_tree.aleo/MerkleProof; 2u32].private;
    call merkle_tree.aleo/verify_non_inclusion r0 r1 into r2;
    async verify_non_inclusion_priv r2 into r3;
    output r3 as freezelist_program.aleo/verify_non_inclusion_priv.future;

finalize verify_non_inclusion_priv:
    input r0 as field.public;
    get freeze_list_root[1u8] into r1;
    is.neq r1 r0 into r2;
    branch.eq r2 false to end_then_0_58;
    get freeze_list_root[2u8] into r3;
    assert.eq r0 r3;
    get block_height_window[true] into r4;
    get root_updated_height[true] into r5;
    add r5 r4 into r6;
    gt r6 block.height into r7;
    assert.eq r7 true;
    branch.eq true true to end_otherwise_0_59;
    position end_then_0_58;
    position end_otherwise_0_59;

constructor:
    gt edition 0u16 into r0;
    branch.eq r0 false to end_then_0_60;
    cast checksum edition into r1 as ChecksumEdition;
    hash.bhp256 r1 into r2 as field;
    cast freezelist_program.aleo r2 into r3 as WalletSigningOpId;
    hash.bhp256 r3 into r4 as field;
    contains multisig_core.aleo/completed_signing_ops[r4] into r5;
    assert.eq r5 true;
    branch.eq true true to end_otherwise_0_61;
    position end_then_0_60;
    position end_otherwise_0_61;
