program wrapper_dispatcher.aleo;

mapping token_routes:
    key as field.public;
    value as field.public;

function register_route:
    input r0 as field.public;
    input r1 as field.public;
    async register_route r0 r1 into r2;
    output r2 as wrapper_dispatcher.aleo/register_route.future;

finalize register_route:
    input r0 as field.public;
    input r1 as field.public;
    set r1 into token_routes[r0];

function transfer_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 1868917857field 516175629116388850284097790795674228field with r0 r1 r2 (as field.private address.private u128.private) into r4 (as dynamic.future);
    async transfer_public r0 r3 r4 into r5;
    output r5 as wrapper_dispatcher.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function transfer_public_as_signer:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 1868917857field 718076685225955844079766916816982442103848756111050079826548field with r0 r1 r2 (as field.private address.private u128.private) into r4 (as dynamic.future);
    async transfer_public_as_signer r0 r3 r4 into r5;
    output r5 as wrapper_dispatcher.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function transfer_public_to_private:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 1868917857field 163031276046149327277138208237194600527678254627957973064970868field with r0 r1 r2 (as field.private address.private u128.private) into r4 r5 (as dynamic.record dynamic.future);
    async transfer_public_to_private r0 r3 r5 into r6;
    output r4 as dynamic.record;
    output r6 as wrapper_dispatcher.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function join:
    input r0 as dynamic.record;
    input r1 as dynamic.record;
    input r2 as field.public;
    call.dynamic r2 1868917857field 1852403562field with r0 r1 (as dynamic.record dynamic.record) into r3 (as dynamic.record);
    output r3 as dynamic.record;

function split:
    input r0 as dynamic.record;
    input r1 as u128.private;
    input r2 as field.public;
    call.dynamic r2 1868917857field 499984920691field with r0 r1 (as dynamic.record u128.private) into r3 r4 (as dynamic.record dynamic.record);
    output r3 as dynamic.record;
    output r4 as dynamic.record;

function transfer_private_to_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as dynamic.record;
    input r3 as field.public;
    call.dynamic r3 1868917857field 159748619646624572882733203183532374243803035081386454010655348field with r0 r1 r2 (as address.private u128.private dynamic.record) into r4 r5 (as dynamic.record dynamic.future);
    async transfer_private_to_public r5 into r6;
    output r4 as dynamic.record;
    output r6 as wrapper_dispatcher.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as dynamic.future;
    await r0;

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as dynamic.record;
    input r3 as field.public;
    call.dynamic r3 1868917857field 134856310785155548303824185267685782132field with r0 r1 r2 (as address.private u128.private dynamic.record) into r4 r5 r6 (as dynamic.record dynamic.record dynamic.future);
    async transfer_private r6 into r7;
    output r4 as dynamic.record;
    output r5 as dynamic.record;
    output r7 as wrapper_dispatcher.aleo/transfer_private.future;

finalize transfer_private:
    input r0 as dynamic.future;
    await r0;
