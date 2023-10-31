program token.aleo;

mapping account:
	key as address.public;
	value as u64.public;

record token:
    owner as address.private;
    amount as u64.private;

struct approval:
    approver as address;
    spender as address;

mapping approvals:
    key as field.public;
    value as u64.public;

function approve_public:
    input r0 as address.public; // spender
    input r1 as u64.public; // amount spender is allowed to withdraw from approver

    // hash approval
    cast self.caller r0 into r2 as approval;
    hash.bhp256 r2 into r3 as field;

    async approve_public r3 r1 into r4;
    output r4 as token.aleo/approve_public.future;

finalize approve_public:
    input r0 as field.public;
    input r1 as u64.public; // increase in amount spender is allowed to withdraw from approver

    // if approvals for approver field times spender field exists, the approved amount is increased.
    // otherwise, the approved allowance is created.
    get.or_use approvals[r0] 0u64 into r2;
    add r1 r2 into r3;
    set r3 into approvals[r0];

function unapprove_public:
    input r0 as address.public; // spender
    input r1 as u64.public; // amount spender's allowance is decreasing by

    // hash approval
    cast self.caller r0 into r2 as approval;
    hash.bhp256 r2 into r3 as field;

    async unapprove_public r3 r1 into r4;
    output r4 as token.aleo/unapprove_public.future;

finalize unapprove_public:
    input r0 as field.public;
    input r1 as u64.public; // decrease in amount spender is allowed to withdraw from approver

    get approvals[r0] into r2;
    sub r2 r1 into r3;
    set r3 into approvals[r0];

/* Transfer From */

function transfer_from_public:
    input r0 as address.public; // from the approver
    input r1 as address.public; // to the receiver
    input r2 as u64.public; // amount to transfer

    cast r0 self.caller into r3 as approval;
    hash.bhp256 r3 into r4 as field; // hash approval

    async transfer_from_public r4 r0 r1 r2 into r5;
    output r5 as token.aleo/transfer_from_public.future;

finalize transfer_from_public:
    input r0 as field.public; // approval
    input r1 as address.public; // from the approver
    input r2 as address.public; // to the receiver
    input r3 as u64.public; // amount to transfer

    get approvals[r0] into r4;
    sub r4 r3 into r5;
    set r5 into approvals[r0];
    get account[r1] into r6;
    sub r6 r3 into r7;
    set r7 into account[r1];
    get.or_use account[r2] 0u64 into r8;
    add r8 r3 into r9;
    set r9 into account[r2];

function transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    async transfer_public self.caller r0 r1 into r2;
    output r2 as token.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    get.or_use account[r0] 0u64 into r3;
    sub r3 r2 into r4;
    set r4 into account[r0];
    get.or_use account[r1] 0u64 into r5;
    add r5 r2 into r6;
    set r6 into account[r1];


function transfer_private:
    input r0 as token.record;
    input r1 as address.private;
    input r2 as u64.private;
    sub r0.amount r2 into r3;
    cast r0.owner r3 into r4 as token.record;
    cast r1 r2 into r5 as token.record;
    output r4 as token.record;
    output r5 as token.record;


function transfer_private_to_public:
    input r0 as token.record;
    input r1 as address.public;
    input r2 as u64.public;
    sub r0.amount r2 into r3;
    cast r0.owner r3 into r4 as token.record;
    async transfer_private_to_public r1 r2 into r5;
    output r4 as token.record;
    output r5 as token.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as address.public;
    input r1 as u64.public;
    get.or_use account[r0] 0u64 into r2;
    add r2 r1 into r3;
    set r3 into account[r0];


function transfer_public_to_private:
    input r0 as address.public;
    input r1 as u64.public;
    cast r0 r1 into r2 as token.record;
    async transfer_public_to_private self.caller r1 into r3;
    output r2 as token.record;
    output r3 as token.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as address.public;
    input r1 as u64.public;
    get.or_use account[r0] 0u64 into r2;
    sub r2 r1 into r3;
    set r3 into account[r0];
