---
arc: 21 
title: Multi-Token Standard Program
authors: evanmarshall
discussion: N/A (Retroactive Proposal)
topic: Application
status: Deprecated
created: 2024-06-07
---

## Abstract

The current version of SnarkOS/SnarkVM does not support either dynamic contract calls ("call by address") or standard interfaces. This makes composability difficult to implement. While it is possible for a first contract to call a second contract, the first contract must be explicitly compiled with knowledge of the code of the second contract. In the DeFi example given above, this means that a DeFi contract must be compiled with support for all token contracts that it will ever interact with. If a new token contract is subsequently deployed on-chain, the DeFi contract will need to be re-compiled and redeployed on chain in order to interact with that token. Proposal. We propose a single multi-token support program (MTSP) that can manage balances for many different ARC-20 tokens. This program would be the standard "hub" that all tokens and DeFi contracts interface with. Individual ARC-20 tokens can register with the MTSP and mint new tokens via this contract. Transfers of token value will occur by direct call to the MTSP rather than the ARC-20 contract itself. The benefit of this approach is that DeFi contracts do not need to be compiled with any special knowledge of individual ARC-20 tokens: their sole dependency will be the MTSP. Hence the deployment of new tokens does not require re-deployment of DeFi contracts. Similarly, individual ARC-20 tokens can also be compiled with dependence on the MTSP, but no dependence on the DeFi programs. The MTSP thus allows interoperability between new tokens and DeFi contracts, with no need for contract re-deployment. As a secondary benefit, the MTSP will provide privacy benefits (via an improved anonymity set) because all private transfers within the MTSP will conceal the identity of the specific token being transferred.

## Source And Examples

You can find the source [here](https://github.com/demox-labs/aleo-standard-programs/blob/8bcc805da1399bd35c713155edeceee0096a7d31/pondo-bot/old_programs/mtsp_credits.aleo#L4) . We have also deployed examples of usage of the MTSP in the same repository as well as deployed the program to Testnet Beta in this transaction: at138kpz0xdfzqavxcnku52954ysx2sptmr263precczclahts8csgs4l05ah

A leo program is provided by due to limitations at the time of writing in Leo, we have to make some manual edits to the Aleo opcodes so the full Aleo source is provided below.

## Specification
```
program multi_token_support_program_v1.aleo;


record Token:
owner as address.private;
amount as u128.private;
token_id as field.private;
external_authorization_required as boolean.private;
authorized_until as u32.private;

struct TokenMetadata:
token_id as field;
name as u128;
symbol as u128;
decimals as u8;
supply as u128;
max_supply as u128;
admin as address;
external_authorization_required as boolean;
external_authorization_party as address;

struct TokenOwner:
account as address;
token_id as field;

struct Balance:
token_id as field;
account as address;
balance as u128;
authorized_until as u32;

struct Allowance:
account as address;
spender as address;
token_id as field;


mapping registered_tokens:
key as field.public;
value as TokenMetadata.public;


mapping balances:
key as field.public;
value as Balance.public;


mapping authorized_balances:
key as field.public;
value as Balance.public;


mapping allowances:
key as field.public;
value as u128.public;


mapping roles:
key as field.public;
value as u8.public;


function transfer_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
async transfer_public r0 r1 r2 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/transfer_public.future;

finalize transfer_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as address.public;
cast r3 r0 into r4 as TokenOwner;
hash.bhp256 r4 into r5 as field;
get authorized_balances[r5] into r6;
get registered_tokens[r0] into r7;
lte block.height r6.authorized_until into r8;
not r7.external_authorization_required into r9;
or r8 r9 into r10;
assert.eq r10 true;
sub r6.balance r2 into r11;
cast r0 r3 r11 r6.authorized_until into r12 as Balance;
set r12 into authorized_balances[r5];
cast r1 r0 into r13 as TokenOwner;
hash.bhp256 r13 into r14 as field;
get registered_tokens[r0] into r15;
ternary r15.external_authorization_required 0u32 4294967295u32 into r16;
cast r0 r1 0u128 r16 into r17 as Balance;
get.or_use balances[r14] r17 into r18;
get.or_use authorized_balances[r14] r17 into r19;
ternary r15.external_authorization_required r18.token_id r19.token_id into r20;
ternary r15.external_authorization_required r18.account r19.account into r21;
ternary r15.external_authorization_required r18.balance r19.balance into r22;
ternary r15.external_authorization_required r18.authorized_until r19.authorized_until into r23;
cast r20 r21 r22 r23 into r24 as Balance;
add r24.balance r2 into r25;
cast r0 r1 r25 r24.authorized_until into r26 as Balance;
branch.eq r15.external_authorization_required false to end_then_0_0;
set r26 into balances[r14];
branch.eq true true to end_otherwise_0_1;
position end_then_0_0;
set r26 into authorized_balances[r14];
position end_otherwise_0_1;




function transfer_public_as_signer:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
async transfer_public_as_signer r0 r1 r2 self.signer into r3;
output r3 as multi_token_support_program_v1.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as address.public;
cast r3 r0 into r4 as TokenOwner;
hash.bhp256 r4 into r5 as field;
get authorized_balances[r5] into r6;
get registered_tokens[r0] into r7;
lte block.height r6.authorized_until into r8;
not r7.external_authorization_required into r9;
or r8 r9 into r10;
assert.eq r10 true;
sub r6.balance r2 into r11;
cast r0 r3 r11 r6.authorized_until into r12 as Balance;
set r12 into authorized_balances[r5];
cast r1 r0 into r13 as TokenOwner;
hash.bhp256 r13 into r14 as field;
get registered_tokens[r0] into r15;
ternary r15.external_authorization_required 0u32 4294967295u32 into r16;
cast r0 r1 0u128 r16 into r17 as Balance;
get.or_use balances[r14] r17 into r18;
get.or_use authorized_balances[r14] r17 into r19;
ternary r15.external_authorization_required r18.token_id r19.token_id into r20;
ternary r15.external_authorization_required r18.account r19.account into r21;
ternary r15.external_authorization_required r18.balance r19.balance into r22;
ternary r15.external_authorization_required r18.authorized_until r19.authorized_until into r23;
cast r20 r21 r22 r23 into r24 as Balance;
add r24.balance r2 into r25;
cast r0 r1 r25 r24.authorized_until into r26 as Balance;
branch.eq r15.external_authorization_required false to end_then_0_2;
set r26 into balances[r14];
branch.eq true true to end_otherwise_0_3;
position end_then_0_2;
set r26 into authorized_balances[r14];
position end_otherwise_0_3;




function transfer_private:
input r0 as address.private;
input r1 as u128.private;
input r2 as Token.record;
sub r2.amount r1 into r3;
cast r2.owner r3 r2.token_id r2.external_authorization_required r2.authorized_until into r4 as Token.record;
ternary r2.external_authorization_required 0u32 4294967295u32 into r5;
cast r0 r1 r2.token_id r2.external_authorization_required r5 into r6 as Token.record;
async transfer_private r2.external_authorization_required r2.authorized_until into r7;
output r4 as Token.record;
output r6 as Token.record;
output r7 as multi_token_support_program_v1.aleo/transfer_private.future;

finalize transfer_private:
input r0 as boolean.public;
input r1 as u32.public;
lte block.height r1 into r2;
not r0 into r3;
or r2 r3 into r4;
assert.eq r4 true;




function transfer_private_to_public:
input r0 as address.public;
input r1 as u128.public;
input r2 as Token.record;
sub r2.amount r1 into r3;
cast r2.owner r3 r2.token_id r2.external_authorization_required r2.authorized_until into r4 as Token.record;
async transfer_private_to_public r2.token_id r0 r1 r2.authorized_until r2.external_authorization_required into r5;
output r4 as Token.record;
output r5 as multi_token_support_program_v1.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as u32.public;
input r4 as boolean.public;
lte block.height r3 into r5;
not r4 into r6;
or r5 r6 into r7;
assert.eq r7 true;
cast r1 r0 into r8 as TokenOwner;
hash.bhp256 r8 into r9 as field;
get registered_tokens[r0] into r10;
ternary r10.external_authorization_required 0u32 4294967295u32 into r11;
cast r0 r1 0u128 r11 into r12 as Balance;
get.or_use balances[r9] r12 into r13;
get.or_use authorized_balances[r9] r12 into r14;
ternary r10.external_authorization_required r13.token_id r14.token_id into r15;
ternary r10.external_authorization_required r13.account r14.account into r16;
ternary r10.external_authorization_required r13.balance r14.balance into r17;
ternary r10.external_authorization_required r13.authorized_until r14.authorized_until into r18;
cast r15 r16 r17 r18 into r19 as Balance;
add r19.balance r2 into r20;
cast r0 r1 r20 r19.authorized_until into r21 as Balance;
branch.eq r10.external_authorization_required false to end_then_0_4;
set r21 into balances[r9];
branch.eq true true to end_otherwise_0_5;
position end_then_0_4;
set r21 into authorized_balances[r9];
position end_otherwise_0_5;

function transfer_public_to_private:
input r0 as field.public;
input r1 as address.private;
input r2 as u128.public;
input r3 as boolean.public;
ternary r3 0u32 4294967295u32 into r4;
cast r1 r2 r0 r3 r4 into r5 as Token.record;
async transfer_public_to_private r0 r2 self.caller r3 into r6;
output r5 as Token.record;
output r6 as multi_token_support_program_v1.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
input r0 as field.public;
input r1 as u128.public;
input r2 as address.public;
input r3 as boolean.public;
get registered_tokens[r0] into r4;
assert.eq r4.external_authorization_required r3;
cast r2 r0 into r5 as TokenOwner;
hash.bhp256 r5 into r6 as field;
get authorized_balances[r6] into r7;
get registered_tokens[r0] into r8;
lte block.height r7.authorized_until into r9;
not r8.external_authorization_required into r10;
or r9 r10 into r11;
assert.eq r11 true;
sub r7.balance r1 into r12;
cast r0 r2 r12 r7.authorized_until into r13 as Balance;
set r13 into authorized_balances[r6];

function initialize:
async initialize into r0;
output r0 as multi_token_support_program_v1.aleo/initialize.future;

finalize initialize:
cast 3443843282313283355522573239085696902919850365217539366784739393210722344986field 1095517519u128 1095517519u128 6u8 1_500_000_000_000_000u128 1_500_000_000_000_000u128 multi_token_support_program_v1.aleo false multi_token_support_program_v1.aleo into r0 as TokenMetadata;
set r0 into registered_tokens[3443843282313283355522573239085696902919850365217539366784739393210722344986field];

function register_token:
input r0 as field.public;
input r1 as u128.public;
input r2 as u128.public;
input r3 as u8.public;
input r4 as u128.public;
input r5 as boolean.public;
input r6 as address.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r7;
assert.eq r7 true;
cast r0 r1 r2 r3 0u128 r4 self.caller r5 r6 into r8 as TokenMetadata;
async register_token r8 into r9;
output r9 as multi_token_support_program_v1.aleo/register_token.future;

finalize register_token:
input r0 as TokenMetadata.public;
contains registered_tokens[r0.token_id] into r1;
assert.eq r1 false;
set r0 into registered_tokens[r0.token_id];

function update_token_management:
input r0 as field.public;
input r1 as address.public;
input r2 as address.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3;
assert.eq r3 true;
async update_token_management r0 r1 r2 self.caller into r4;
output r4 as multi_token_support_program_v1.aleo/update_token_management.future;

finalize update_token_management:
input r0 as field.public;
input r1 as address.public;
input r2 as address.public;
input r3 as address.public;
get registered_tokens[r0] into r4;
assert.eq r3 r4.admin;
cast r0 r4.name r4.symbol r4.decimals r4.supply r4.max_supply r1 r4.external_authorization_required r2 into r5 as TokenMetadata;
set r5 into registered_tokens[r0];


function set_role:
input r0 as field.public;
input r1 as address.public;
input r2 as u8.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3;
assert.eq r3 true;
async set_role r0 r1 r2 self.caller into r4;
output r4 as multi_token_support_program_v1.aleo/set_role.future;

finalize set_role:
input r0 as field.public;
input r1 as address.public;
input r2 as u8.public;
input r3 as address.public;
get registered_tokens[r0] into r4;
assert.eq r3 r4.admin;
cast r1 r0 into r5 as TokenOwner;
hash.bhp256 r5 into r6 as field;
set r2 into roles[r6];

function remove_role:
input r0 as field.public;
input r1 as address.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r2;
assert.eq r2 true;
async remove_role r0 r1 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/remove_role.future;

finalize remove_role:
input r0 as field.public;
input r1 as address.public;
input r2 as address.public;
get registered_tokens[r0] into r3;
assert.eq r2 r3.admin;
cast r1 r0 into r4 as TokenOwner;
hash.bhp256 r4 into r5 as field;
remove roles[r5];

function mint_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as u32.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r4;
assert.eq r4 true;
async mint_public r0 r1 r2 r3 self.caller into r5;
output r5 as multi_token_support_program_v1.aleo/mint_public.future;

finalize mint_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as u32.public;
input r4 as address.public;
get registered_tokens[r0] into r5;
is.eq r4 r5.admin into r6;
not r6 into r7;
branch.eq r7 false to end_then_0_6;
cast r4 r0 into r8 as TokenOwner;
hash.bhp256 r8 into r9 as field;
get roles[r9] into r10;
is.eq r10 1u8 into r11;
is.eq r10 3u8 into r12;
or r11 r12 into r13;
assert.eq r13 true;
branch.eq true true to end_otherwise_0_7;
position end_then_0_6;
position end_otherwise_0_7;
add r5.supply r2 into r14;
lte r14 r5.max_supply into r15;
assert.eq r15 true;
cast r1 r0 into r16 as TokenOwner;
hash.bhp256 r16 into r17 as field;
cast r0 r1 0u128 r3 into r18 as Balance;
get.or_use balances[r17] r18 into r19;
get.or_use authorized_balances[r17] r18 into r20;
ternary r5.external_authorization_required r19.token_id r20.token_id into r21;
ternary r5.external_authorization_required r19.account r20.account into r22;
ternary r5.external_authorization_required r19.balance r20.balance into r23;
ternary r5.external_authorization_required r19.authorized_until r20.authorized_until into r24;
cast r21 r22 r23 r24 into r25 as Balance;
add r25.balance r2 into r26;
cast r0 r1 r26 r25.authorized_until into r27 as Balance;
branch.eq r5.external_authorization_required false to end_then_0_8;
set r27 into balances[r17];
branch.eq true true to end_otherwise_0_9;
position end_then_0_8;
set r27 into authorized_balances[r17];
position end_otherwise_0_9;
cast r0 r5.name r5.symbol r5.decimals r14 r5.max_supply r5.admin r5.external_authorization_required r5.external_authorization_party into r28 as TokenMetadata;
set r28 into registered_tokens[r0];

function mint_private:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as boolean.public;
input r4 as u32.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r5;
assert.eq r5 true;
cast r1 r2 r0 r3 r4 into r6 as Token.record;
async mint_private r0 r2 r3 r4 self.caller into r7;
output r6 as Token.record;
output r7 as multi_token_support_program_v1.aleo/mint_private.future;

finalize mint_private:
input r0 as field.public;
input r1 as u128.public;
input r2 as boolean.public;
input r3 as u32.public;
input r4 as address.public;
get registered_tokens[r0] into r5;
is.eq r4 r5.admin into r6;
not r6 into r7;
branch.eq r7 false to end_then_0_10;
cast r4 r0 into r8 as TokenOwner;
hash.bhp256 r8 into r9 as field;
get roles[r9] into r10;
is.eq r10 1u8 into r11;
is.eq r10 3u8 into r12;
or r11 r12 into r13;
assert.eq r13 true;
branch.eq true true to end_otherwise_0_11;
position end_then_0_10;
position end_otherwise_0_11;
add r5.supply r1 into r14;
lte r14 r5.max_supply into r15;
assert.eq r15 true;
assert.eq r5.external_authorization_required r2;
is.eq r3 0u32 into r16;
not r5.external_authorization_required into r17;
or r16 r17 into r18;
assert.eq r18 true;
cast r0 r5.name r5.symbol r5.decimals r14 r5.max_supply r5.admin r5.external_authorization_required r5.external_authorization_party into r19 as TokenMetadata;
set r19 into registered_tokens[r0];

function burn_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
is.neq r0 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3;
assert.eq r3 true;
cast r1 r0 into r4 as TokenOwner;
async burn_public r4 r2 self.caller into r5;
output r5 as multi_token_support_program_v1.aleo/burn_public.future;

finalize burn_public:
input r0 as TokenOwner.public;
input r1 as u128.public;
input r2 as address.public;
get registered_tokens[r0.token_id] into r3;
is.neq r2 r3.admin into r4;
branch.eq r4 false to end_then_0_12;
cast r2 r0.token_id into r5 as TokenOwner;
hash.bhp256 r5 into r6 as field;
get roles[r6] into r7;
is.eq r7 2u8 into r8;
is.eq r7 3u8 into r9;
or r8 r9 into r10;
assert.eq r10 true;
branch.eq true true to end_otherwise_0_13;
position end_then_0_12;
position end_otherwise_0_13;
sub r3.supply r1 into r11;
cast r3.token_id r3.name r3.symbol r3.decimals r11 r3.max_supply r3.admin r3.external_authorization_required r3.external_authorization_party into r12 as TokenMetadata;
set r12 into registered_tokens[r0.token_id];
cast r0.token_id r0.account 0u128 0u32 into r13 as Balance;
hash.bhp256 r0 into r14 as field;
get.or_use authorized_balances[r14] r13 into r15;
gt r15.balance 0u128 into r16;
branch.eq r16 false to end_then_0_14;
gt r15.balance r1 into r17;
branch.eq r17 false to end_then_1_16;
sub r15.balance r1 into r18;
cast r0.token_id r0.account r18 r15.authorized_until into r19 as Balance;
set r19 into authorized_balances[r14];
branch.eq true true to end_otherwise_1_17;
position end_then_1_16;
remove authorized_balances[r14];
sub r1 r15.balance into r20;
get balances[r14] into r21;
sub r21.balance r20 into r22;
cast r0.token_id r0.account r22 r21.authorized_until into r23 as Balance;
set r23 into balances[r14];
position end_otherwise_1_17;
branch.eq true true to end_otherwise_0_15;
position end_then_0_14;
get balances[r14] into r24;
sub r24.balance r1 into r25;
cast r0.token_id r0.account r25 r24.authorized_until into r26 as Balance;
set r26 into balances[r14];
position end_otherwise_0_15;

function burn_private:
input r0 as Token.record;
input r1 as u128.public;
is.neq r0.token_id 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r2;
assert.eq r2 true;
sub r0.amount r1 into r3;
cast r0.owner r3 r0.token_id r0.external_authorization_required r0.authorized_until into r4 as Token.record;
async burn_private r0.token_id r1 self.caller into r5;
output r4 as Token.record;
output r5 as multi_token_support_program_v1.aleo/burn_private.future;

finalize burn_private:
input r0 as field.public;
input r1 as u128.public;
input r2 as address.public;
get registered_tokens[r0] into r3;
is.eq r2 r3.admin into r4;
not r4 into r5;
branch.eq r5 false to end_then_0_18;
cast r2 r0 into r6 as TokenOwner;
hash.bhp256 r6 into r7 as field;
get roles[r7] into r8;
is.eq r8 2u8 into r9;
is.eq r8 3u8 into r10;
or r9 r10 into r11;
assert.eq r11 true;
branch.eq true true to end_otherwise_0_19;
position end_then_0_18;
position end_otherwise_0_19;
sub r3.supply r1 into r12;
cast r0 r3.name r3.symbol r3.decimals r12 r3.max_supply r3.admin r3.external_authorization_required r3.external_authorization_party into r13 as TokenMetadata;
set r13 into registered_tokens[r0];

function prehook_public:
input r0 as TokenOwner.public;
input r1 as u128.public;
input r2 as u32.public;
async prehook_public r0 r1 r2 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/prehook_public.future;

finalize prehook_public:
input r0 as TokenOwner.public;
input r1 as u128.public;
input r2 as u32.public;
input r3 as address.public;
get registered_tokens[r0.token_id] into r4;
is.eq r3 r4.external_authorization_party into r5;
assert.eq r5 true;
cast r0.token_id r0.account 0u128 0u32 into r6 as Balance;
hash.bhp256 r0 into r7 as field;
get.or_use balances[r7] r6 into r8;
get.or_use authorized_balances[r7] r6 into r9;
lt r9.authorized_until block.height into r10;
add r8.balance r9.balance into r11;
ternary r10 r11 r8.balance into r12;
ternary r10 0u128 r9.balance into r13;
sub r12 r1 into r14;
add r13 r1 into r15;
cast r0.token_id r0.account r15 r2 into r16 as Balance;
set r16 into authorized_balances[r7];
cast r0.token_id r0.account r14 r8.authorized_until into r17 as Balance;
set r17 into balances[r7];

function prehook_private:
input r0 as Token.record;
input r1 as u128.private;
input r2 as u32.private;
sub r0.amount r1 into r3;
cast r0.owner r3 r0.token_id r0.external_authorization_required r0.authorized_until into r4 as Token.record;
cast r0.owner r1 r0.token_id r0.external_authorization_required r2 into r5 as Token.record;
async prehook_private r0.token_id self.caller into r6;
output r4 as Token.record;
output r5 as Token.record;
output r6 as multi_token_support_program_v1.aleo/prehook_private.future;

finalize prehook_private:
input r0 as field.public;
input r1 as address.public;
get registered_tokens[r0] into r2;
is.eq r1 r2.external_authorization_party into r3;
assert.eq r3 true;

function approve_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
async approve_public r0 r1 r2 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/approve_public.future;

finalize approve_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as address.public;
cast r3 r0 into r4 as TokenOwner;
cast r3 r1 r0 into r5 as Allowance;
hash.bhp256 r5 into r6 as field;
get.or_use allowances[r6] 0u128 into r7;
add r7 r2 into r8;
set r8 into allowances[r6];

function unapprove_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
async unapprove_public r0 r1 r2 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/unapprove_public.future;

finalize unapprove_public:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as address.public;
cast r3 r1 r0 into r4 as Allowance;
hash.bhp256 r4 into r5 as field;
get allowances[r5] into r6;
sub r6 r2 into r7;
set r7 into allowances[r5];

function transfer_from_public:
input r0 as field.public;
input r1 as address.public;
input r2 as address.public;
input r3 as u128.public;
async transfer_from_public r0 r1 r2 r3 self.caller into r4;
output r4 as multi_token_support_program_v1.aleo/transfer_from_public.future;

finalize transfer_from_public:
input r0 as field.public;
input r1 as address.public;
input r2 as address.public;
input r3 as u128.public;
input r4 as address.public;
cast r1 r4 r0 into r5 as Allowance;
hash.bhp256 r5 into r6 as field;
get allowances[r6] into r7;
sub r7 r3 into r8;
set r8 into allowances[r6];
cast r1 r0 into r9 as TokenOwner;
hash.bhp256 r9 into r10 as field;
get authorized_balances[r10] into r11;
get registered_tokens[r0] into r12;
lte block.height r11.authorized_until into r13;
not r12.external_authorization_required into r14;
or r13 r14 into r15;
assert.eq r15 true;
sub r11.balance r3 into r16;
cast r0 r1 r16 r11.authorized_until into r17 as Balance;
set r17 into authorized_balances[r10];
cast r2 r0 into r18 as TokenOwner;
hash.bhp256 r18 into r19 as field;
get registered_tokens[r0] into r20;
ternary r20.external_authorization_required 0u32 4294967295u32 into r21;
cast r0 r2 0u128 r21 into r22 as Balance;
get.or_use balances[r19] r22 into r23;
get.or_use authorized_balances[r19] r22 into r24;
ternary r20.external_authorization_required r23.token_id r24.token_id into r25;
ternary r20.external_authorization_required r23.account r24.account into r26;
ternary r20.external_authorization_required r23.balance r24.balance into r27;
ternary r20.external_authorization_required r23.authorized_until r24.authorized_until into r28;
cast r25 r26 r27 r28 into r29 as Balance;
add r29.balance r3 into r30;
cast r0 r2 r30 r29.authorized_until into r31 as Balance;
branch.eq r20.external_authorization_required false to end_then_0_20;
set r31 into balances[r19];
branch.eq true true to end_otherwise_0_21;
position end_then_0_20;
set r31 into authorized_balances[r19];
position end_otherwise_0_21;

function transfer_from_public_to_private:
input r0 as field.public;
input r1 as address.public;
input r2 as address.private;
input r3 as u128.public;
input r4 as boolean.public;
ternary r4 0u32 4294967295u32 into r5;
cast r2 r3 r0 r4 r5 into r6 as Token.record;
async transfer_from_public_to_private r0 r1 r3 self.caller r4 into r7;
output r6 as Token.record;
output r7 as multi_token_support_program_v1.aleo/transfer_from_public_to_private.future;

finalize transfer_from_public_to_private:
input r0 as field.public;
input r1 as address.public;
input r2 as u128.public;
input r3 as address.public;
input r4 as boolean.public;
get registered_tokens[r0] into r5;
assert.eq r5.external_authorization_required r4;
cast r1 r3 r0 into r6 as Allowance;
hash.bhp256 r6 into r7 as field;
get allowances[r7] into r8;
sub r8 r2 into r9;
set r9 into allowances[r7];
cast r1 r0 into r10 as TokenOwner;
hash.bhp256 r10 into r11 as field;
get authorized_balances[r11] into r12;
get registered_tokens[r0] into r13;
lte block.height r12.authorized_until into r14;
not r13.external_authorization_required into r15;
or r14 r15 into r16;
assert.eq r16 true;
sub r12.balance r2 into r17;
cast r0 r1 r17 r12.authorized_until into r18 as Balance;
set r18 into authorized_balances[r11];

function deposit_credits_public:
input r0 as u64.public;
call credits.aleo/transfer_public_as_signer multi_token_support_program_v1.aleo r0 into r1;
cast r0 into r2 as u128;
async deposit_credits_public r1 r2 self.signer into r3;
output r3 as multi_token_support_program_v1.aleo/deposit_credits_public.future;

finalize deposit_credits_public:
input r0 as credits.aleo/transfer_public_as_signer.future;
input r1 as u128.public;
input r2 as address.public;
await r0;
cast r2 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3 as TokenOwner;
hash.bhp256 r3 into r4 as field;
cast 3443843282313283355522573239085696902919850365217539366784739393210722344986field r2 0u128 4294967295u32 into r5 as Balance;
get.or_use authorized_balances[r4] r5 into r6;
add r6.balance r1 into r7;
cast 3443843282313283355522573239085696902919850365217539366784739393210722344986field r2 r7 r6.authorized_until into r8 as Balance;
set r8 into authorized_balances[r4];

function deposit_credits_private:
input r0 as credits.aleo/credits.record;
input r1 as u64.private;
call credits.aleo/transfer_private_to_public r0 multi_token_support_program_v1.aleo r1 into r2 r3;
cast r1 into r4 as u128;
cast r0.owner r4 3443843282313283355522573239085696902919850365217539366784739393210722344986field false 4294967295u32 into r5 as Token.record;
async deposit_credits_private r3 into r6;
output r2 as credits.aleo/credits.record;
output r5 as Token.record;
output r6 as multi_token_support_program_v1.aleo/deposit_credits_private.future;

finalize deposit_credits_private:
input r0 as credits.aleo/transfer_private_to_public.future;
await r0;

function withdraw_credits_public:
input r0 as u64.private;
call credits.aleo/transfer_public self.caller r0 into r1;
cast r0 into r2 as u128;
async withdraw_credits_public r1 r2 self.caller into r3;
output r3 as multi_token_support_program_v1.aleo/withdraw_credits_public.future;

finalize withdraw_credits_public:
input r0 as credits.aleo/transfer_public.future;
input r1 as u128.public;
input r2 as address.public;
await r0;
cast r2 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r3 as TokenOwner;
hash.bhp256 r3 into r4 as field;
get authorized_balances[r4] into r5;
sub r5.balance r1 into r6;
cast 3443843282313283355522573239085696902919850365217539366784739393210722344986field r2 r6 r5.authorized_until into r7 as Balance;
set r7 into authorized_balances[r4];

function withdraw_credits_private:
input r0 as Token.record;
input r1 as u64.private;
is.eq r0.token_id 3443843282313283355522573239085696902919850365217539366784739393210722344986field into r2;
assert.eq r2 true;
call credits.aleo/transfer_public_to_private r0.owner r1 into r3 r4;
cast r1 into r5 as u128;
sub r0.amount r5 into r6;
cast r0.owner r6 r0.token_id r0.external_authorization_required r0.authorized_until into r7 as Token.record;
async withdraw_credits_private r4 into r8;
output r7 as Token.record;
output r3 as credits.aleo/credits.record;
output r8 as multi_token_support_program_v1.aleo/withdraw_credits_private.future;

finalize withdraw_credits_private:
input r0 as credits.aleo/transfer_public_to_private.future;
await r0;
```
