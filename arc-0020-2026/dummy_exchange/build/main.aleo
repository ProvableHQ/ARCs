import credits.aleo;
import wrapped_credits.aleo;
program dummy_exchange.aleo;

function transfer_from:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    call wrapped_credits.aleo/transfer_from_public r0 r1 r2 into r3;
    async transfer_from r3 into r4;
    output r4 as dummy_exchange.aleo/transfer_from.future;

finalize transfer_from:
    input r0 as wrapped_credits.aleo/transfer_from_public.future;
    await r0;

constructor:
    assert.eq edition 0u16;
