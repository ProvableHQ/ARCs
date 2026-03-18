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
    call.dynamic r3 'aleo' 'transfer_public' with r0 r1 r2 (as field.private address.private u128.private) into r4 (as dynamic.future);
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
    call.dynamic r3 'aleo' 'transfer_public_as_signer' with r0 r1 r2 (as field.private address.private u128.private) into r4 (as dynamic.future);
    async transfer_public_as_signer r0 r3 r4 into r5;
    output r5 as wrapper_dispatcher.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function deposit:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'deposit' with r0 r1 (as field.private u128.private) into r3 (as dynamic.future);
    async deposit r0 r2 r3 into r4;
    output r4 as wrapper_dispatcher.aleo/deposit.future;

finalize deposit:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function deposit_compliant:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'deposit' with r0 r1 (as field.private u128.private) into r3 r4 (as dynamic.record dynamic.future);
    async deposit_compliant r0 r2 r4 into r5;
    output r3 as dynamic.record;
    output r5 as wrapper_dispatcher.aleo/deposit_compliant.future;

finalize deposit_compliant:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function withdraw:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'withdraw' with r0 r1 (as field.private u128.private) into r3 (as dynamic.future);
    async withdraw r0 r2 r3 into r4;
    output r4 as wrapper_dispatcher.aleo/withdraw.future;

finalize withdraw:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function withdraw_compliant:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'withdraw' with r0 r1 (as field.private u128.private) into r3 r4 (as dynamic.record dynamic.future);
    async withdraw_compliant r0 r2 r4 into r5;
    output r3 as dynamic.record;
    output r5 as wrapper_dispatcher.aleo/withdraw_compliant.future;

finalize withdraw_compliant:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function withdraw_as_signer:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'withdraw_as_signer' with r0 r1 (as field.private u128.private) into r3 (as dynamic.future);
    async withdraw_as_signer r0 r2 r3 into r4;
    output r4 as wrapper_dispatcher.aleo/withdraw_as_signer.future;

finalize withdraw_as_signer:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function withdraw_as_signer_compliant:
    input r0 as field.public;
    input r1 as u128.public;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'withdraw_as_signer' with r0 r1 (as field.private u128.private) into r3 r4 (as dynamic.record dynamic.future);
    async withdraw_as_signer_compliant r0 r2 r4 into r5;
    output r3 as dynamic.record;
    output r5 as wrapper_dispatcher.aleo/withdraw_as_signer_compliant.future;

finalize withdraw_as_signer_compliant:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function shield:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 'aleo' 'shield' with r0 r1 r2 (as field.private address.private u128.private) into r4 r5 (as dynamic.record dynamic.future);
    async shield r0 r3 r5 into r6;
    output r4 as dynamic.record;
    output r6 as wrapper_dispatcher.aleo/shield.future;

finalize shield:
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
    call.dynamic r2 'aleo' 'join' with r0 r1 (as dynamic.record dynamic.record) into r3 (as dynamic.record);
    output r3 as dynamic.record;

function split:
    input r0 as dynamic.record;
    input r1 as u128.private;
    input r2 as field.public;
    call.dynamic r2 'aleo' 'split' with r0 r1 (as dynamic.record u128.private) into r3 r4 (as dynamic.record dynamic.record);
    output r3 as dynamic.record;
    output r4 as dynamic.record;

function unshield:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as dynamic.record;
    input r4 as field.public;
    call.dynamic r4 'aleo' 'unshield' with r1 r2 r3 (as address.private u128.private dynamic.record) into r5 r6 (as dynamic.record dynamic.future);
    async unshield r0 r4 r6 into r7;
    output r5 as dynamic.record;
    output r7 as wrapper_dispatcher.aleo/unshield.future;

finalize unshield:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function transfer_private:
    input r0 as address.private;
    input r1 as u128.private;
    input r2 as dynamic.record;
    input r3 as field.public;
    call.dynamic r3 'aleo' 'transfer_private' with r0 r1 r2 (as address.private u128.private dynamic.record) into r4 r5 r6 (as dynamic.record dynamic.record dynamic.future);
    async transfer_private r6 into r7;
    output r4 as dynamic.record;
    output r5 as dynamic.record;
    output r7 as wrapper_dispatcher.aleo/transfer_private.future;

finalize transfer_private:
    input r0 as dynamic.future;
    await r0;

function mint_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 'aleo' 'mint_public' with r0 r1 r2 (as field.private address.private u128.private) into r4 (as dynamic.future);
    async mint_public r0 r3 r4 into r5;
    output r5 as wrapper_dispatcher.aleo/mint_public.future;

finalize mint_public:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

function mint_private:
    input r0 as field.public;
    input r1 as address.private;
    input r2 as u128.public;
    input r3 as field.public;
    call.dynamic r3 'aleo' 'mint_private' with r0 r1 r2 (as field.private address.private u128.private) into r4 r5 (as dynamic.record dynamic.future);
    async mint_private r0 r3 r5 into r6;
    output r4 as dynamic.record;
    output r6 as wrapper_dispatcher.aleo/mint_private.future;

finalize mint_private:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as dynamic.future;
    get token_routes[r0] into r3;
    assert.eq r3 r1;
    await r2;

constructor:
    assert.eq edition 0u16;
