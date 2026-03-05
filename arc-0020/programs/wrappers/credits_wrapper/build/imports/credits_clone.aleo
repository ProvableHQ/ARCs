program credits_clone.aleo;

record credits:
    owner as address.private;
    microcredits as u64.private;

struct committee_state:
    is_open as boolean;
    commission as u8;

struct bond_state:
    validator as address;
    microcredits as u64;

struct unbond_state:
    microcredits as u64;
    height as u32;

mapping committee:
    key as address.public;
    value as committee_state.public;

mapping delegated:
    key as address.public;
    value as u64.public;

mapping metadata:
    key as address.public;
    value as u32.public;

mapping bonded:
    key as address.public;
    value as bond_state.public;

mapping unbonding:
    key as address.public;
    value as unbond_state.public;

mapping account:
    key as address.public;
    value as u64.public;

mapping withdraw:
    key as address.public;
    value as address.public;

function bond_validator:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as u8.public;
    is.neq self.signer r0 into r3;
    assert.eq r3 true;
    gte r1 1000000u64 into r4;
    assert.eq r4 true;
    lte r2 100u8 into r5;
    assert.eq r5 true;
    async bond_validator self.signer r0 r2 r1 into r6;
    output r6 as credits_clone.aleo/bond_validator.future;

finalize bond_validator:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u8.public;
    input r3 as u64.public;
    get.or_use withdraw[r0] r1 into r4;
    is.eq r1 r4 into r5;
    assert.eq r5 true;
    cast true r2 into r6 as committee_state;
    get.or_use committee[r0] r6 into r7;
    is.eq r2 r7.commission into r8;
    assert.eq r8 true;
    cast r0 0u64 into r9 as bond_state;
    get.or_use bonded[r0] r9 into r10;
    is.eq r10.validator r0 into r11;
    assert.eq r11 true;
    add r10.microcredits r3 into r12;
    cast r0 r12 into r13 as bond_state;
    get.or_use delegated[r0] 0u64 into r14;
    add r3 r14 into r15;
    gte r15 10000000000000u64 into r16;
    assert.eq r16 true;
    get account[r0] into r17;
    sub r17 r3 into r18;
    contains committee[r0] into r19;
    not r19 into r20;
    branch.eq r20 false to end_then_0_0;
    set r4 into withdraw[r0];
    gte r3 100000000u64 into r21;
    assert.eq r21 true;
    get.or_use metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc] 0u32 into r22;
    add r22 1u32 into r23;
    set r23 into metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    contains unbonding[r0] into r24;
    not r24 into r25;
    assert.eq r25 true;
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    position end_otherwise_0_1;
    set r7 into committee[r0];
    set r15 into delegated[r0];
    set r13 into bonded[r0];
    set r18 into account[r0];

function bond_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    gte r2 1000000u64 into r3;
    assert.eq r3 true;
    is.neq self.caller r0 into r4;
    assert.eq r4 true;
    async bond_public self.caller r1 r0 r2 into r5;
    output r5 as credits_clone.aleo/bond_public.future;

finalize bond_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as u64.public;
    get.or_use withdraw[r0] r1 into r4;
    is.eq r1 r4 into r5;
    assert.eq r5 true;
    contains bonded[r0] into r6;
    not r6 into r7;
    branch.eq r7 false to end_then_0_2;
    set r1 into withdraw[r0];
    cast true 0u8 into r8 as committee_state;
    get.or_use committee[r2] r8 into r9;
    assert.eq r9.is_open true;
    get.or_use metadata[aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0] 0u32 into r10;
    add r10 1u32 into r11;
    lte r11 100000u32 into r12;
    assert.eq r12 true;
    set r11 into metadata[aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0];
    branch.eq true true to end_otherwise_0_3;
    position end_then_0_2;
    position end_otherwise_0_3;
    cast r2 0u64 into r13 as bond_state;
    get.or_use bonded[r0] r13 into r14;
    is.eq r14.validator r2 into r15;
    assert.eq r15 true;
    add r14.microcredits r3 into r16;
    gte r16 10000000000u64 into r17;
    assert.eq r17 true;
    cast r2 r16 into r18 as bond_state;
    get account[r0] into r19;
    sub r19 r3 into r20;
    get.or_use delegated[r2] 0u64 into r21;
    add r3 r21 into r22;
    contains unbonding[r2] into r23;
    not r23 into r24;
    assert.eq r24 true;
    set r18 into bonded[r0];
    set r20 into account[r0];
    set r22 into delegated[r2];

function unbond_public:
    input r0 as address.public;
    input r1 as u64.public;
    async unbond_public r0 self.caller r1 into r2;
    output r2 as credits_clone.aleo/unbond_public.future;

finalize unbond_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    add block.height 360u32 into r3;
    cast 0u64 r3 into r4 as unbond_state;
    get bonded[r0] into r5;
    get withdraw[r0] into r6;
    is.eq r1 r6 into r7;
    contains withdraw[r5.validator] into r8;
    get.or_use withdraw[r5.validator] aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r9;
    is.eq r1 r9 into r10;
    and r8 r10 into r11;
    or r7 r11 into r12;
    assert.eq r12 true;
    is.eq r5.validator r0 into r13;
    not r13 into r14;
    branch.eq r14 false to end_then_0_4;
    get.or_use unbonding[r0] r4 into r15;
    get delegated[r5.validator] into r16;
    sub r5.microcredits r2 into r17;
    lt r17 10000000000u64 into r18;
    or r11 r18 into r19;
    ternary r19 r5.microcredits r2 into r20;
    add r15.microcredits r20 into r21;
    cast r21 r3 into r22 as unbond_state;
    set r22 into unbonding[r0];
    sub r16 r20 into r23;
    set r23 into delegated[r5.validator];
    not r19 into r24;
    branch.eq r24 false to end_then_1_6;
    cast r5.validator r17 into r25 as bond_state;
    set r25 into bonded[r0];
    branch.eq true true to end_otherwise_1_7;
    position end_then_1_6;
    remove bonded[r0];
    get metadata[aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0] into r26;
    sub r26 1u32 into r27;
    set r27 into metadata[aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0];
    position end_otherwise_1_7;
    gte r23 10000000000000u64 into r28;
    not r28 into r29;
    branch.eq r29 false to end_then_1_8;
    contains committee[r5.validator] into r30;
    branch.eq r30 false to end_then_2_10;
    get bonded[r5.validator] into r31;
    get delegated[r5.validator] into r32;
    remove committee[r5.validator];
    get metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc] into r33;
    sub r33 1u32 into r34;
    set r34 into metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    sub r32 r31.microcredits into r35;
    set r35 into delegated[r5.validator];
    remove bonded[r5.validator];
    get.or_use unbonding[r5.validator] r4 into r36;
    add r31.microcredits r36.microcredits into r37;
    cast r37 r3 into r38 as unbond_state;
    set r38 into unbonding[r5.validator];
    branch.eq true true to end_otherwise_2_11;
    position end_then_2_10;
    position end_otherwise_2_11;
    branch.eq true true to end_otherwise_1_9;
    position end_then_1_8;
    position end_otherwise_1_9;
    branch.eq true true to end_otherwise_0_5;
    position end_then_0_4;
    contains committee[r5.validator] into r39;
    branch.eq r39 false to end_then_1_12;
    get bonded[r5.validator] into r40;
    get delegated[r5.validator] into r41;
    lt r41 10000000000000u64 into r42;
    not r42 into r43;
    branch.eq r43 false to end_then_2_14;
    sub r41 r2 into r44;
    sub r40.microcredits r2 into r45;
    gte r45 100000000u64 into r46;
    gte r44 10000000000000u64 into r47;
    and r46 r47 into r48;
    branch.eq r48 false to end_then_3_16;
    get.or_use unbonding[r5.validator] r4 into r49;
    add r49.microcredits r2 into r50;
    cast r50 r3 into r51 as unbond_state;
    set r51 into unbonding[r5.validator];
    set r44 into delegated[r5.validator];
    cast r5.validator r45 into r52 as bond_state;
    set r52 into bonded[r5.validator];
    branch.eq true true to end_otherwise_3_17;
    position end_then_3_16;
    remove committee[r5.validator];
    get metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc] into r53;
    sub r53 1u32 into r54;
    set r54 into metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    sub r41 r40.microcredits into r55;
    set r55 into delegated[r5.validator];
    remove bonded[r5.validator];
    get.or_use unbonding[r5.validator] r4 into r56;
    add r40.microcredits r56.microcredits into r57;
    cast r57 r3 into r58 as unbond_state;
    set r58 into unbonding[r5.validator];
    position end_otherwise_3_17;
    branch.eq true true to end_otherwise_2_15;
    position end_then_2_14;
    remove committee[r5.validator];
    get metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc] into r59;
    sub r59 1u32 into r60;
    set r60 into metadata[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    sub r41 r40.microcredits into r61;
    set r61 into delegated[r5.validator];
    remove bonded[r5.validator];
    get.or_use unbonding[r5.validator] r4 into r62;
    add r40.microcredits r62.microcredits into r63;
    cast r63 r3 into r64 as unbond_state;
    set r64 into unbonding[r5.validator];
    position end_otherwise_2_15;
    branch.eq true true to end_otherwise_1_13;
    position end_then_1_12;
    position end_otherwise_1_13;
    position end_otherwise_0_5;

function claim_unbond_public:
    input r0 as address.public;
    async claim_unbond_public r0 into r1;
    output r1 as credits_clone.aleo/claim_unbond_public.future;

finalize claim_unbond_public:
    input r0 as address.public;
    get unbonding[r0] into r1;
    gte block.height r1.height into r2;
    assert.eq r2 true;
    get withdraw[r0] into r3;
    get.or_use account[r3] 0u64 into r4;
    add r4 r1.microcredits into r5;
    set r5 into account[r3];
    remove unbonding[r0];
    contains bonded[r0] into r6;
    not r6 into r7;
    branch.eq r7 false to end_then_0_18;
    remove withdraw[r0];
    branch.eq true true to end_otherwise_0_19;
    position end_then_0_18;
    position end_otherwise_0_19;

function set_validator_state:
    input r0 as boolean.public;
    async set_validator_state self.caller r0 into r1;
    output r1 as credits_clone.aleo/set_validator_state.future;

finalize set_validator_state:
    input r0 as address.public;
    input r1 as boolean.public;
    get committee[r0] into r2;
    cast r1 r2.commission into r3 as committee_state;
    set r3 into committee[r0];

function transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    async transfer_public self.caller r1 r0 into r2;
    output r2 as credits_clone.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as address.public;
    get account[r0] into r3;
    sub r3 r1 into r4;
    set r4 into account[r0];
    get.or_use account[r2] 0u64 into r5;
    add r5 r1 into r6;
    set r6 into account[r2];

function transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u64.public;
    async transfer_public_as_signer self.signer r1 r0 into r2;
    output r2 as credits_clone.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as address.public;
    get account[r0] into r3;
    sub r3 r1 into r4;
    set r4 into account[r0];
    get.or_use account[r2] 0u64 into r5;
    add r5 r1 into r6;
    set r6 into account[r2];

function transfer_private:
    input r0 as credits.record;
    input r1 as address.private;
    input r2 as u64.private;
    cast r1 r2 into r3 as credits.record;
    sub r0.microcredits r2 into r4;
    cast r0.owner r4 into r5 as credits.record;
    output r3 as credits.record;
    output r5 as credits.record;

function transfer_private_to_public:
    input r0 as credits.record;
    input r1 as address.public;
    input r2 as u64.public;
    sub r0.microcredits r2 into r3;
    cast r0.owner r3 into r4 as credits.record;
    async transfer_private_to_public r1 r2 into r5;
    output r4 as credits.record;
    output r5 as credits_clone.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as address.public;
    input r1 as u64.public;
    get.or_use account[r0] 0u64 into r2;
    add r2 r1 into r3;
    set r3 into account[r0];

function transfer_public_to_private:
    input r0 as address.private;
    input r1 as u64.public;
    cast r0 r1 into r2 as credits.record;
    async transfer_public_to_private self.caller r1 into r3;
    output r2 as credits.record;
    output r3 as credits_clone.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as address.public;
    input r1 as u64.public;
    get account[r0] into r2;
    sub r2 r1 into r3;
    set r3 into account[r0];

function join:
    input r0 as credits.record;
    input r1 as credits.record;
    add r0.microcredits r1.microcredits into r2;
    cast r0.owner r2 into r3 as credits.record;
    output r3 as credits.record;

function split:
    input r0 as credits.record;
    input r1 as u64.private;
    cast r0.owner r1 into r2 as credits.record;
    sub r0.microcredits r1 into r3;
    sub r3 10000u64 into r4;
    cast r0.owner r4 into r5 as credits.record;
    output r2 as credits.record;
    output r5 as credits.record;

constructor:
    assert.eq edition 0u16;
