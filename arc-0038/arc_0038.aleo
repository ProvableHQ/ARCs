import credits.aleo;
program arc_0038.aleo;

struct withdrawal_state:
    microcredits as u64;
    claim_block as u32;


mapping is_initialized:
	key as u8.public;
	value as boolean.public;


mapping commission_percent:
	key as u8.public;
	value as u128.public;


mapping validator:
	key as u8.public;
	value as address.public;


mapping total_balance:
	key as u8.public;
	value as u64.public;


mapping total_shares:
	key as u8.public;
	value as u64.public;


mapping delegator_shares:
	key as address.public;
	value as u64.public;


mapping pending_withdrawal:
	key as u8.public;
	value as u64.public;


mapping current_batch_height:
	key as u8.public;
	value as u32.public;


mapping withdrawals:
	key as address.public;
	value as withdrawal_state.public;

function initialize:
    input r0 as u128.public;
    input r1 as address.public;
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    lt r0 1000u128 into r2;
    assert.eq r2 true;
    lte r0 500u128 into r3;
    assert.eq r3 true;
    async initialize r0 r1 into r4;
    output r4 as arc_0038.aleo/initialize.future;

finalize initialize:
    input r0 as u128.public;
    input r1 as address.public;
    get is_initialized[0u8] into r2;
    assert.eq r2 false;
    set r0 into commission_percent[0u8];
    set r1 into validator[0u8];
    set 0u64 into total_shares[0u8];
    set 0u64 into total_balance[0u8];
    set 0u64 into pending_withdrawal[0u8];
    set 0u32 into current_batch_height[0u8];


function initial_deposit:
    input r0 as credits.aleo/credits.record;
    input r1 as u64.public;
    input r2 as address.public;
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    call credits.aleo/transfer_private_to_public r0 aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny r1 into r3 r4;
    call credits.aleo/bond_public r2 r1 into r5;
    async initial_deposit r4 r5 r1 into r6;
    output r3 as credits.aleo/credits.record;
    output r6 as arc_0038.aleo/initial_deposit.future;

finalize initial_deposit:
    input r0 as credits.aleo/transfer_private_to_public.future;
    input r1 as credits.aleo/bond_public.future;
    input r2 as u64.public;
    await r0;
    await r1;
    get is_initialized[0u8] into r3;
    assert.eq r3 true;
    get.or_use total_balance[0u8] 0u64 into r4;
    get.or_use total_shares[0u8] 0u64 into r5;
    assert.eq r4 0u64;
    assert.eq r5 0u64;
    set r2 into total_balance[0u8];
    mul r2 1_000u64 into r6;
    set r6 into total_shares[0u8];
    set r2 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];






function set_commission_percent:
    input r0 as u128.public;
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    lt r0 1000u128 into r1;
    assert.eq r1 true;
    lte r0 500u128 into r2;
    assert.eq r2 true;
    async set_commission_percent r0 into r3;
    output r3 as arc_0038.aleo/set_commission_percent.future;

finalize set_commission_percent:
    input r0 as u128.public;
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r1 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r1 into r2;
    get total_balance[0u8] into r3;
    get total_shares[0u8] into r4;
    gt r2.microcredits r3 into r5;
    sub r2.microcredits r3 into r6;
    ternary r5 r6 0u64 into r7;
    get commission_percent[0u8] into r8;
    cast r7 into r9 as u128;
    mul r9 r8 into r10;
    div r10 1000u128 into r11;
    cast r11 into r12 as u64;
    sub r7 r12 into r13;
    add r3 r13 into r14;
    cast r14 into r15 as u128;
    cast r12 into r16 as u128;
    cast r4 into r17 as u128;
    mul r17 1000u128 into r18;
    div r18 r15 into r19;
    add r15 r16 into r20;
    mul r20 r19 into r21;
    div r21 1000u128 into r22;
    sub r22 r17 into r23;
    cast r23 into r24 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r25;
    add r25 r24 into r26;
    set r26 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r4 r24 into r27;
    set r27 into total_shares[0u8];
    add r14 r12 into r28;
    set r28 into total_balance[0u8];
    set r0 into commission_percent[0u8];


function set_next_validator:
    input r0 as address.public;
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    async set_next_validator r0 into r1;
    output r1 as arc_0038.aleo/set_next_validator.future;

finalize set_next_validator:
    input r0 as address.public;
    set r0 into validator[1u8];


function unbond_all:
    input r0 as u64.public;
    call credits.aleo/unbond_public r0 into r1;
    async unbond_all r1 r0 into r2;
    output r2 as arc_0038.aleo/unbond_all.future;

finalize unbond_all:
    input r0 as credits.aleo/unbond_public.future;
    input r1 as u64.public;
    await r0;
    contains validator[1u8] into r2;
    assert.eq r2 true;
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r3 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r3 into r4;
    get total_balance[0u8] into r5;
    get total_shares[0u8] into r6;
    gt r4.microcredits r5 into r7;
    sub r4.microcredits r5 into r8;
    ternary r7 r8 0u64 into r9;
    get commission_percent[0u8] into r10;
    cast r9 into r11 as u128;
    mul r11 r10 into r12;
    div r12 1000u128 into r13;
    cast r13 into r14 as u64;
    sub r9 r14 into r15;
    add r5 r15 into r16;
    cast r16 into r17 as u128;
    cast r14 into r18 as u128;
    cast r6 into r19 as u128;
    mul r19 1000u128 into r20;
    div r20 r17 into r21;
    add r17 r18 into r22;
    mul r22 r21 into r23;
    div r23 1000u128 into r24;
    sub r24 r19 into r25;
    cast r25 into r26 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r27;
    add r27 r26 into r28;
    set r28 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r6 r26 into r29;
    set r29 into total_shares[0u8];
    add r16 r14 into r30;
    set r30 into total_balance[0u8];
    sub r4.microcredits r1 into r31;
    lt r31 10_000_000_000u64 into r32;
    assert.eq r32 true;


function claim_unbond:
    call credits.aleo/claim_unbond_public into r0;
    async claim_unbond r0 into r1;
    output r1 as arc_0038.aleo/claim_unbond.future;

finalize claim_unbond:
    input r0 as credits.aleo/claim_unbond_public.future;
    await r0;
    remove current_batch_height[0u8];


function bond_all:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/bond_public r0 r1 into r2;
    async bond_all r2 r0 r1 into r3;
    output r3 as arc_0038.aleo/bond_all.future;

finalize bond_all:
    input r0 as credits.aleo/bond_public.future;
    input r1 as address.public;
    input r2 as u64.public;
    await r0;
    cast 0u64 0u32 into r3 as credits.aleo/unbond_state;
    get.or_use credits.aleo/unbonding[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r3 into r4;
    assert.eq r4.microcredits 0u64;
    get credits.aleo/account[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] into r5;
    get pending_withdrawal[0u8] into r6;
    sub r5 r6 into r7;
    assert.eq r2 r7;
    contains validator[1u8] into r8;
    get validator[1u8] into r9;
    get validator[0u8] into r10;
    ternary r8 r9 r10 into r11;
    assert.eq r1 r11;
    set r11 into validator[0u8];
    remove validator[1u8];


function claim_commission:
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    async claim_commission into r0;
    output r0 as arc_0038.aleo/claim_commission.future;

finalize claim_commission:
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r0 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r0 into r1;
    get total_balance[0u8] into r2;
    get total_shares[0u8] into r3;
    gt r1.microcredits r2 into r4;
    sub r1.microcredits r2 into r5;
    ternary r4 r5 0u64 into r6;
    get commission_percent[0u8] into r7;
    cast r6 into r8 as u128;
    mul r8 r7 into r9;
    div r9 1000u128 into r10;
    cast r10 into r11 as u64;
    sub r6 r11 into r12;
    add r2 r12 into r13;
    cast r13 into r14 as u128;
    cast r11 into r15 as u128;
    cast r3 into r16 as u128;
    mul r16 1000u128 into r17;
    div r17 r14 into r18;
    add r14 r15 into r19;
    mul r19 r18 into r20;
    div r20 1000u128 into r21;
    sub r21 r16 into r22;
    cast r22 into r23 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r24;
    add r24 r23 into r25;
    set r25 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r3 r23 into r26;
    set r26 into total_shares[0u8];
    add r13 r11 into r27;
    set r27 into total_balance[0u8];


function deposit_public:
    input r0 as credits.aleo/credits.record;
    input r1 as u64.public;
    call credits.aleo/transfer_private_to_public r0 aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny r1 into r2 r3;
    async deposit_public r3 self.caller r1 into r4;
    output r2 as credits.aleo/credits.record;
    output r4 as arc_0038.aleo/deposit_public.future;

finalize deposit_public:
    input r0 as credits.aleo/transfer_private_to_public.future;
    input r1 as address.public;
    input r2 as u64.public;
    await r0;
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r3 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r3 into r4;
    get total_balance[0u8] into r5;
    get total_shares[0u8] into r6;
    gt r4.microcredits r5 into r7;
    sub r4.microcredits r5 into r8;
    ternary r7 r8 0u64 into r9;
    get commission_percent[0u8] into r10;
    cast r9 into r11 as u128;
    mul r11 r10 into r12;
    div r12 1000u128 into r13;
    cast r13 into r14 as u64;
    sub r9 r14 into r15;
    add r5 r15 into r16;
    cast r16 into r17 as u128;
    cast r14 into r18 as u128;
    cast r6 into r19 as u128;
    mul r19 1000u128 into r20;
    div r20 r17 into r21;
    add r17 r18 into r22;
    mul r22 r21 into r23;
    div r23 1000u128 into r24;
    sub r24 r19 into r25;
    cast r25 into r26 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r27;
    add r27 r26 into r28;
    set r28 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r6 r26 into r29;
    add r16 r14 into r30;
    cast r30 into r31 as u128;
    cast r2 into r32 as u128;
    cast r29 into r33 as u128;
    mul r33 1000u128 into r34;
    div r34 r31 into r35;
    add r31 r32 into r36;
    mul r36 r35 into r37;
    div r37 1000u128 into r38;
    sub r38 r33 into r39;
    cast r39 into r40 as u64;
    gte r40 1u64 into r41;
    assert.eq r41 true;
    get.or_use delegator_shares[r1] 0u64 into r42;
    add r42 r40 into r43;
    set r43 into delegator_shares[r1];
    add r29 r40 into r44;
    set r44 into total_shares[0u8];
    add r30 r2 into r45;
    set r45 into total_balance[0u8];




function withdraw_public:
    input r0 as u64.public;
    input r1 as u64.public;
    call credits.aleo/unbond_public r1 into r2;
    async withdraw_public r2 r0 r1 self.caller into r3;
    output r3 as arc_0038.aleo/withdraw_public.future;

finalize withdraw_public:
    input r0 as credits.aleo/unbond_public.future;
    input r1 as u64.public;
    input r2 as u64.public;
    input r3 as address.public;
    await r0;
    contains withdrawals[r3] into r4;
    assert.eq r4 false;
    get.or_use current_batch_height[0u8] 0u32 into r5;
    add block.height 360u32 into r6;
    is.eq r5 0u32 into r7;
    gte r5 r6 into r8;
    or r7 r8 into r9;
    assert.eq r9 true;
    get delegator_shares[r3] into r10;
    gte r10 r1 into r11;
    assert.eq r11 true;
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r12 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r12 into r13;
    get total_balance[0u8] into r14;
    get total_shares[0u8] into r15;
    gt r13.microcredits r14 into r16;
    sub r13.microcredits r14 into r17;
    ternary r16 r17 0u64 into r18;
    get commission_percent[0u8] into r19;
    cast r18 into r20 as u128;
    mul r20 r19 into r21;
    div r21 1000u128 into r22;
    cast r22 into r23 as u64;
    sub r18 r23 into r24;
    add r14 r24 into r25;
    cast r25 into r26 as u128;
    cast r23 into r27 as u128;
    cast r15 into r28 as u128;
    mul r28 1000u128 into r29;
    div r29 r26 into r30;
    add r26 r27 into r31;
    mul r31 r30 into r32;
    div r32 1000u128 into r33;
    sub r33 r28 into r34;
    cast r34 into r35 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r36;
    add r36 r35 into r37;
    set r37 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r15 r35 into r38;
    add r25 r23 into r39;
    cast r1 into r40 as u128;
    mul r40 1000u128 into r41;
    cast r38 into r42 as u128;
    div r41 r42 into r43;
    cast r39 into r44 as u128;
    mul r44 r43 into r45;
    div r45 1000u128 into r46;
    cast r2 into r47 as u128;
    gte r46 r47 into r48;
    assert.eq r48 true;
    div block.height 1_000u32 into r49;
    mul r49 1_000u32 into r50;
    add r50 1_000u32 into r51;
    ternary r7 r51 r5 into r52;
    set r52 into current_batch_height[0u8];
    cast r2 r52 into r53 as withdrawal_state;
    set r53 into withdrawals[r3];
    get pending_withdrawal[0u8] into r54;
    add r54 r2 into r55;
    set r55 into pending_withdrawal[0u8];
    sub r39 r2 into r56;
    set r56 into total_balance[0u8];
    sub r38 r1 into r57;
    set r57 into total_shares[0u8];
    sub r10 r1 into r58;
    set r58 into delegator_shares[r3];


function create_withdraw_claim:
    input r0 as u64.public;
    async create_withdraw_claim r0 self.caller into r1;
    output r1 as arc_0038.aleo/create_withdraw_claim.future;

finalize create_withdraw_claim:
    input r0 as u64.public;
    input r1 as address.public;
    contains withdrawals[r1] into r2;
    assert.eq r2 false;
    cast aleo1q6qstg8q8shwqf5m6q5fcenuwsdqsvp4hhsgfnx5chzjm3secyzqt9mxm8 0u64 into r3 as credits.aleo/bond_state;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] r3 into r4;
    assert.eq r4.microcredits 0u64;
    get delegator_shares[r1] into r5;
    gte r5 r0 into r6;
    assert.eq r6 true;
    get total_balance[0u8] into r7;
    get total_shares[0u8] into r8;
    cast r0 into r9 as u128;
    mul r9 1000u128 into r10;
    cast r8 into r11 as u128;
    div r10 r11 into r12;
    cast r7 into r13 as u128;
    mul r13 r12 into r14;
    div r14 1000u128 into r15;
    cast r15 into r16 as u64;
    cast r16 block.height into r17 as withdrawal_state;
    set r17 into withdrawals[r1];
    get pending_withdrawal[0u8] into r18;
    add r18 r16 into r19;
    set r19 into pending_withdrawal[0u8];
    sub r7 r16 into r20;
    set r20 into total_balance[0u8];
    sub r8 r0 into r21;
    set r21 into total_shares[0u8];
    sub r5 r0 into r22;
    set r22 into delegator_shares[r1];


function claim_withdrawal_public:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/transfer_public r0 r1 into r2;
    async claim_withdrawal_public r2 r0 r1 into r3;
    output r3 as arc_0038.aleo/claim_withdrawal_public.future;

finalize claim_withdrawal_public:
    input r0 as credits.aleo/transfer_public.future;
    input r1 as address.public;
    input r2 as u64.public;
    await r0;
    get withdrawals[r1] into r3;
    gte block.height r3.claim_block into r4;
    assert.eq r4 true;
    assert.eq r3.microcredits r2;
    remove withdrawals[r1];
    get pending_withdrawal[0u8] into r5;
    sub r5 r2 into r6;
    set r6 into pending_withdrawal[0u8];