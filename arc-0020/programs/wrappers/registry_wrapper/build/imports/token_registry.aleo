import credits_clone.aleo;
program token_registry.aleo;

record Token:
    owner as address.private;
    amount as u128.private;
    token_id as field.private;
    external_authorization_required as boolean.private;
    authorized_until as u32.private;

struct TokenMetadata:
    token_id as field;
    name as u128;
    symbol as u128;
    decimals as u8;
    supply as u128;
    max_supply as u128;
    admin as address;
    external_authorization_required as boolean;
    external_authorization_party as address;

struct TokenOwner:
    account as address;
    token_id as field;

struct Balance:
    token_id as field;
    account as address;
    balance as u128;
    authorized_until as u32;

struct Allowance:
    account as address;
    spender as address;
    token_id as field;

mapping registered_tokens:
    key as field.public;
    value as TokenMetadata.public;

mapping balances:
    key as field.public;
    value as Balance.public;

mapping authorized_balances:
    key as field.public;
    value as Balance.public;

mapping allowances:
    key as field.public;
    value as u128.public;

mapping roles:
    key as field.public;
    value as u8.public;

function initialize:
    async initialize into r0;
    output r0 as token_registry.aleo/initialize.future;

finalize initialize:
    contains registered_tokens[3443843282313283355522573239085696902919850365217539366784739393210722344986field] into r0;
    assert.eq r0 false;
    cast 3443843282313283355522573239085696902919850365217539366784739393210722344986field 1095517519u128 1095517519u128 6u8 0u128 10000000000000000u128 wrapped_credits.aleo false token_registry.aleo into r1 as TokenMetadata;
    set r1 into registered_tokens[3443843282313283355522573239085696902919850365217539366784739393210722344986field];

function register_token:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as u128.public;
    input r3 as u8.public;
    input r4 as u128.public;
    input r5 as boolean.public;
    input r6 as address.public;
    is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r7;
    assert.eq r7 true;
    cast r0 r1 r2 r3 0u128 r4 self.caller r5 r6 into r8 as TokenMetadata;
    async register_token r8 into r9;
    output r9 as token_registry.aleo/register_token.future;

finalize register_token:
    input r0 as TokenMetadata.public;
    contains registered_tokens[r0.token_id] into r1;
    assert.eq r1 false;
    set r0 into registered_tokens[r0.token_id];

function update_token_management:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3;
    assert.eq r3 true;
    async update_token_management r0 self.caller r1 r2 into r4;
    output r4 as token_registry.aleo/update_token_management.future;

finalize update_token_management:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as address.public;
    get registered_tokens[r0] into r4;
    assert.eq r1 r4.admin;
    cast r0 r4.name r4.symbol r4.decimals r4.supply r4.max_supply r2 r4.external_authorization_required r3 into r5 as TokenMetadata;
    set r5 into registered_tokens[r0];

function set_role:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u8.public;
    is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3;
    assert.eq r3 true;
    is.eq r2 1u8 into r4;
    is.eq r2 2u8 into r5;
    or r4 r5 into r6;
    is.eq r2 3u8 into r7;
    or r6 r7 into r8;
    assert.eq r8 true;
    cast r1 r0 into r9 as TokenOwner;
    hash.bhp256 r9 into r10 as field;
    async set_role r0 self.caller r10 r2 into r11;
    output r11 as token_registry.aleo/set_role.future;

finalize set_role:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u8.public;
    get registered_tokens[r0] into r4;
    assert.eq r1 r4.admin;
    set r3 into roles[r2];

function remove_role:
    input r0 as field.public;
    input r1 as address.public;
    is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r2;
    assert.eq r2 true;
    cast r1 r0 into r3 as TokenOwner;
    hash.bhp256 r3 into r4 as field;
    async remove_role r0 self.caller r4 into r5;
    output r5 as token_registry.aleo/remove_role.future;

finalize remove_role:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    get registered_tokens[r0] into r3;
    assert.eq r1 r3.admin;
    remove roles[r2];

function mint_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as u32.public;
    cast self.caller r0 into r4 as TokenOwner;
    hash.bhp256 r4 into r5 as field;
    cast r1 r0 into r6 as TokenOwner;
    hash.bhp256 r6 into r7 as field;
    async mint_public r0 self.caller r5 r2 r1 r3 r7 into r8;
    output r8 as token_registry.aleo/mint_public.future;

finalize mint_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    input r4 as address.public;
    input r5 as u32.public;
    input r6 as field.public;
    get registered_tokens[r0] into r7;
    is.eq r1 r7.admin into r8;
    not r8 into r9;
    branch.eq r9 false to end_then_0_20;
    get roles[r2] into r10;
    is.eq r10 1u8 into r11;
    is.eq r10 3u8 into r12;
    or r11 r12 into r13;
    assert.eq r13 true;
    branch.eq true true to end_otherwise_0_21;
    position end_then_0_20;
    position end_otherwise_0_21;
    add r7.supply r3 into r14;
    lte r14 r7.max_supply into r15;
    assert.eq r15 true;
    cast r0 r4 0u128 r5 into r16 as Balance;
    get.or_use balances[r6] r16 into r17;
    get.or_use authorized_balances[r6] r16 into r18;
    ternary r7.external_authorization_required r17.token_id r18.token_id into r19;
    ternary r7.external_authorization_required r17.account r18.account into r20;
    ternary r7.external_authorization_required r17.balance r18.balance into r21;
    ternary r7.external_authorization_required r17.authorized_until r18.authorized_until into r22;
    cast r19 r20 r21 r22 into r23 as Balance;
    add r23.balance r3 into r24;
    cast r0 r4 r24 r23.authorized_until into r25 as Balance;
    branch.eq r7.external_authorization_required false to end_then_0_22;
    set r25 into balances[r6];
    branch.eq true true to end_otherwise_0_23;
    position end_then_0_22;
    set r25 into authorized_balances[r6];
    position end_otherwise_0_23;
    cast r0 r7.name r7.symbol r7.decimals r14 r7.max_supply r7.admin r7.external_authorization_required r7.external_authorization_party into r26 as TokenMetadata;
    set r26 into registered_tokens[r0];

function mint_private:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    input r3 as boolean.public;
    input r4 as u32.public;
    cast r1 r2 r0 r3 r4 into r5 as Token.record;
    cast self.caller r0 into r6 as TokenOwner;
    hash.bhp256 r6 into r7 as field;
    async mint_private r0 self.caller r7 r2 r3 r4 into r8;
    output r5 as Token.record;
    output r8 as token_registry.aleo/mint_private.future;

finalize mint_private:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    input r4 as boolean.public;
    input r5 as u32.public;
    get registered_tokens[r0] into r6;
    is.eq r1 r6.admin into r7;
    not r7 into r8;
    branch.eq r8 false to end_then_0_24;
    get roles[r2] into r9;
    is.eq r9 1u8 into r10;
    is.eq r9 3u8 into r11;
    or r10 r11 into r12;
    assert.eq r12 true;
    branch.eq true true to end_otherwise_0_25;
    position end_then_0_24;
    position end_otherwise_0_25;
    add r6.supply r3 into r13;
    lte r13 r6.max_supply into r14;
    assert.eq r14 true;
    assert.eq r6.external_authorization_required r4;
    is.eq r5 0u32 into r15;
    not r6.external_authorization_required into r16;
    or r15 r16 into r17;
    assert.eq r17 true;
    cast r0 r6.name r6.symbol r6.decimals r13 r6.max_supply r6.admin r6.external_authorization_required r6.external_authorization_party into r18 as TokenMetadata;
    set r18 into registered_tokens[r0];

function burn_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r1 r0 into r3 as TokenOwner;
    hash.bhp256 r3 into r4 as field;
    cast self.caller r0 into r5 as TokenOwner;
    hash.bhp256 r5 into r6 as field;
    async burn_public r0 self.caller r6 r2 r3 r4 into r7;
    output r7 as token_registry.aleo/burn_public.future;

finalize burn_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    input r4 as TokenOwner.public;
    input r5 as field.public;
    get registered_tokens[r0] into r6;
    is.neq r1 r6.admin into r7;
    branch.eq r7 false to end_then_0_26;
    get roles[r2] into r8;
    is.eq r8 2u8 into r9;
    is.eq r8 3u8 into r10;
    or r9 r10 into r11;
    assert.eq r11 true;
    branch.eq true true to end_otherwise_0_27;
    position end_then_0_26;
    position end_otherwise_0_27;
    sub r6.supply r3 into r12;
    cast r6.token_id r6.name r6.symbol r6.decimals r12 r6.max_supply r6.admin r6.external_authorization_required r6.external_authorization_party into r13 as TokenMetadata;
    set r13 into registered_tokens[r4.token_id];
    cast r4.token_id r4.account 0u128 0u32 into r14 as Balance;
    get.or_use authorized_balances[r5] r14 into r15;
    gt r15.balance r3 into r16;
    branch.eq r16 false to end_then_0_28;
    sub r15.balance r3 into r17;
    cast r4.token_id r4.account r17 r15.authorized_until into r18 as Balance;
    set r18 into authorized_balances[r5];
    branch.eq true true to end_otherwise_0_29;
    position end_then_0_28;
    sub r3 r15.balance into r19;
    cast r4.token_id r4.account 0u128 r15.authorized_until into r20 as Balance;
    set r20 into authorized_balances[r5];
    gt r19 0u128 into r21;
    branch.eq r21 false to end_then_1_30;
    get balances[r5] into r22;
    sub r22.balance r19 into r23;
    cast r4.token_id r4.account r23 r22.authorized_until into r24 as Balance;
    set r24 into balances[r5];
    branch.eq true true to end_otherwise_1_31;
    position end_then_1_30;
    position end_otherwise_1_31;
    position end_otherwise_0_29;

function burn_private:
    input r0 as Token.record;
    input r1 as u128.public;
    sub r0.amount r1 into r2;
    cast r0.owner r2 r0.token_id r0.external_authorization_required r0.authorized_until into r3 as Token.record;
    cast self.caller r0.token_id into r4 as TokenOwner;
    hash.bhp256 r4 into r5 as field;
    async burn_private r0.token_id self.caller r5 r1 into r6;
    output r3 as Token.record;
    output r6 as token_registry.aleo/burn_private.future;

finalize burn_private:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    get registered_tokens[r0] into r4;
    is.eq r1 r4.admin into r5;
    not r5 into r6;
    branch.eq r6 false to end_then_0_32;
    get roles[r2] into r7;
    is.eq r7 2u8 into r8;
    is.eq r7 3u8 into r9;
    or r8 r9 into r10;
    assert.eq r10 true;
    branch.eq true true to end_otherwise_0_33;
    position end_then_0_32;
    position end_otherwise_0_33;
    sub r4.supply r3 into r11;
    cast r0 r4.name r4.symbol r4.decimals r11 r4.max_supply r4.admin r4.external_authorization_required r4.external_authorization_party into r12 as TokenMetadata;
    set r12 into registered_tokens[r0];

function prehook_public:
    input r0 as TokenOwner.public;
    input r1 as u128.public;
    input r2 as u32.public;
    hash.bhp256 r0 into r3 as field;
    async prehook_public r0 self.caller r3 r1 r2 into r4;
    output r4 as token_registry.aleo/prehook_public.future;

finalize prehook_public:
    input r0 as TokenOwner.public;
    input r1 as address.public;
    input r2 as field.public;
    input r3 as u128.public;
    input r4 as u32.public;
    get registered_tokens[r0.token_id] into r5;
    assert.eq r5.external_authorization_required true;
    is.eq r1 r5.external_authorization_party into r6;
    assert.eq r6 true;
    cast r0.token_id r0.account 0u128 0u32 into r7 as Balance;
    get.or_use balances[r2] r7 into r8;
    get.or_use authorized_balances[r2] r7 into r9;
    lt r9.authorized_until block.height into r10;
    add r8.balance r9.balance into r11;
    ternary r10 r11 r8.balance into r12;
    ternary r10 0u128 r9.balance into r13;
    sub r12 r3 into r14;
    add r13 r3 into r15;
    cast r0.token_id r0.account r15 r4 into r16 as Balance;
    set r16 into authorized_balances[r2];
    cast r0.token_id r0.account r14 r8.authorized_until into r17 as Balance;
    set r17 into balances[r2];

function prehook_private:
    input r0 as Token.record;
    input r1 as u128.private;
    input r2 as u32.private;
    sub r0.amount r1 into r3;
    cast r0.owner r3 r0.token_id r0.external_authorization_required r0.authorized_until into r4 as Token.record;
    cast r0.owner r1 r0.token_id r0.external_authorization_required r2 into r5 as Token.record;
    async prehook_private r0.token_id self.caller into r6;
    output r4 as Token.record;
    output r5 as Token.record;
    output r6 as token_registry.aleo/prehook_private.future;

finalize prehook_private:
    input r0 as field.public;
    input r1 as address.public;
    get registered_tokens[r0] into r2;
    is.eq r1 r2.external_authorization_party into r3;
    assert.eq r3 true;

function transfer_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast self.caller r0 into r3 as TokenOwner;
    hash.bhp256 r3 into r4 as field;
    cast r1 r0 into r5 as TokenOwner;
    hash.bhp256 r5 into r6 as field;
    async transfer_public r4 r0 self.caller r2 r1 r6 into r7;
    output r7 as token_registry.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as address.public;
    input r3 as u128.public;
    input r4 as address.public;
    input r5 as field.public;
    get authorized_balances[r0] into r6;
    get registered_tokens[r1] into r7;
    lte block.height r6.authorized_until into r8;
    not r7.external_authorization_required into r9;
    or r8 r9 into r10;
    assert.eq r10 true;
    sub r6.balance r3 into r11;
    cast r1 r2 r11 r6.authorized_until into r12 as Balance;
    set r12 into authorized_balances[r0];
    get registered_tokens[r1] into r13;
    ternary r13.external_authorization_required 0u32 4294967295u32 into r14;
    cast r1 r4 0u128 r14 into r15 as Balance;
    get.or_use balances[r5] r15 into r16;
    get.or_use authorized_balances[r5] r15 into r17;
    ternary r13.external_authorization_required r16.token_id r17.token_id into r18;
    ternary r13.external_authorization_required r16.account r17.account into r19;
    ternary r13.external_authorization_required r16.balance r17.balance into r20;
    ternary r13.external_authorization_required r16.authorized_until r17.authorized_until into r21;
    cast r18 r19 r20 r21 into r22 as Balance;
    add r22.balance r3 into r23;
    cast r1 r4 r23 r22.authorized_until into r24 as Balance;
    branch.eq r13.external_authorization_required false to end_then_0_34;
    set r24 into balances[r5];
    branch.eq true true to end_otherwise_0_35;
    position end_then_0_34;
    set r24 into authorized_balances[r5];
    position end_otherwise_0_35;

function transfer_public_as_signer:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast self.signer r0 into r3 as TokenOwner;
    hash.bhp256 r3 into r4 as field;
    cast r1 r0 into r5 as TokenOwner;
    hash.bhp256 r5 into r6 as field;
    async transfer_public_as_signer r4 r0 self.signer r2 r1 r6 into r7;
    output r7 as token_registry.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as address.public;
    input r3 as u128.public;
    input r4 as address.public;
    input r5 as field.public;
    get authorized_balances[r0] into r6;
    get registered_tokens[r1] into r7;
    lte block.height r6.authorized_until into r8;
    not r7.external_authorization_required into r9;
    or r8 r9 into r10;
    assert.eq r10 true;
    sub r6.balance r3 into r11;
    cast r1 r2 r11 r6.authorized_until into r12 as Balance;
    set r12 into authorized_balances[r0];
    get registered_tokens[r1] into r13;
    ternary r13.external_authorization_required 0u32 4294967295u32 into r14;
    cast r1 r4 0u128 r14 into r15 as Balance;
    get.or_use balances[r5] r15 into r16;
    get.or_use authorized_balances[r5] r15 into r17;
    ternary r13.external_authorization_required r16.token_id r17.token_id into r18;
    ternary r13.external_authorization_required r16.account r17.account into r19;
    ternary r13.external_authorization_required r16.balance r17.balance into r20;
    ternary r13.external_authorization_required r16.authorized_until r17.authorized_until into r21;
    cast r18 r19 r20 r21 into r22 as Balance;
    add r22.balance r3 into r23;
    cast r1 r4 r23 r22.authorized_until into r24 as Balance;
    branch.eq r13.external_authorization_required false to end_then_0_36;
    set r24 into balances[r5];
    branch.eq true true to end_otherwise_0_37;
    position end_then_0_36;
    set r24 into authorized_balances[r5];
    position end_otherwise_0_37;

function approve_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast self.caller r1 r0 into r3 as Allowance;
    hash.bhp256 r3 into r4 as field;
    async approve_public r4 r2 into r5;
    output r5 as token_registry.aleo/approve_public.future;

finalize approve_public:
    input r0 as field.public;
    input r1 as u128.public;
    get.or_use allowances[r0] 0u128 into r2;
    add r2 r1 into r3;
    set r3 into allowances[r0];

function unapprove_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast self.caller r1 r0 into r3 as Allowance;
    hash.bhp256 r3 into r4 as field;
    async unapprove_public r4 r2 into r5;
    output r5 as token_registry.aleo/unapprove_public.future;

finalize unapprove_public:
    input r0 as field.public;
    input r1 as u128.public;
    get allowances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into allowances[r0];

function transfer_from_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as u128.public;
    cast r1 self.caller r0 into r4 as Allowance;
    hash.bhp256 r4 into r5 as field;
    cast r1 r0 into r6 as TokenOwner;
    hash.bhp256 r6 into r7 as field;
    cast r2 r0 into r8 as TokenOwner;
    hash.bhp256 r8 into r9 as field;
    async transfer_from_public r5 r3 r7 r0 r1 r2 r9 into r10;
    output r10 as token_registry.aleo/transfer_from_public.future;

finalize transfer_from_public:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    input r3 as field.public;
    input r4 as address.public;
    input r5 as address.public;
    input r6 as field.public;
    get allowances[r0] into r7;
    sub r7 r1 into r8;
    set r8 into allowances[r0];
    get authorized_balances[r2] into r9;
    get registered_tokens[r3] into r10;
    lte block.height r9.authorized_until into r11;
    not r10.external_authorization_required into r12;
    or r11 r12 into r13;
    assert.eq r13 true;
    sub r9.balance r1 into r14;
    cast r3 r4 r14 r9.authorized_until into r15 as Balance;
    set r15 into authorized_balances[r2];
    get registered_tokens[r3] into r16;
    ternary r16.external_authorization_required 0u32 4294967295u32 into r17;
    cast r3 r5 0u128 r17 into r18 as Balance;
    get.or_use balances[r6] r18 into r19;
    get.or_use authorized_balances[r6] r18 into r20;
    ternary r16.external_authorization_required r19.token_id r20.token_id into r21;
    ternary r16.external_authorization_required r19.account r20.account into r22;
    ternary r16.external_authorization_required r19.balance r20.balance into r23;
    ternary r16.external_authorization_required r19.authorized_until r20.authorized_until into r24;
    cast r21 r22 r23 r24 into r25 as Balance;
    add r25.balance r1 into r26;
    cast r3 r5 r26 r25.authorized_until into r27 as Balance;
    branch.eq r16.external_authorization_required false to end_then_0_38;
    set r27 into balances[r6];
    branch.eq true true to end_otherwise_0_39;
    position end_then_0_38;
    set r27 into authorized_balances[r6];
    position end_otherwise_0_39;

function transfer_public_to_private:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    input r3 as boolean.public;
    ternary r3 0u32 4294967295u32 into r4;
    cast r1 r2 r0 r3 r4 into r5 as Token.record;
    cast self.caller r0 into r6 as TokenOwner;
    hash.bhp256 r6 into r7 as field;
    async transfer_public_to_private r0 r3 r7 self.caller r2 into r8;
    output r5 as Token.record;
    output r8 as token_registry.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as field.public;
    input r1 as boolean.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as u128.public;
    get registered_tokens[r0] into r5;
    assert.eq r5.external_authorization_required r1;
    get authorized_balances[r2] into r6;
    get registered_tokens[r0] into r7;
    lte block.height r6.authorized_until into r8;
    not r7.external_authorization_required into r9;
    or r8 r9 into r10;
    assert.eq r10 true;
    sub r6.balance r4 into r11;
    cast r0 r3 r11 r6.authorized_until into r12 as Balance;
    set r12 into authorized_balances[r2];

function transfer_from_public_to_private:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.private;
    input r3 as u128.public;
    input r4 as boolean.public;
    ternary r4 0u32 4294967295u32 into r5;
    cast r2 r3 r0 r4 r5 into r6 as Token.record;
    cast r1 self.caller r0 into r7 as Allowance;
    hash.bhp256 r7 into r8 as field;
    cast r1 r0 into r9 as TokenOwner;
    hash.bhp256 r9 into r10 as field;
    async transfer_from_public_to_private r0 r4 r8 r3 r10 r1 into r11;
    output r6 as Token.record;
    output r11 as token_registry.aleo/transfer_from_public_to_private.future;

finalize transfer_from_public_to_private:
    input r0 as field.public;
    input r1 as boolean.public;
    input r2 as field.public;
    input r3 as u128.public;
    input r4 as field.public;
    input r5 as address.public;
    get registered_tokens[r0] into r6;
    assert.eq r6.external_authorization_required r1;
    get allowances[r2] into r7;
    sub r7 r3 into r8;
    set r8 into allowances[r2];
    get authorized_balances[r4] into r9;
    get registered_tokens[r0] into r10;
    lte block.height r9.authorized_until into r11;
    not r10.external_authorization_required into r12;
    or r11 r12 into r13;
    assert.eq r13 true;
    sub r9.balance r3 into r14;
    cast r0 r5 r14 r9.authorized_until into r15 as Balance;
    set r15 into authorized_balances[r4];

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as Token.record;
    sub r2.amount r1 into r3;
    cast r2.owner r3 r2.token_id r2.external_authorization_required r2.authorized_until into r4 as Token.record;
    ternary r2.external_authorization_required 0u32 4294967295u32 into r5;
    cast r0 r1 r2.token_id r2.external_authorization_required r5 into r6 as Token.record;
    async transfer_private r2.authorized_until r2.external_authorization_required into r7;
    output r4 as Token.record;
    output r6 as Token.record;
    output r7 as token_registry.aleo/transfer_private.future;

finalize transfer_private:
    input r0 as u32.public;
    input r1 as boolean.public;
    lte block.height r0 into r2;
    not r1 into r3;
    or r2 r3 into r4;
    assert.eq r4 true;

function transfer_private_to_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as Token.record;
    sub r2.amount r1 into r3;
    cast r2.owner r3 r2.token_id r2.external_authorization_required r2.authorized_until into r4 as Token.record;
    cast r0 r2.token_id into r5 as TokenOwner;
    hash.bhp256 r5 into r6 as field;
    async transfer_private_to_public r2.authorized_until r2.external_authorization_required r2.token_id r0 r6 r1 into r7;
    output r4 as Token.record;
    output r7 as token_registry.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as u32.public;
    input r1 as boolean.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as field.public;
    input r5 as u128.public;
    lte block.height r0 into r6;
    not r1 into r7;
    or r6 r7 into r8;
    assert.eq r8 true;
    get registered_tokens[r2] into r9;
    ternary r9.external_authorization_required 0u32 4294967295u32 into r10;
    cast r2 r3 0u128 r10 into r11 as Balance;
    get.or_use balances[r4] r11 into r12;
    get.or_use authorized_balances[r4] r11 into r13;
    ternary r9.external_authorization_required r12.token_id r13.token_id into r14;
    ternary r9.external_authorization_required r12.account r13.account into r15;
    ternary r9.external_authorization_required r12.balance r13.balance into r16;
    ternary r9.external_authorization_required r12.authorized_until r13.authorized_until into r17;
    cast r14 r15 r16 r17 into r18 as Balance;
    add r18.balance r5 into r19;
    cast r2 r3 r19 r18.authorized_until into r20 as Balance;
    branch.eq r9.external_authorization_required false to end_then_0_40;
    set r20 into balances[r4];
    branch.eq true true to end_otherwise_0_41;
    position end_then_0_40;
    set r20 into authorized_balances[r4];
    position end_otherwise_0_41;

function join:
    input r0 as Token.record;
    input r1 as Token.record;
    is.eq r0.token_id r1.token_id into r2;
    assert.eq r2 true;
    add r0.amount r1.amount into r3;
    lt r0.authorized_until r1.authorized_until into r4;
    ternary r4 r0.authorized_until r1.authorized_until into r5;
    cast r0.owner r3 r0.token_id r0.external_authorization_required r5 into r6 as Token.record;
    output r6 as Token.record;

function split:
    input r0 as Token.record;
    input r1 as u128.private;
    gte r0.amount r1 into r2;
    assert.eq r2 true;
    cast r0.owner r1 r0.token_id r0.external_authorization_required r0.authorized_until into r3 as Token.record;
    sub r0.amount r1 into r4;
    cast r0.owner r4 r0.token_id r0.external_authorization_required r0.authorized_until into r5 as Token.record;
    output r3 as Token.record;
    output r5 as Token.record;

constructor:
    assert.eq edition 0u16;
