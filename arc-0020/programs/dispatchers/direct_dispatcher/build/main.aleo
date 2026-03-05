program direct_dispatcher.aleo;

struct MerkleProof:
    siblings as [field; 16u32];
    leaf_index as u32;

struct TokenRoute:
    program_id as field;
    network_id as field;
    convention as u8;

mapping token_routes:
    key as field.public;
    value as TokenRoute.public;

function register_route:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u8.public;
    async register_route r1 r2 r3 r0 into r4;
    output r4 as direct_dispatcher.aleo/register_route.future;

finalize register_route:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u8.public;
    input r3 as field.public;
    cast r0 r1 r2 into r4 as TokenRoute;
    set r4 into token_routes[r3];

function dispatch_f_a_u:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as address.public;
    input r5 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as field.private address.private u128.private) into r6 (as dynamic.future);
    async dispatch_f_a_u r6 into r7;
    output r7 as direct_dispatcher.aleo/dispatch_f_a_u.future;

finalize dispatch_f_a_u:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u128.private) into r5 (as dynamic.future);
    async dispatch_a_u r5 into r6;
    output r6 as direct_dispatcher.aleo/dispatch_a_u.future;

finalize dispatch_a_u:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u64:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u64.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u64.private) into r5 (as dynamic.future);
    async dispatch_a_u64 r5 into r6;
    output r6 as direct_dispatcher.aleo/dispatch_a_u64.future;

finalize dispatch_a_u64:
    input r0 as dynamic.future;
    await r0;

function dispatch_a:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    call.dynamic r0 r1 r2 with r3 (as address.private) into r4 (as dynamic.future);
    async dispatch_a r4 into r5;
    output r5 as direct_dispatcher.aleo/dispatch_a.future;

finalize dispatch_a:
    input r0 as dynamic.future;
    await r0;

function dispatch_bool:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as boolean.public;
    call.dynamic r0 r1 r2 with r3 (as boolean.private) into r4 (as dynamic.future);
    async dispatch_bool r4 into r5;
    output r5 as direct_dispatcher.aleo/dispatch_bool.future;

finalize dispatch_bool:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_a_u:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as address.public;
    input r5 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as address.private address.private u128.private) into r6 (as dynamic.future);
    async dispatch_a_a_u r6 into r7;
    output r7 as direct_dispatcher.aleo/dispatch_a_a_u.future;

finalize dispatch_a_a_u:
    input r0 as dynamic.future;
    await r0;

function dispatch_f_a_a_u:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as address.public;
    input r5 as address.public;
    input r6 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as field.private address.private address.private u128.private) into r7 (as dynamic.future);
    async dispatch_f_a_a_u r7 into r8;
    output r8 as direct_dispatcher.aleo/dispatch_f_a_a_u.future;

finalize dispatch_f_a_a_u:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u16:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u16.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u16.private) into r5 (as dynamic.future);
    async dispatch_a_u16 r5 into r6;
    output r6 as direct_dispatcher.aleo/dispatch_a_u16.future;

finalize dispatch_a_u16:
    input r0 as dynamic.future;
    await r0;

function dispatch_r_r_to_r:
    input r0 as dynamic.record;
    input r1 as dynamic.record;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as field.public;
    call.dynamic r2 r3 r4 with r0 r1 (as dynamic.record dynamic.record) into r5 (as dynamic.record);
    output r5 as dynamic.record;

function dispatch_r_to_r:
    input r0 as dynamic.record;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as field.public;
    call.dynamic r1 r2 r3 with r0 (as dynamic.record) into r4 (as dynamic.record);
    output r4 as dynamic.record;

function dispatch_r_u_to_rr:
    input r0 as dynamic.record;
    input r1 as u128.private;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as field.public;
    call.dynamic r2 r3 r4 with r0 r1 (as dynamic.record u128.private) into r5 r6 (as dynamic.record dynamic.record);
    output r5 as dynamic.record;
    output r6 as dynamic.record;

function dispatch_r_u64_to_rr:
    input r0 as dynamic.record;
    input r1 as u64.private;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as field.public;
    call.dynamic r2 r3 r4 with r0 r1 (as dynamic.record u64.private) into r5 r6 (as dynamic.record dynamic.record);
    output r5 as dynamic.record;
    output r6 as dynamic.record;

function dispatch_f_a_u_to_r_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as address.private;
    input r5 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as field.private address.private u128.private) into r6 r7 (as dynamic.record dynamic.future);
    async dispatch_f_a_u_to_r_f r7 into r8;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_f_a_u_to_r_f.future;

finalize dispatch_f_a_u_to_r_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_to_r_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u128.private) into r5 r6 (as dynamic.record dynamic.future);
    async dispatch_a_u_to_r_f r6 into r7;
    output r5 as dynamic.record;
    output r7 as direct_dispatcher.aleo/dispatch_a_u_to_r_f.future;

finalize dispatch_a_u_to_r_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_to_r_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u128.public;
    input r5 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as address.private u128.private dynamic.record) into r6 r7 (as dynamic.record dynamic.future);
    async dispatch_a_u_r_to_r_f r7 into r8;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_a_u_r_to_r_f.future;

finalize dispatch_a_u_r_to_r_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u64_r_to_r_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u64.public;
    input r5 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as address.private u64.private dynamic.record) into r6 r7 (as dynamic.record dynamic.future);
    async dispatch_a_u64_r_to_r_f r7 into r8;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_a_u64_r_to_r_f.future;

finalize dispatch_a_u64_r_to_r_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u64_to_r_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u64.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u64.private) into r5 r6 (as dynamic.record dynamic.future);
    async dispatch_a_u64_to_r_f r6 into r7;
    output r5 as dynamic.record;
    output r7 as direct_dispatcher.aleo/dispatch_a_u64_to_r_f.future;

finalize dispatch_a_u64_to_r_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_to_rr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as address.private u128.private dynamic.record) into r6 r7 r8 (as dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_to_rr_f r8 into r9;
    output r6 as dynamic.record;
    output r7 as dynamic.record;
    output r9 as direct_dispatcher.aleo/dispatch_a_u_r_to_rr_f.future;

finalize dispatch_a_u_r_to_rr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_to_rr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    call.dynamic r0 r1 r2 with r3 r4 (as address.private u128.private) into r5 r6 r7 (as dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_to_rr_f r7 into r8;
    output r5 as dynamic.record;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_a_u_to_rr_f.future;

finalize dispatch_a_u_to_rr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_proofs_to_rr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as [MerkleProof; 2u32].public;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record [MerkleProof; 2u32].private) into r7 r8 r9 (as dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_proofs_to_rr_f r9 into r10;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r10 as direct_dispatcher.aleo/dispatch_a_u_r_proofs_to_rr_f.future;

finalize dispatch_a_u_r_proofs_to_rr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_r_u_to_rr_f:
    input r0 as dynamic.record;
    input r1 as u128.public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as field.public;
    call.dynamic r2 r3 r4 with r0 r1 (as dynamic.record u128.private) into r5 r6 r7 (as dynamic.record dynamic.record dynamic.future);
    async dispatch_r_u_to_rr_f r7 into r8;
    output r5 as dynamic.record;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_r_u_to_rr_f.future;

finalize dispatch_r_u_to_rr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_to_rrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 (as address.private u128.private dynamic.record) into r6 r7 r8 r9 (as dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_to_rrr_f r9 into r10;
    output r6 as dynamic.record;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r10 as direct_dispatcher.aleo/dispatch_a_u_r_to_rrr_f.future;

finalize dispatch_a_u_r_to_rrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_proofs_to_rrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as [MerkleProof; 2u32].public;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record [MerkleProof; 2u32].private) into r7 r8 r9 r10 (as dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_proofs_to_rrr_f r10 into r11;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r9 as dynamic.record;
    output r11 as direct_dispatcher.aleo/dispatch_a_u_r_proofs_to_rrr_f.future;

finalize dispatch_a_u_r_proofs_to_rrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_r_to_rrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record dynamic.record) into r7 r8 r9 r10 (as dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_r_to_rrr_f r10 into r11;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r9 as dynamic.record;
    output r11 as direct_dispatcher.aleo/dispatch_a_u_r_r_to_rrr_f.future;

finalize dispatch_a_u_r_r_to_rrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_r_to_rrrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record dynamic.record) into r7 r8 r9 r10 r11 (as dynamic.record dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_r_to_rrrr_f r11 into r12;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r9 as dynamic.record;
    output r10 as dynamic.record;
    output r12 as direct_dispatcher.aleo/dispatch_a_u_r_r_to_rrrr_f.future;

finalize dispatch_a_u_r_r_to_rrrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_proofs_to_rrrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as [MerkleProof; 2u32].public;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record [MerkleProof; 2u32].private) into r7 r8 r9 r10 r11 (as dynamic.record dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_proofs_to_rrrr_f r11 into r12;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r9 as dynamic.record;
    output r10 as dynamic.record;
    output r12 as direct_dispatcher.aleo/dispatch_a_u_r_proofs_to_rrrr_f.future;

finalize dispatch_a_u_r_proofs_to_rrrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_a_u_r_r_to_rrrrr_f:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.private;
    input r4 as u128.public;
    input r5 as dynamic.record;
    input r6 as dynamic.record;
    call.dynamic r0 r1 r2 with r3 r4 r5 r6 (as address.private u128.private dynamic.record dynamic.record) into r7 r8 r9 r10 r11 r12 (as dynamic.record dynamic.record dynamic.record dynamic.record dynamic.record dynamic.future);
    async dispatch_a_u_r_r_to_rrrrr_f r12 into r13;
    output r7 as dynamic.record;
    output r8 as dynamic.record;
    output r9 as dynamic.record;
    output r10 as dynamic.record;
    output r11 as dynamic.record;
    output r13 as direct_dispatcher.aleo/dispatch_a_u_r_r_to_rrrrr_f.future;

finalize dispatch_a_u_r_r_to_rrrrr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_r_proofs_to_rr_f:
    input r0 as dynamic.record;
    input r1 as [MerkleProof; 2u32].public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as field.public;
    call.dynamic r2 r3 r4 with r0 r1 (as dynamic.record [MerkleProof; 2u32].private) into r5 r6 r7 (as dynamic.record dynamic.record dynamic.future);
    async dispatch_r_proofs_to_rr_f r7 into r8;
    output r5 as dynamic.record;
    output r6 as dynamic.record;
    output r8 as direct_dispatcher.aleo/dispatch_r_proofs_to_rr_f.future;

finalize dispatch_r_proofs_to_rr_f:
    input r0 as dynamic.future;
    await r0;

function dispatch_proofs_to_r_f:
    input r0 as [MerkleProof; 2u32].public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as field.public;
    call.dynamic r1 r2 r3 with r0 (as [MerkleProof; 2u32].private) into r4 r5 (as dynamic.record dynamic.future);
    async dispatch_proofs_to_r_f r5 into r6;
    output r4 as dynamic.record;
    output r6 as direct_dispatcher.aleo/dispatch_proofs_to_r_f.future;

finalize dispatch_proofs_to_r_f:
    input r0 as dynamic.future;
    await r0;
