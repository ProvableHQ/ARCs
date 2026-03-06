import credits_clone.aleo;
import token_registry.aleo;
import merkle_tree.aleo;
import token_interface.aleo;
program fixed_registry_wrapper.aleo;

record Token:
    owner as address.private;
    amount as u128.private;
    token_id as field.private;

mapping balances:
    key as address.public;
    value as u128.public;

function deposit:
    input r0 as field.public;
    input r1 as u128.public;
    call token_registry.aleo/transfer_public_as_signer 1field fixed_registry_wrapper.aleo r1 into r2;
    async deposit r2 self.signer r1 into r3;
    output r3 as fixed_registry_wrapper.aleo/deposit.future;

finalize deposit:
    input r0 as token_registry.aleo/transfer_public_as_signer.future;
    input r1 as address.public;
    input r2 as u128.public;
    await r0;
    get.or_use balances[r1] 0u128 into r3;
    add r3 r2 into r4;
    set r4 into balances[r1];

function withdraw:
    input r0 as field.public;
    input r1 as u128.public;
    call token_registry.aleo/transfer_public 1field self.caller r1 into r2;
    async withdraw r2 self.caller r1 into r3;
    output r3 as fixed_registry_wrapper.aleo/withdraw.future;

finalize withdraw:
    input r0 as token_registry.aleo/transfer_public.future;
    input r1 as address.public;
    input r2 as u128.public;
    await r0;
    get balances[r1] into r3;
    sub r3 r2 into r4;
    set r4 into balances[r1];

function transfer_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    async transfer_public self.caller r2 r1 into r3;
    output r3 as fixed_registry_wrapper.aleo/transfer_public.future;

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

function transfer_public_as_signer:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    async transfer_public_as_signer self.signer r2 r1 into r3;
    output r3 as fixed_registry_wrapper.aleo/transfer_public_as_signer.future;

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
    call token_registry.aleo/mint_public 1field r0 r1 0u32 into r2;
    async mint_public r2 into r3;
    output r3 as fixed_registry_wrapper.aleo/mint_public.future;

finalize mint_public:
    input r0 as token_registry.aleo/mint_public.future;
    await r0;

function join:
    input r0 as Token.record;
    input r1 as Token.record;
    assert.eq r0.token_id r1.token_id;
    add r0.amount r1.amount into r2;
    cast r0.owner r2 r0.token_id into r3 as Token.record;
    output r3 as Token.record;

function split:
    input r0 as Token.record;
    input r1 as u128.private;
    cast r0.owner r1 r0.token_id into r2 as Token.record;
    sub r0.amount r1 into r3;
    cast r0.owner r3 r0.token_id into r4 as Token.record;
    output r2 as Token.record;
    output r4 as Token.record;

function shield:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    cast r1 r2 r0 into r3 as Token.record;
    async shield self.signer r2 into r4;
    output r3 as Token.record;
    output r4 as fixed_registry_wrapper.aleo/shield.future;

finalize shield:
    input r0 as address.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into balances[r0];

function unshield:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as Token.record;
    sub r2.amount r1 into r3;
    cast r2.owner r3 r2.token_id into r4 as Token.record;
    async unshield r0 r1 into r5;
    output r4 as Token.record;
    output r5 as fixed_registry_wrapper.aleo/unshield.future;

finalize unshield:
    input r0 as address.public;
    input r1 as u128.public;
    get.or_use balances[r0] 0u128 into r2;
    add r2 r1 into r3;
    set r3 into balances[r0];

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as Token.record;
    cast r0 r1 r2.token_id into r3 as Token.record;
    sub r2.amount r1 into r4;
    cast r2.owner r4 r2.token_id into r5 as Token.record;
    async transfer_private into r6;
    output r3 as Token.record;
    output r5 as Token.record;
    output r6 as fixed_registry_wrapper.aleo/transfer_private.future;

finalize transfer_private:
    assert.eq true true;

function mint_private:
    input r0 as address.private;
    input r1 as u128.public;
    cast r0 r1 1field into r2 as Token.record;
    call token_registry.aleo/mint_public 1field fixed_registry_wrapper.aleo r1 0u32 into r3;
    async mint_private r3 into r4;
    output r2 as Token.record;
    output r4 as fixed_registry_wrapper.aleo/mint_private.future;

finalize mint_private:
    input r0 as token_registry.aleo/mint_public.future;
    await r0;
