program dummy_exchange.aleo;

function transfer_from:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as u128.public;
    call.dynamic r0 1868917857field 567541106188061564941814004975800285532843504244field with r1 r2 r3 (as address.private address.private u128.private) into r4 (as dynamic.future);
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
    call.dynamic r0 1868917857field 567541106188061564941814004975800285532843504244field with self.signer dummy_exchange.aleo r2 (as address.private address.private u128.private) into r4 (as dynamic.future);
    call.dynamic r1 1868917857field 516175629116388850284097790795674228field with self.signer r3 (as address.private u128.private) into r5 (as dynamic.future);
    async swap r4 r5 into r6;
    output r6 as dummy_exchange.aleo/swap.future;

finalize swap:
    input r0 as dynamic.future;
    input r1 as dynamic.future;
    await r0;
    await r1;

constructor:
    assert.eq edition 0u16;
