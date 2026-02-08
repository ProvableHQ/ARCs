import credits.aleo;

program wrapped_credits.aleo;

record Token:
    owner as address.private;
    amount as u128.private;

mapping balances:
    key as address.public;
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
    get balances[r1] into r3;
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
    input r0 as address.private;
    input r1 as u128.private;
    async transfer_public self.caller r1 r0 into r2;
    output r2 as wrapped_credits.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as address.public;
    get balances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into balances[r0];
    get balances[r2] into r5;
    add r5 r1 into r6;
    set r6 into balances[r2];

function transfer_public_to_private:
    input r0 as address.private;
    input r1 as u128.private;
    cast r0 r1 into r2 as Token.record;
    async transfer_public_to_private self.caller r1 into r3;
    output r2 as Token.record;
    output r3 as wrapped_credits.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as address.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into balances[r0];

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
    get balances[r2] into r5;
    add r5 r1 into r6;
    set r6 into balances[r2];

constructor:
    assert.eq edition 0u16;
