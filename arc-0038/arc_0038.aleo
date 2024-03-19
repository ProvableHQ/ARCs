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
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r1;
    get total_balance[0u8] into r2;
    get total_shares[0u8] into r3;
    gt r1 r2 into r4;
    sub r1 r2 into r5;
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
    set r7 into commission_percent[0u8];


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
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
    get total_balance[0u8] into r4;
    get total_shares[0u8] into r5;
    gt r3 r4 into r6;
    sub r3 r4 into r7;
    ternary r6 r7 0u64 into r8;
    get commission_percent[0u8] into r9;
    cast r8 into r10 as u128;
    mul r10 r9 into r11;
    div r11 1000u128 into r12;
    cast r12 into r13 as u64;
    sub r8 r13 into r14;
    add r4 r14 into r15;
    cast r15 into r16 as u128;
    cast r13 into r17 as u128;
    cast r5 into r18 as u128;
    mul r18 1000u128 into r19;
    div r19 r16 into r20;
    add r16 r17 into r21;
    mul r21 r20 into r22;
    div r22 1000u128 into r23;
    sub r23 r18 into r24;
    cast r24 into r25 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r26;
    add r26 r25 into r27;
    set r27 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r5 r25 into r28;
    set r28 into total_shares[0u8];
    add r15 r13 into r29;
    set r29 into total_balance[0u8];
    sub r3 r1 into r30;
    lt r30 10_000_000_000u64 into r31;
    assert.eq r31 true;


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
    get.or_use credits.aleo/unbonding[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
    assert.eq r3 0u64;
    get.or_use credits.aleo/account[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r4;
    get pending_withdrawal[0u8] into r5;
    sub r4 r5 into r6;
    assert.eq r2 r6;
    contains validator[1u8] into r7;
    get validator[1u8] into r8;
    get validator[0u8] into r9;
    ternary r7 r8 r9 into r10;
    assert.eq r1 r10;
    set r10 into validator[0u8];
    remove validator[1u8];


function claim_commission:
    assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
    async claim_commission into r0;
    output r0 as arc_0038.aleo/claim_commission.future;

finalize claim_commission:
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r0;
    get total_balance[0u8] into r1;
    get total_shares[0u8] into r2;
    gt r0 r1 into r3;
    sub r0 r1 into r4;
    ternary r3 r4 0u64 into r5;
    get commission_percent[0u8] into r6;
    cast r5 into r7 as u128;
    mul r7 r6 into r8;
    div r8 1000u128 into r9;
    cast r9 into r10 as u64;
    sub r5 r10 into r11;
    add r1 r11 into r12;
    cast r12 into r13 as u128;
    cast r10 into r14 as u128;
    cast r2 into r15 as u128;
    mul r15 1000u128 into r16;
    div r16 r13 into r17;
    add r13 r14 into r18;
    mul r18 r17 into r19;
    div r19 1000u128 into r20;
    sub r20 r15 into r21;
    cast r21 into r22 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r23;
    add r23 r22 into r24;
    set r24 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r2 r22 into r25;
    set r25 into total_shares[0u8];
    add r12 r10 into r26;
    set r26 into total_balance[0u8];


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
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
    get total_balance[0u8] into r4;
    get total_shares[0u8] into r5;
    gt r3 r4 into r6;
    sub r3 r4 into r7;
    ternary r6 r7 0u64 into r8;
    get commission_percent[0u8] into r9;
    cast r8 into r10 as u128;
    mul r10 r9 into r11;
    div r11 1000u128 into r12;
    cast r12 into r13 as u64;
    sub r8 r13 into r14;
    add r4 r14 into r15;
    cast r15 into r16 as u128;
    cast r13 into r17 as u128;
    cast r5 into r18 as u128;
    mul r18 1000u128 into r19;
    div r19 r16 into r20;
    add r16 r17 into r21;
    mul r21 r20 into r22;
    div r22 1000u128 into r23;
    sub r23 r18 into r24;
    cast r24 into r25 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r26;
    add r26 r25 into r27;
    set r27 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r5 r25 into r28;
    add r15 r13 into r29;
    cast r29 into r30 as u128;
    cast r2 into r31 as u128;
    cast r28 into r32 as u128;
    mul r32 1000u128 into r33;
    div r33 r30 into r34;
    add r30 r31 into r35;
    mul r35 r34 into r36;
    div r36 1000u128 into r37;
    sub r37 r32 into r38;
    cast r38 into r39 as u64;
    gte r39 1u64 into r40;
    assert.eq r40 true;
    get.or_use delegator_shares[r1] 0u64 into r41;
    add r41 r39 into r42;
    set r42 into delegator_shares[r1];
    add r28 r39 into r43;
    set r43 into total_shares[0u8];
    add r29 r2 into r44;
    set r44 into total_balance[0u8];




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
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r12;
    get total_balance[0u8] into r13;
    get total_shares[0u8] into r14;
    gt r12 r13 into r15;
    sub r12 r13 into r16;
    ternary r15 r16 0u64 into r17;
    get commission_percent[0u8] into r18;
    cast r17 into r19 as u128;
    mul r19 r18 into r20;
    div r20 1000u128 into r21;
    cast r21 into r22 as u64;
    sub r17 r22 into r23;
    add r13 r23 into r24;
    cast r24 into r25 as u128;
    cast r22 into r26 as u128;
    cast r14 into r27 as u128;
    mul r27 1000u128 into r28;
    div r28 r25 into r29;
    add r25 r26 into r30;
    mul r30 r29 into r31;
    div r31 1000u128 into r32;
    sub r32 r27 into r33;
    cast r33 into r34 as u64;
    get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r35;
    add r35 r34 into r36;
    set r36 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
    add r14 r34 into r37;
    add r24 r22 into r38;
    cast r1 into r39 as u128;
    mul r39 1000u128 into r40;
    cast r37 into r41 as u128;
    div r40 r41 into r42;
    cast r38 into r43 as u128;
    mul r43 r42 into r44;
    div r44 1000u128 into r45;
    cast r2 into r46 as u128;
    gte r45 r46 into r47;
    assert.eq r47 true;
    div block.height 1_000u32 into r48;
    mul r48 1_000u32 into r49;
    add r49 1_000u32 into r50;
    ternary r7 r50 r5 into r51;
    set r51 into current_batch_height[0u8];
    cast r2 r51 into r52 as withdrawal_state;
    set r52 into withdrawals[r3];
    get pending_withdrawal[0u8] into r53;
    add r53 r2 into r54;
    set r54 into pending_withdrawal[0u8];
    sub r38 r2 into r55;
    set r55 into total_balance[0u8];
    sub r37 r1 into r56;
    set r56 into total_shares[0u8];
    sub r10 r1 into r57;
    set r57 into delegator_shares[r3];


function create_withdraw_claim:
    input r0 as u64.public;
    async create_withdraw_claim r0 self.caller into r1;
    output r1 as arc_0038.aleo/create_withdraw_claim.future;

finalize create_withdraw_claim:
    input r0 as u64.public;
    input r1 as address.public;
    contains withdrawals[r1] into r2;
    assert.eq r2 false;
    get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
    assert.eq r3 0u64;
    get delegator_shares[r1] into r4;
    gte r4 r0 into r5;
    assert.eq r5 true;
    get total_balance[0u8] into r6;
    get total_shares[0u8] into r7;
    cast r0 into r8 as u128;
    mul r8 1000u128 into r9;
    cast r7 into r10 as u128;
    div r9 r10 into r11;
    cast r6 into r12 as u128;
    mul r12 r11 into r13;
    div r13 1000u128 into r14;
    cast r14 into r15 as u64;
    cast r15 block.height into r16 as withdrawal_state;
    set r16 into withdrawals[r1];
    get pending_withdrawal[0u8] into r17;
    add r17 r15 into r18;
    set r18 into pending_withdrawal[0u8];
    sub r6 r15 into r19;
    set r19 into total_balance[0u8];
    sub r7 r0 into r20;
    set r20 into total_shares[0u8];
    sub r4 r0 into r21;
    set r21 into delegator_shares[r1];


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
