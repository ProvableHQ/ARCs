program dummy_exchange.aleo;

function transfer_from:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as u128.public;
    call.dynamic r0 'aleo' 'transfer_from_public' with r1 r2 r3 (as address.public address.public u128.public) into r4 (as dynamic.future);
    async transfer_from r4 into r5;
    output r5 as dummy_exchange.aleo/transfer_from.future;

finalize transfer_from:
    input r0 as dynamic.future;
    await r0;

function swap:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u128.public;
    input r3 as u128.public;
    call.dynamic r0 'aleo' 'transfer_from_public' with self.signer dummy_exchange.aleo r2 (as address.public address.public u128.public) into r4 (as dynamic.future);
    call.dynamic r1 'aleo' 'transfer_public' with self.signer r3 (as address.public u128.public) into r5 (as dynamic.future);
    async swap r4 r5 into r6;
    output r6 as dummy_exchange.aleo/swap.future;

finalize swap:
    input r0 as dynamic.future;
    input r1 as dynamic.future;
    await r0;
    await r1;

constructor:
    assert.eq edition 0u16;
