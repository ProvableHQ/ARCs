import credits_clone.aleo;
import token_registry.aleo;
import merkle_tree.aleo;
import token_interface.aleo;
program registry_wrapper.aleo;

record Token:
    owner as address.private;
    amount as u128.private;
    token_id as field.private;

struct BalanceKey:
    account as address;
    token_id as field;

mapping balances:
    key as field.public;
    value as u128.public;

function deposit:
    input r0 as field.public;
    input r1 as u128.public;
    cast self.signer r0 into r2 as BalanceKey;
    hash.bhp256 r2 into r3 as field;
    call token_registry.aleo/transfer_public_as_signer r0 registry_wrapper.aleo r1 into r4;
    async deposit r4 r3 r1 into r5;
    output r5 as registry_wrapper.aleo/deposit.future;

finalize deposit:
    input r0 as token_registry.aleo/transfer_public_as_signer.future;
    input r1 as field.public;
    input r2 as u128.public;
    await r0;
    get.or_use balances[r1] 0u128 into r3;
    add r3 r2 into r4;
    set r4 into balances[r1];

function withdraw:
    input r0 as field.public;
    input r1 as u128.public;
    cast self.caller r0 into r2 as BalanceKey;
    hash.bhp256 r2 into r3 as field;
    call token_registry.aleo/transfer_public r0 self.caller r1 into r4;
    async withdraw r4 r3 r1 into r5;
    output r5 as registry_wrapper.aleo/withdraw.future;

finalize withdraw:
    input r0 as token_registry.aleo/transfer_public.future;
    input r1 as field.public;
    input r2 as u128.public;
    await r0;
    get balances[r1] into r3;
    sub r3 r2 into r4;
    set r4 into balances[r1];

function withdraw_as_signer:
    input r0 as field.public;
    input r1 as u128.public;
    cast self.signer r0 into r2 as BalanceKey;
    hash.bhp256 r2 into r3 as field;
    call token_registry.aleo/transfer_public r0 self.signer r1 into r4;
    async withdraw_as_signer r4 r3 r1 into r5;
    output r5 as registry_wrapper.aleo/withdraw_as_signer.future;

finalize withdraw_as_signer:
    input r0 as token_registry.aleo/transfer_public.future;
    input r1 as field.public;
    input r2 as u128.public;
    await r0;
    get balances[r1] into r3;
    sub r3 r2 into r4;
    set r4 into balances[r1];

function transfer_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast self.caller r0 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;
    cast r1 r0 into r5 as BalanceKey;
    hash.bhp256 r5 into r6 as field;
    async transfer_public r4 r2 r6 into r7;
    output r7 as registry_wrapper.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
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
    cast self.signer r0 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;
    cast r1 r0 into r5 as BalanceKey;
    hash.bhp256 r5 into r6 as field;
    async transfer_public_as_signer r4 r2 r6 into r7;
    output r7 as registry_wrapper.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    get balances[r0] into r3;
    sub r3 r1 into r4;
    set r4 into balances[r0];
    get.or_use balances[r2] 0u128 into r5;
    add r5 r1 into r6;
    set r6 into balances[r2];

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
    cast self.signer r0 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;
    cast r1 r2 r0 into r5 as Token.record;
    async shield r4 r2 into r6;
    output r5 as Token.record;
    output r6 as registry_wrapper.aleo/shield.future;

finalize shield:
    input r0 as field.public;
    input r1 as u128.public;
    get balances[r0] into r2;
    sub r2 r1 into r3;
    set r3 into balances[r0];

function unshield:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as Token.record;
    cast r0 r2.token_id into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;
    sub r2.amount r1 into r5;
    cast r2.owner r5 r2.token_id into r6 as Token.record;
    async unshield r4 r1 into r7;
    output r6 as Token.record;
    output r7 as registry_wrapper.aleo/unshield.future;

finalize unshield:
    input r0 as field.public;
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
    output r6 as registry_wrapper.aleo/transfer_private.future;

finalize transfer_private:
    assert.eq true true;

constructor:
    assert.eq edition 0u16;
