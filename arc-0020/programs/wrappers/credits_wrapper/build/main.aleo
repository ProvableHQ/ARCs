import credits_clone.aleo;
import merkle_tree.aleo;
import token_interface.aleo;
program credits_wrapper.aleo;

record Token:
    owner as address.private;
    amount as u128.private;

function transfer_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r2 into r3 as u64;
    call credits_clone.aleo/transfer_public r1 r3 into r4;
    async transfer_public r4 into r5;
    output r5 as credits_wrapper.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as credits_clone.aleo/transfer_public.future;
    await r0;

function transfer_public_as_signer:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r2 into r3 as u64;
    call credits_clone.aleo/transfer_public_as_signer r1 r3 into r4;
    async transfer_public_as_signer r4 into r5;
    output r5 as credits_wrapper.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as credits_clone.aleo/transfer_public_as_signer.future;
    await r0;

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

function transfer_public_to_private:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    cast r2 into r3 as u64;
    cast r1 r2 into r4 as Token.record;
    call credits_clone.aleo/transfer_public_as_signer credits_wrapper.aleo r3 into r5;
    async transfer_public_to_private r5 into r6;
    output r4 as Token.record;
    output r6 as credits_wrapper.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as credits_clone.aleo/transfer_public_as_signer.future;
    await r0;

function transfer_private_to_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as Token.record;
    sub r2.amount r1 into r3;
    cast r2.owner r3 into r4 as Token.record;
    cast r1 into r5 as u64;
    call credits_clone.aleo/transfer_public r0 r5 into r6;
    async transfer_private_to_public r6 into r7;
    output r4 as Token.record;
    output r7 as credits_wrapper.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as credits_clone.aleo/transfer_public.future;
    await r0;

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as Token.record;
    cast r0 r1 into r3 as Token.record;
    sub r2.amount r1 into r4;
    cast r2.owner r4 into r5 as Token.record;
    async transfer_private into r6;
    output r3 as Token.record;
    output r5 as Token.record;
    output r6 as credits_wrapper.aleo/transfer_private.future;

finalize transfer_private:
    assert.eq true true;
