import credits.aleo;
program wrapped_credits.aleo;

record Token:
    owner as address.private;
    amount as u128.private;

struct TokenInfo:
    name as u128;
    symbol as u128;
    decimals as u8;
    supply as u128;
    max_supply as u128;

struct TokenAllowance:
    account as address;
    spender as address;

mapping balances:
    key as address.public;
    value as u128.public;

mapping token_info:
    key as boolean.public;
    value as TokenInfo.public;

mapping allowances:
    key as TokenAllowance.public;
    value as u128.public;

function deposit_credits_public:
    input r0 as u64.public;
    call credits.aleo/transfer_public_as_signer wrapped_credits.aleo r0 into r1;
    async deposit_credits_public r1 self.signer r0 into r2;
    output r2 as wrapped_credits.aleo/deposit_credits_public.future;

finalize deposit_credits_public:
    input r0 as credits.aleo/transfer_public_as_signer.future;
    input r1 as address.public;
    input r2 as u64.public;
    await r0;
    get.or_use balances[r1] 0u128 into r3;
    cast r2 into r4 as u128;
    add r3 r4 into r5;
    set r5 into balances[r1];

function deposit_credits_private:
    input r0 as credits.aleo/credits.record;
    input r1 as u64.private;
    call credits.aleo/transfer_private_to_public r0 wrapped_credits.aleo r1 into r2 r3;
    cast r1 into r4 as u128;
    cast self.signer r4 into r5 as Token.record;
    async deposit_credits_private r3 into r6;
    output r2 as credits.aleo/credits.record;
    output r5 as Token.record;
    output r6 as wrapped_credits.aleo/deposit_credits_private.future;

finalize deposit_credits_private:
    input r0 as credits.aleo/transfer_private_to_public.future;
    await r0;

function withdraw_credits_public:
    input r0 as u64.private;
    call credits.aleo/transfer_public self.caller r0 into r1;
    async withdraw_credits_public self.caller r0 r1 into r2;
    output r2 as wrapped_credits.aleo/withdraw_credits_public.future;

finalize withdraw_credits_public:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as credits.aleo/transfer_public.future;
    get balances[r0] into r3;
    cast r1 into r4 as u128;
    sub r3 r4 into r5;
    set r5 into balances[r0];
    await r2;

function withdraw_credits_public_signer:
    input r0 as u64.private;
    call credits.aleo/transfer_public self.signer r0 into r1;
    async withdraw_credits_public_signer self.signer r0 r1 into r2;
    output r2 as wrapped_credits.aleo/withdraw_credits_public_signer.future;

finalize withdraw_credits_public_signer:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as credits.aleo/transfer_public.future;
    get balances[r0] into r3;
    cast r1 into r4 as u128;
    sub r3 r4 into r5;
    set r5 into balances[r0];
    await r2;

function withdraw_credits_private:
    input r0 as Token.record;
    input r1 as u64.private;
    call credits.aleo/transfer_public_to_private r0.owner r1 into r2 r3;
    cast r1 into r4 as u128;
    sub r0.amount r4 into r5;
    cast r0.owner r5 into r6 as Token.record;
    async withdraw_credits_private r3 into r7;
    output r2 as credits.aleo/credits.record;
    output r6 as Token.record;
    output r7 as wrapped_credits.aleo/withdraw_credits_private.future;

finalize withdraw_credits_private:
    input r0 as credits.aleo/transfer_public_to_private.future;
    await r0;

function transfer_public:
    input r0 as address.public;
    input r1 as u128.public;
    async transfer_public self.caller r1 r0 into r2;
    output r2 as wrapped_credits.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as address.public;
    get balances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into balances[r0];
    get.or_use balances[r2] 0u128 into r5;
    add r5 r1 into r6;
    set r6 into balances[r2];

function shield:
    input r0 as u128.public;
    cast self.signer r0 into r1 as Token.record;
    async shield self.signer r0 into r2;
    output r1 as Token.record;
    output r2 as wrapped_credits.aleo/shield.future;

finalize shield:
    input r0 as address.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into balances[r0];

function unshield:
    input r0 as Token.record;
    input r1 as u128.private;
    gte r0.amount r1 into r2;
    assert.eq r2 true;
    cast r1 into r3 as u64;
    call credits.aleo/transfer_public_to_private r0.owner r3 into r4 r5;
    cast r1 into r6 as u64;
    call credits.aleo/transfer_private_to_public r4 r0.owner r6 into r7 r8;
    sub r0.amount r1 into r9;
    cast r0.owner r9 into r10 as Token.record;
    cast r0.owner 0u128 into r11 as Token.record;
    async unshield r5 r8 into r12;
    output r10 as Token.record;
    output r11 as Token.record;
    output r12 as wrapped_credits.aleo/unshield.future;

finalize unshield:
    input r0 as credits.aleo/transfer_public_to_private.future;
    input r1 as credits.aleo/transfer_private_to_public.future;
    await r0;
    await r1;

function transfer_private:
    input r0 as Token.record;
    input r1 as address.private;
    input r2 as u128.private;
    is.eq r0.owner self.signer into r3;
    assert.eq r3 true;
    sub r0.amount r2 into r4;
    cast r0.owner r4 into r5 as Token.record;
    cast r1 r2 into r6 as Token.record;
    output r5 as Token.record;
    output r6 as Token.record;

function transfer_private_to_public:
    input r0 as Token.record;
    input r1 as address.private;
    input r2 as u128.private;
    is.eq r0.owner self.signer into r3;
    assert.eq r3 true;
    sub r0.amount r2 into r4;
    cast r0.owner r4 into r5 as Token.record;
    async transfer_private_to_public r1 r2 into r6;
    output r5 as Token.record;
    output r6 as wrapped_credits.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as address.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    add r2 r1 into r3;
    set r3 into balances[r0];

function approve_public:
    input r0 as address.public;
    input r1 as u128.public;
    cast self.caller r0 into r2 as TokenAllowance;
    async approve_public r2 r1 into r3;
    output r3 as wrapped_credits.aleo/approve_public.future;

finalize approve_public:
    input r0 as TokenAllowance.public;
    input r1 as u128.public;
    get.or_use allowances[r0] 0u128 into r2;
    add r2 r1 into r3;
    set r3 into allowances[r0];

function unapprove_public:
    input r0 as address.public;
    input r1 as u128.public;
    cast self.caller r0 into r2 as TokenAllowance;
    async unapprove_public r2 r1 into r3;
    output r3 as wrapped_credits.aleo/unapprove_public.future;

finalize unapprove_public:
    input r0 as TokenAllowance.public;
    input r1 as u128.public;
    get allowances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into allowances[r0];

function transfer_from_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r0 self.caller into r3 as TokenAllowance;
    async transfer_from_public r3 r2 r0 r1 into r4;
    output r4 as wrapped_credits.aleo/transfer_from_public.future;

finalize transfer_from_public:
    input r0 as TokenAllowance.public;
    input r1 as u128.public;
    input r2 as address.public;
    input r3 as address.public;
    get allowances[r0] into r4;
    gte r4 r1 into r5;
    assert.eq r5 true;
    sub r4 r1 into r6;
    set r6 into allowances[r0];
    get balances[r2] into r7;
    sub r7 r1 into r8;
    set r8 into balances[r2];
    get.or_use balances[r3] 0u128 into r9;
    add r9 r1 into r10;
    set r10 into balances[r3];

function transfer_from_public_to_private:
    input r0 as address.public;
    input r1 as u128.public;
    cast r0 self.caller into r2 as TokenAllowance;
    cast self.caller r1 into r3 as Token.record;
    async transfer_from_public_to_private r2 r1 r0 into r4;
    output r3 as Token.record;
    output r4 as wrapped_credits.aleo/transfer_from_public_to_private.future;

finalize transfer_from_public_to_private:
    input r0 as TokenAllowance.public;
    input r1 as u128.public;
    input r2 as address.public;
    get allowances[r0] into r3;
    gte r3 r1 into r4;
    assert.eq r4 true;
    sub r3 r1 into r5;
    set r5 into allowances[r0];
    get balances[r2] into r6;
    sub r6 r1 into r7;
    set r7 into balances[r2];

function transfer_public_as_signer:
    input r0 as address.private;
    input r1 as u128.private;
    async transfer_public_as_signer self.signer r1 r0 into r2;
    output r2 as wrapped_credits.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as address.public;
    get balances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into balances[r0];
    get.or_use balances[r2] 0u128 into r5;
    add r5 r1 into r6;
    set r6 into balances[r2];

function mint_public:
    input r0 as address.public;
    input r1 as u128.public;
    cast r1 into r2 as u64;
    call credits.aleo/transfer_public_as_signer wrapped_credits.aleo r2 into r3;
    async mint_public r3 r0 r1 into r4;
    output r4 as wrapped_credits.aleo/mint_public.future;

finalize mint_public:
    input r0 as credits.aleo/transfer_public_as_signer.future;
    input r1 as address.public;
    input r2 as u128.public;
    await r0;
    get.or_use balances[r1] 0u128 into r3;
    add r3 r2 into r4;
    set r4 into balances[r1];

function mint_private:
    input r0 as address.public;
    input r1 as u128.public;
    cast r0 r1 into r2 as Token.record;
    async mint_private self.signer r1 into r3;
    output r2 as Token.record;
    output r3 as wrapped_credits.aleo/mint_private.future;

finalize mint_private:
    input r0 as address.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into balances[r0];

function burn_public:
    input r0 as u128.public;
    cast r0 into r1 as u64;
    call credits.aleo/transfer_public self.caller r1 into r2;
    async burn_public self.caller r0 r2 into r3;
    output r3 as wrapped_credits.aleo/burn_public.future;

finalize burn_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as credits.aleo/transfer_public.future;
    get balances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into balances[r0];
    await r2;

function burn_private:
    input r0 as Token.record;
    is.eq r0.owner self.signer into r1;
    assert.eq r1 true;
    cast r0.amount into r2 as u64;
    call credits.aleo/transfer_public_to_private r0.owner r2 into r3 r4;
    async burn_private r4 into r5;
    output r5 as wrapped_credits.aleo/burn_private.future;

finalize burn_private:
    input r0 as credits.aleo/transfer_public_to_private.future;
    await r0;

constructor:
    assert.eq edition 0u16;
