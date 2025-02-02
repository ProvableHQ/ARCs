import token.aleo;

program spender_tester.aleo;

function transfer_from_public:
    input r0 as address.public; // approver
    input r1 as address.public; // receiver
    input r2 as u64.public;

    call token.aleo/transfer_from_public r0 r1 r2 into r3;
    async transfer_from_public r3 into r4;
    output r4 as spender_tester.aleo/transfer_from_public.future;

finalize transfer_from_public:
    input r0 as token.aleo/transfer_from_public.future;
    await r0;
