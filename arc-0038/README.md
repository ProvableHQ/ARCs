---
arc: 0038
title: Create Delegated Staking Standard Program with Commission
authors: chris@demoxlabs.xyz mike@demoxlabs.xyz evan@demoxlabs.xyz
discussion: https://github.com/AleoHQ/ARCs/discussions/66
topic: Application
status: Draft
created: 3/19/2024
---

## Abstract
Validators play an important role in running the network. Validators receive rewards for taking on this responsibility, and this reward is split among the delegators bonded to them. To account for the cost associated with running a validator node, validators should be allowed to take a commission on the rewards earned from bonding to them. This proposal would also allow smaller delegators to participate in staking, as the minimum stake may be prohibitive for smaller investors.

## Specification
### Required Constants:
```
const ADMIN: address = aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
```
Validators will need to set an admin address from which they will be able to control certain aspects of the program, such as the commission rate and address of the validator node
```
const CORE_PROTOCOL: address = aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny;
```
This is the precompiled address of the program itself. This is used for reading the mapping values for the program in `credits.aleo` (account, bonded, etc).
```
const SHARES_TO_MICROCREDITS: u64 = 1_000u64;
```
Shares in the protocol are equivalent to nanocredits (at time of initial deposit) in order to more precisely calculate the commission due to the validator. This constant helps us move between shares and microcredits for the initial deposit.


```
const PRECISION_UNSIGNED: u128 = 1000u128;
```
A constant used for added precision when performing integer calculations


```
const MAX_COMMISSION_RATE: u128 = 500u128;
```
This is the maximum allowed commission rate for the program. It is relative to the `PRECISION_UNSIGNED` above. e.g. 100u128 = 10%


```
const UNBONDING_PERIOD: u32 = 360u32;
```
The unbonding period in blocks, as defined in `credits.aleo` Used for batching withdrawal requests


```
const MINIMUM_BOND_POOL: u64 = 10_000_000_000u64;
```
This minimum stake as defined in `credits.aleo`. Used to ensure an attempt to unbond the full balance will successfully remove the value in the `bonded` mapping.


### Required Mappings:
```
mapping is_initialized: u8 => bool;
```
Key `0u8` stores a boolean showing whether the program has been initialized by the admin. 


```
mapping commission_percent: u8 => u128;
```
Key `0u8` stores the percentage of rewards taken as commission. Relative to `PRECISION_UNSIGNED` e.g. 100u128 = 10%


```
mapping validator: u8 => address;
```
Key `0u8` stores the current address used for bonding to the validator.
Key `1u8` stores the next address to use for bonding, in the case the validator address needs to be updated. Automatically reset when the pool funds are bonded.
```
mapping total_balance: u8 => u64;
```
Key `0u8` stores the total balance of microcredits that have been deposited to the program, excluding commissions.


```
mapping total_shares: u8 => u64;
```
Key `0u8` stores the total number of shares owned by delegators. Shares represent the portion of the `total_balance` that a delegator owns. For example, upon withdrawal, we calculate the amount of microcredits to disburse to the delegator based on the portion of the shares pool they own. (`delegator_shares / total_shares`)


```
mapping delegator_shares: address => u64;
```
Maps from a delegator to the number of shares they own.


```
mapping pending_withdrawal: u8 => u64;
```
Key `0u8` stores the total amount of microcredits that delegators are waiting to withdraw.


```
mapping current_batch_height: u8 => u32;
```
Key `0u8` stores the height at which the current batch of withdrawals will be available for claim. Used to prevent indefinite unbonding due to withdrawals. If the value is not present or equal to `0u32`, there is no batch currently unbonding, and a new batch may be started.


```
mapping withdrawals: address => withdrawal_state;
```
Maps from a delegator to their `withdrawal_state`, which contains the amount of microcredits they have pending withdrawal and the height at which they will be available to claim.


### Required Structs:
```
struct withdrawal_state:
	microcredits as u64;
	claim_block as u32;

```
In normal operation of the protocol, most if not all of the credits owned by the protocol will be bonded to a validator, which means withdrawals must unbond, claim, and then transfer credits to the withdrawer.
To keep track of the amount of microcredits a withdrawer can claim, as well as to keep track of when the withdrawer can claim, this struct holds both properties. For use of this struct, see the `withdrawals` mapping, `create_withdraw_claim` finalize block, and the `withdraw_public` finalize block.

### Required Records:
None

### Required Functions:

#### Initialize
The `initialize` function takes two arguments: `commission_rate`, the initial commission rate as a `u128` and `validator_address`, the `address` of the validator the program will bond to.
The transition is straightforward - we assert that it is the admin calling this function and that the commission rate is within bounds.
The finalize confirms that the program has not already been initialized and then sets `is_initialized` to true and sets the initial values for each of the program’s mappings.
```aleo
function initialize:
	input r0 as u128.public;
	input r1 as address.public;
	assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
	lt r0 1000u128 into r2;
	assert.eq r2 true;
	lte r0 500u128 into r3;
	assert.eq r3 true;
	async initialize r0 r1 into r4;
	output r4 as staking_lite.aleo/initialize.future;


finalize initialize:
	input r0 as u128.public;
	input r1 as address.public;
	get is_initialized[0u8] into r2;
	assert.eq r2 false;
	set r0 into commission_percent[0u8];
	set r1 into validator[0u8];
	set 0u64 into total_shares[0u8];
	set 0u64 into total_balance[0u8];
	set 0u64 into pending_withdrawal[0u8];
	set 0u32 into current_batch_height[0u8];
```
```leo
  transition initialize(commission_rate: u128, validator_address: address) {
	assert_eq(self.caller, ADMIN);
	assert(commission_rate < PRECISION_UNSIGNED);
	assert(commission_rate <= MAX_COMMISSION_RATE);


	return then finalize(commission_rate, validator_address);
  }


  finalize initialize(commission_rate: u128, validator_address: address) {
	assert_eq(is_initialized.get(0u8), false);


	commission_percent.set(0u8, commission_rate);
	validator.set(0u8, validator_address);
	total_shares.set(0u8, 0u64);
	total_balance.set(0u8, 0u64);
	pending_withdrawal.set(0u8, 0u64);
	current_batch_height.set(0u8, 0u32);
  }
```
#### Initial Deposit
`initial_deposit` takes three arguments: `input_record` (credits.aleo/credits record) and `microcredits` (u64) which are used to transfer credits into the program, and `validator_address` (address) used to call `bond_public` with the credits transferred in. Note: once `transfer_public_signer` is added to `credits.aleo`, we won’t need to accept private records and can instead only take microcredits as the singular argument for this function. Currently, `transfer_public` uses the caller and not the signer to transfer credits, which means the protocol address would be transferring credits from and to itself in this function.
The transition simply asserts that the admin is calling this function and handles the calls to `credits.aleo` for transferring and bonding.
The finalize block first confirms that the program has been initialized, and there are no funds present in the program. It then initializes the balance of microcredits and shares (in nanocredits) and assigns the new shares to the admin in `delegator_shares`. 
```aleo
function initial_deposit:
	input r0 as credits.aleo/credits.record;
	input r1 as u64.public;
	input r2 as address.public;
	assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
	call credits.aleo/transfer_public_to_public r0 aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny r1 into r3 r4;
	call credits.aleo/bond_public r2 r1 into r5;
	async initial_deposit r4 r5 r1 into r6;
	output r3 as credits.aleo/credits.record;
	output r6 as staking_lite.aleo/initial_deposit.future;


finalize initial_deposit:
	input r0 as credits.aleo/transfer_public_to_public.future;
	input r1 as credits.aleo/bond_public.future;
	input r2 as u64.public;
	await r0;
	await r1;
	get is_initialized[0u8] into r3;
	assert.eq r3 true;
	get.or_use total_balance[0u8] 0u64 into r4;
	get.or_use total_shares[0u8] 0u64 into r5;
	assert.eq r4 0u64;
	assert.eq r5 0u64;
	set r2 into total_balance[0u8];
	mul r2 1_000u64 into r6;
	set r6 into total_shares[0u8];
	set r2 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
```
```leo
  transition initial_deposit(
	input_record: credits.aleo/credits,
	microcredits: u64,
	validator_address: address
  ) -> credits.aleo/credits {
	assert_eq(self.caller, ADMIN);
	// Must be a credits record because credits.aleo uses self.caller for transfers
	let updated_record: credits.aleo/credits = credits.aleo/transfer_public_to_public(input_record, CORE_PROTOCOL, microcredits);
	credits.aleo/bond_public(validator_address, microcredits);


	return (updated_record) then finalize(microcredits);
  }


  finalize initial_deposit(microcredits: u64) {
	assert(is_initialized.get(0u8));


	let balance: u64 = total_balance.get_or_use(0u8, 0u64);
	let shares: u64 = total_shares.get_or_use(0u8, 0u64);
	assert_eq(balance, 0u64);
	assert_eq(shares, 0u64);


	total_balance.set(0u8, microcredits);
	total_shares.set(0u8, microcredits * SHARES_TO_MICROCREDITS);
	delegator_shares.set(ADMIN, microcredits);
  }
```
#### Get Commission
`get_commission` is an inline function (i.e. a helper function that, when compiled to aleo instructions, is inserted directly everywhere it is called) that takes two arguments: `rewards` the total amount of rewards earned from bonding in microcredits, and `commission_rate` the current commission rate of the program both as `u128`s
`get_commission` is used to calculate the portion of rewards that is owed to the validator as commission. We use `u128`s for safety against overflow when multiplying and normalize back to `u64` by dividing by `PRECISION_UNSIGNED`.
```leo
  inline get_commission(
	rewards: u128,
	commission_rate: u128,
  ) -> u64 {
	let commission: u128 = rewards * commission_rate / PRECISION_UNSIGNED;
	let commission_64: u64 = commission as u64;
	return commission_64;
  }
```
#### Calculate New Shares
`calculate_new_shares` is an inline function that takes three arguments: `balance` the total balance of microcredits in the program (deposits + rewards), `deposit` the amount of microcredits being deposited, and `shares` the total amount of shares outstanding. 
`calculate_new_shares` is used to determine the amount of shares to mint for the depositor. This is determined by first calculating the ratio of the current amount of shares and the current balance in microcredits. The goal is to keep this ratio constant, so we determine the number of shares to mint based on the relative change in microcredits. 
This code represents the following formula:
`new_shares = ( total_shares / total_balance) * (total_balance + deposit) - total_shares`
```leo
  inline calculate_new_shares(balance: u128, deposit: u128, shares: u128) -> u64 {
	let pool_ratio: u128 = ((shares * PRECISION_UNSIGNED) / balance);
	let new_total_shares: u128 = (balance + deposit) * pool_ratio;
	let diff: u128 = (new_total_shares / PRECISION_UNSIGNED) - shares;
	let shares_to_mint: u64 = diff as u64;
	return shares_to_mint;
  }
```
#### Set Commission Percent
`set_commission_percent` takes one argument: `new_commission_rate` as a `u128` which will be set as the new value for `commission_percent[0u8]`
The transition simply confirms that the program admin is calling this function and that the new commission rate is within bounds.
The concerns of the finalize block are to:
- First claim any remaining commission at the current commission percent
- Set the new commission rate
```aleo
function set_commission_percent:
	input r0 as u128.public;
	assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
	lt r0 1000u128 into r1;
	assert.eq r1 true;
	lte r0 500u128 into r2;
	assert.eq r2 true;
	async set_commission_percent r0 into r3;
	output r3 as staking_lite.aleo/set_commission_percent.future;


finalize set_commission_percent:
	input r0 as u128.public;
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r1;
	get total_balance[0u8] into r2;
	get total_shares[0u8] into r3;
	gt r1 r2 into r4;
	sub r1 r2 into r5;
	ternary r4 r5 0u64 into r6;
	get commission_percent[0u8] into r7;
	cast r6 into r8 as u128;
	mul r8 r7 into r9;
	div r9 1000u128 into r10;
	cast r10 into r11 as u64;
	sub r6 r11 into r12;
	add r2 r12 into r13;
	cast r13 into r14 as u128;
	cast r11 into r15 as u128;
	cast r3 into r16 as u128;
	mul r16 1000u128 into r17;
	div r17 r14 into r18;
	add r14 r15 into r19;
	mul r19 r18 into r20;
	div r20 1000u128 into r21;
	sub r21 r16 into r22;
	cast r22 into r23 as u64;
	get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r24;
	add r24 r23 into r25;
	set r25 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
	add r3 r23 into r26;
	set r26 into total_shares[0u8];
	add r13 r11 into r27;
	set r27 into total_balance[0u8];
	set r7 into commission_percent[0u8];
```
```leo
  transition set_commission_percent(new_commission_rate: u128) {
	assert_eq(self.caller, ADMIN);
	assert(new_commission_rate < PRECISION_UNSIGNED);
	assert(new_commission_rate <= MAX_COMMISSION_RATE);


	return then finalize(new_commission_rate);
  }


  finalize set_commission_percent(new_commission_rate: u128) {
	// Make sure all commission is claimed before changing the rate
	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
	let commission_rate: u128 = commission_percent.get(0u8);
	let new_commission: u64 = get_commission(rewards as u128, commission_rate);
	current_balance += rewards - new_commission;


	let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, new_commission as u128, current_shares as u128);
	let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
	delegator_shares.set(ADMIN, current_commission + new_commission_shares);


	total_shares.set(0u8, current_shares + new_commission_shares);
	total_balance.set(0u8, current_balance + new_commission);


	commission_percent.set(0u8, commission_rate);
  }
```
#### Set Next Validator
`set_next_validator` takes one argument: `validator_address`, the new `address` that the program will bond to after any currently bonded funds are unbonded.
The transition simply confirms that only the admin may call this function, and the finalize block handles setting the value into `validator[1u8]`
```aleo
function set_next_validator:
	input r0 as address.public;
	assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
	async set_next_validator r0 into r1;
	output r1 as staking_lite.aleo/set_next_validator.future;


finalize set_next_validator:
	input r0 as address.public;
	set r0 into validator[1u8];
```
```leo
  // Update the validator address, to be applied automatically on the next bond_all call
  transition set_next_validator(validator_address: address) {
	assert_eq(self.caller, ADMIN);


	return then finalize(validator_address);
  }


  finalize set_next_validator(validator_address: address) {
	validator.set(1u8, validator_address);
  }
```
#### Unbond All
`unbond_all` takes one argument: `pool_balance` which is the total amount of microcredits to unbond, as a `u64`
The transition simply calls `unbond_public` with the supplied value, and is permissionless.
The finalize block handles the following:
- Confirming that the admin has set a value for the next validator, as `unbond_all` should only occur as part of a validator address change
- Distributing any outstanding commission to the validator
- Asserting that the amount unbonded will result in a complete unbonding (by checking that any difference between `pool_balance` and the actual amount bonded is less than the minimum stake amount)
```aleo
function unbond_all:
	input r0 as u64.public;
	call credits.aleo/unbond_public r0 into r1;
	async unbond_all r1 r0 into r2;
	output r2 as staking_lite.aleo/unbond_all.future;


finalize unbond_all:
	input r0 as credits.aleo/unbond_public.future;
	input r1 as u64.public;
	await r0;
	contains validator[1u8] into r2;
	assert.eq r2 true;
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
	get total_balance[0u8] into r4;
	get total_shares[0u8] into r5;
	gt r3 r4 into r6;
	sub r3 r4 into r7;
	ternary r6 r7 0u64 into r8;
	get commission_percent[0u8] into r9;
	cast r8 into r10 as u128;
	mul r10 r9 into r11;
	div r11 1000u128 into r12;
	cast r12 into r13 as u64;
	sub r8 r13 into r14;
	add r4 r14 into r15;
	cast r15 into r16 as u128;
	cast r13 into r17 as u128;
	cast r5 into r18 as u128;
	mul r18 1000u128 into r19;
	div r19 r16 into r20;
	add r16 r17 into r21;
	mul r21 r20 into r22;
	div r22 1000u128 into r23;
	sub r23 r18 into r24;
	cast r24 into r25 as u64;
	get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r26;
	add r26 r25 into r27;
	set r27 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
	add r5 r25 into r28;
	set r28 into total_shares[0u8];
	add r15 r13 into r29;
	set r29 into total_balance[0u8];
	sub r3 r1 into r30;
	lt r30 10_000_000_000u64 into r31;
	assert.eq r31 true;
```
```leo
  transition unbond_all(pool_balance: u64) {
	credits.aleo/unbond_public(pool_balance);


	return then finalize(pool_balance);
  }


  finalize unbond_all(pool_balance: u64) {
	let next_validator: bool = validator.contains(1u8);
	assert(next_validator);


	// Make sure all commission is claimed before unbonding
	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
	let commission_rate: u128 = commission_percent.get(0u8);
	let new_commission: u64 = get_commission(rewards as u128, commission_rate);
	current_balance += rewards - new_commission;


	let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, new_commission as u128, current_shares as u128);
	let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
	delegator_shares.set(ADMIN, current_commission + new_commission_shares);


	total_shares.set(0u8, current_shares + new_commission_shares);
	total_balance.set(0u8, current_balance + new_commission);


	// Assert that the pool will be fully unbonded
	let residual_balance: u64 = bonded - pool_balance;
	assert(residual_balance < MINIMUM_BOND_POOL);
  }
```
#### Claim Unbond
`claim_unbond` takes no arguments. The transition simply calls `claim_unbond_public`, to claim any unbonded credits - whether from a withdrawal or as a result of `unbond_all`. 
The finalize block removes the value of `current_batch_height` to allow a new withdrawal batch to begin.
```aleo
function claim_unbond:
	call credits.aleo/claim_unbond_public into r0;
	async claim_unbond r0 into r1;
	output r1 as staking_lite.aleo/claim_unbond.future;


finalize claim_unbond:
	input r0 as credits.aleo/claim_unbond_public.future;
	await r0;
	remove current_batch_height[0u8];
```
```leo
  transition claim_unbond() {
	credits.aleo/claim_unbond_public();

	return then finalize();
  }


  finalize claim_unbond() {
	current_batch_height.remove(0u8);
  }
```
#### Bond All
`bond_all` takes two arguments: `validator_address` as an address, and `amount` as a u64.
The transition part is straightforward – the credits.aleo program is called to bond credits held by the protocol to the validator, either the next validator if one is set or to the current validator.
In a nutshell, the concerns of the finalize portion of bond_all are to:
- Ensure there’s not credits unbonding, which means we would be unable to bond to a validator
- Bond all available microcredits to the validator (next or current). Available microcredits depends on pending withdrawals.
- If a next validator is set, bond to the next validator. Set the next validator as the current validator, and remove the next validator.

```aleo


function bond_all:
	input r0 as address.public;
	input r1 as u64.public;
	call credits.aleo/bond_public r0 r1 into r2;
	async bond_all r2 r0 r1 into r3;
	output r3 as staking_lite.aleo/bond_all.future;


finalize bond_all:
	input r0 as credits.aleo/bond_public.future;
	input r1 as address.public;
	input r2 as u64.public;
	await r0;
	get.or_use credits.aleo/unbonding[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
	assert.eq r3 0u64;
	get.or_use credits.aleo/account[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r4;
	get pending_withdrawal[0u8] into r5;
	sub r4 r5 into r6;
	assert.eq r2 r6;
	contains validator[1u8] into r7;
	get validator[1u8] into r8;
	get validator[0u8] into r9;
	ternary r7 r8 r9 into r10;
	assert.eq r1 r10;
	set r10 into validator[0u8];
	remove validator[1u8];
```
```leo


  transition bond_all(validator_address: address, amount: u64) {
	// Call will fail if there is any balance still bonded to another validator
	credits.aleo/bond_public(validator_address, amount);


	return then finalize(validator_address, amount);
  }


  finalize bond_all(validator_address: address, amount: u64) {
	let unbonding_balance: u64 = 0u64; // credits.aleo/unbonding.get(CORE_PROTOCOL);
	assert_eq(unbonding_balance, 0u64);


	let account_balance: u64 = 0u64; // credits.aleo/account.get(CORE_PROTOCOL);
	let pending_withdrawals: u64 = pending_withdrawal.get(0u8);
	let available_balance: u64 = account_balance - pending_withdrawals;
	assert_eq(amount, available_balance);


	// Set validator
	let has_next_validator: bool = validator.contains(1u8);
	let current_validator: address = has_next_validator ? validator.get(1u8) : validator.get(0u8);
	assert_eq(validator_address, current_validator);


	validator.set(0u8, current_validator);
	validator.remove(1u8);
  }
```
#### Claim Commission
`claim_commission` takes no arguments. `claim_commission` is intended for the admin of the protocol to harvest rewards from staking at any point.
In a nutshell, the concerns of the finalize portion of `claim_commission` are to:
- Distribute commission shares for the protocol admin
- Update the protocol state
```aleo
function claim_commission:
	assert.eq self.caller aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
	async claim_commission into r0;
	output r0 as staking_lite.aleo/claim_commission.future;


finalize claim_commission:
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r0;
	get total_balance[0u8] into r1;
	get total_shares[0u8] into r2;
	gt r0 r1 into r3;
	sub r0 r1 into r4;
	ternary r3 r4 0u64 into r5;
	get commission_percent[0u8] into r6;
	cast r5 into r7 as u128;
	mul r7 r6 into r8;
	div r8 1000u128 into r9;
	cast r9 into r10 as u64;
	sub r5 r10 into r11;
	add r1 r11 into r12;
	cast r12 into r13 as u128;
	cast r10 into r14 as u128;
	cast r2 into r15 as u128;
	mul r15 1000u128 into r16;
	div r16 r13 into r17;
	add r13 r14 into r18;
	mul r18 r17 into r19;
	div r19 1000u128 into r20;
	sub r20 r15 into r21;
	cast r21 into r22 as u64;
	get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r23;
	add r23 r22 into r24;
	set r24 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
	add r2 r22 into r25;
	set r25 into total_shares[0u8];
	add r12 r10 into r26;
	set r26 into total_balance[0u8];
```
```leo
  transition claim_commission() {
	assert_eq(self.caller, ADMIN);
	return then finalize();
  }


  finalize claim_commission() {
	// Distribute shares for new commission
	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
	let commission_rate: u128 = commission_percent.get(0u8);
	let new_commission: u64 = get_commission(rewards as u128, commission_rate);
	current_balance += rewards - new_commission;


	let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, new_commission as u128, current_shares as u128);
	let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
	delegator_shares.set(ADMIN, current_commission + new_commission_shares);


	total_shares.set(0u8, current_shares + new_commission_shares);
	total_balance.set(0u8, current_balance + new_commission);
  }
```
#### Deposit Public
`deposit_public` takes two arguments: `input_record` as a `credits.aleo/credits record`, and `microcredits` as a u64. Note: once `transfer_public_signer` is added to `credits.aleo`, we won’t need to accept private records and can instead only take microcredits as the singular argument for this function. Currently, `transfer_public` uses the caller and not the signer to transfer credits, which means the protocol address would be transferring credits from and to itself in this function.
The transition part is straightforward – the `credits.aleo` program is called to transfer credits from the depositor to the protocol address.
In a nutshell, the concerns of the finalize portion of `deposit_public` are to:
- Distribute commission shares for the protocol admin
- Distribute shares for the depositor, in direct proportion to the amount of the protocol credits pool they just contributed to
- Update the protocol state
Deposit public does not automatically bond the credits. This is for several reasons. By not directly bonding credits, we do not enforce a minimum deposit. We also save the depositor on fees, since the constraints of the bond call are not a part of the overall transition. `bond_all` must be called in order to bond the microcredits held by the protocol to the validator.
```aleo
function deposit_public:
	input r0 as credits.aleo/credits.record;
	input r1 as u64.public;
	call credits.aleo/transfer_public_to_public r0 aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny r1 into r2 r3;
	async deposit_public r3 self.caller r1 into r4;
	output r2 as credits.aleo/credits.record;
	output r4 as staking_lite.aleo/deposit_public.future;


finalize deposit_public:
	input r0 as credits.aleo/transfer_public_to_public.future;
	input r1 as address.public;
	input r2 as u64.public;
	await r0;
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
	get total_balance[0u8] into r4;
	get total_shares[0u8] into r5;
	gt r3 r4 into r6;
	sub r3 r4 into r7;
	ternary r6 r7 0u64 into r8;
	get commission_percent[0u8] into r9;
	cast r8 into r10 as u128;
	mul r10 r9 into r11;
	div r11 1000u128 into r12;
	cast r12 into r13 as u64;
	sub r8 r13 into r14;
	add r4 r14 into r15;
	cast r15 into r16 as u128;
	cast r13 into r17 as u128;
	cast r5 into r18 as u128;
	mul r18 1000u128 into r19;
	div r19 r16 into r20;
	add r16 r17 into r21;
	mul r21 r20 into r22;
	div r22 1000u128 into r23;
	sub r23 r18 into r24;
	cast r24 into r25 as u64;
	get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r26;
	add r26 r25 into r27;
	set r27 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
	add r5 r25 into r28;
	add r15 r13 into r29;
	cast r29 into r30 as u128;
	cast r2 into r31 as u128;
	cast r28 into r32 as u128;
	mul r32 1000u128 into r33;
	div r33 r30 into r34;
	add r30 r31 into r35;
	mul r35 r34 into r36;
	div r36 1000u128 into r37;
	sub r37 r32 into r38;
	cast r38 into r39 as u64;
	gte r39 1u64 into r40;
	assert.eq r40 true;
	get.or_use delegator_shares[r1] 0u64 into r41;
	add r41 r39 into r42;
	set r42 into delegator_shares[r1];
	add r28 r39 into r43;
	set r43 into total_shares[0u8];
	add r29 r2 into r44;
	set r44 into total_balance[0u8];
```
```leo
transition deposit_public(
	input_record: credits.aleo/credits,
	microcredits: u64
  ) -> credits.aleo/credits {
	// Must be a credits record because credits.aleo uses self.caller for transfers
	let updated_record: credits.aleo/credits = credits.aleo/transfer_public_to_public(input_record, CORE_PROTOCOL, microcredits);


	return (updated_record) then finalize(self.caller, microcredits);
  }


  finalize deposit_public(
	caller: address,
	microcredits: u64
  ) {
	// Distribute shares for new commission
	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
	let commission_rate: u128 = commission_percent.get(0u8);
	let new_commission: u64 = get_commission(rewards as u128, commission_rate);
	current_balance += rewards - new_commission;


	let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, new_commission as u128, current_shares as u128);
	let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
	delegator_shares.set(ADMIN, current_commission + new_commission_shares);


	current_shares += new_commission_shares;
	current_balance += new_commission;


	// Calculate mint for deposit
	let new_shares: u64 = calculate_new_shares(current_balance as u128, microcredits as u128, current_shares as u128);


	// Ensure mint amount is valid
	assert(new_shares >= 1u64);


	// Update delegator_shares mapping
	let shares: u64 = delegator_shares.get_or_use(caller, 0u64);
	delegator_shares.set(caller, shares + new_shares);


	// Update total shares
	total_shares.set(0u8, current_shares + new_shares);


	// Update total_balance
	total_balance.set(0u8, current_balance + microcredits);
  }
```
#### Withdraw Public
`withdraw_public` takes two arguments: `withdrawal_shares` and `total_withdrawal`, both as u64s. Withdrawal shares are the amount of shares to burn in exchange for `total_withdrawal` microcredits.
`withdraw_public` is meant to be used in the normal operation of the protocol – most credits (excepting deposits and pending withdrawals) should be bonded to the validator.
The transition part is straightforward – the `credits.aleo` program is called to unbond the `total_withdrawal` microcredits from the protocol address.
In a nutshell, the concerns of the finalize portion of `withdraw_public` are to:
- Determine whether this withdrawal will fit into the current withdraw batch, if one is taking place
- Distribute commission shares for the protocol admin
- Ensure that the `total_withdrawal` microcredits are less than or equal to the proportion of microcredits held by the withdrawal_shares
- Update the protocol state
- Set a withdraw claim for the withdrawer so that they may withdraw their shares at a given `claim_height`
```aleo
function withdraw_public:
	input r0 as u64.public;
	input r1 as u64.public;
	call credits.aleo/unbond_public r1 into r2;
	async withdraw_public r2 r0 r1 self.caller into r3;
	output r3 as staking_lite.aleo/withdraw_public.future;


finalize withdraw_public:
	input r0 as credits.aleo/unbond_public.future;
	input r1 as u64.public;
	input r2 as u64.public;
	input r3 as address.public;
	await r0;
	contains withdrawals[r3] into r4;
	assert.eq r4 false;
	get.or_use current_batch_height[0u8] 0u32 into r5;
	add block.height 360u32 into r6;
	is.eq r5 0u32 into r7;
	gte r5 r6 into r8;
	or r7 r8 into r9;
	assert.eq r9 true;
	get delegator_shares[r3] into r10;
	gte r10 r1 into r11;
	assert.eq r11 true;
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r12;
	get total_balance[0u8] into r13;
	get total_shares[0u8] into r14;
	gt r12 r13 into r15;
	sub r12 r13 into r16;
	ternary r15 r16 0u64 into r17;
	get commission_percent[0u8] into r18;
	cast r17 into r19 as u128;
	mul r19 r18 into r20;
	div r20 1000u128 into r21;
	cast r21 into r22 as u64;
	sub r17 r22 into r23;
	add r13 r23 into r24;
	cast r24 into r25 as u128;
	cast r22 into r26 as u128;
	cast r14 into r27 as u128;
	mul r27 1000u128 into r28;
	div r28 r25 into r29;
	add r25 r26 into r30;
	mul r30 r29 into r31;
	div r31 1000u128 into r32;
	sub r32 r27 into r33;
	cast r33 into r34 as u64;
	get.or_use delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru] 0u64 into r35;
	add r35 r34 into r36;
	set r36 into delegator_shares[aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru];
	add r14 r34 into r37;
	add r24 r22 into r38;
	cast r1 into r39 as u128;
	mul r39 1000u128 into r40;
	cast r37 into r41 as u128;
	div r40 r41 into r42;
	cast r38 into r43 as u128;
	mul r43 r42 into r44;
	div r44 1000u128 into r45;
	cast r2 into r46 as u128;
	gte r45 r46 into r47;
	assert.eq r47 true;
	div block.height 1_000u32 into r48;
	mul r48 1_000u32 into r49;
	add r49 1_000u32 into r50;
	ternary r7 r50 r5 into r51;
	set r51 into current_batch_height[0u8];
	cast r2 r51 into r52 as withdrawal_state;
	set r52 into withdrawals[r3];
	get pending_withdrawal[0u8] into r53;
	add r53 r2 into r54;
	set r54 into pending_withdrawal[0u8];
	sub r38 r2 into r55;
	set r55 into total_balance[0u8];
	sub r37 r1 into r56;
	set r56 into total_shares[0u8];
	sub r10 r1 into r57;
	set r57 into delegator_shares[r3];
```
```leo
transition withdraw_public(withdrawal_shares: u64, total_withdrawal: u64) {
	credits.aleo/unbond_public(total_withdrawal);


	return then finalize(withdrawal_shares, total_withdrawal, self.caller);
  }


  finalize withdraw_public(withdrawal_shares: u64, total_withdrawal: u64, owner: address) {
	// Assert that they don't have any pending withdrawals
	let currently_withdrawing: bool = withdrawals.contains(owner);
	assert_eq(currently_withdrawing, false);


	// Determine if the withdrawal can fit into the current batch
	let current_batch: u32 = current_batch_height.get_or_use(0u8, 0u32);
	let min_claim_height: u32 = block.height + UNBONDING_PERIOD;
	let new_batch: bool = current_batch == 0u32;
	let unbonding_allowed: bool = new_batch || current_batch >= min_claim_height;
	assert(unbonding_allowed);


	// Assert that they have enough to withdraw
	let delegator_balance: u64 = delegator_shares.get(owner);
	assert(delegator_balance >= withdrawal_shares);


	// Distribute shares for new commission
	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
	let commission_rate: u128 = commission_percent.get(0u8);
	let new_commission: u64 = get_commission(rewards as u128, commission_rate);
	current_balance += rewards - new_commission;


	let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, new_commission as u128, current_shares as u128);
	let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
	delegator_shares.set(ADMIN, current_commission + new_commission_shares);


	current_shares += new_commission_shares;
	current_balance += new_commission;


	// Calculate withdrawal amount
	let withdraw_ratio: u128 = (withdrawal_shares as u128 * PRECISION_UNSIGNED) / current_shares as u128;
	let withdrawal_calculation: u128 = (current_balance as u128 * withdraw_ratio) / PRECISION_UNSIGNED;


	// If the calculated withdrawal amount is greater than total_withdrawal, the excess will stay in the pool
	assert(withdrawal_calculation >= total_withdrawal as u128);


	// Update withdrawals mappings
	let batch_height: u32 = new_batch ? get_new_batch_height(block.height) : current_batch;
	current_batch_height.set(0u8, batch_height);
	let withdrawal: withdrawal_state = withdrawal_state {
  	microcredits: total_withdrawal,
  	claim_block: batch_height
	};
	withdrawals.set(owner, withdrawal);


	// Update pending withdrawal
	let currently_pending: u64 = pending_withdrawal.get(0u8);
	pending_withdrawal.set(0u8, currently_pending + total_withdrawal);


	// Update total balance
	total_balance.set(0u8, current_balance - total_withdrawal);


	// Update total shares
	total_shares.set(0u8, current_shares - withdrawal_shares);


	// Update delegator_shares mapping
	delegator_shares.set(owner, delegator_balance - withdrawal_shares);
  }
```
#### Get New Batch Height
`get_new_batch_height` is an inline function (i.e. a helper function that, when compiled to aleo instructions, is inserted directly everywhere it is called) takes one argument: `height` as a u32, representing the current block height.
`get_new_batch_height` rounds up the current `block.height` to the nearest 1000th block height. Given an input of 0, we expect an output of 1000. Given input of 999, we expect an output of 1000.
```leo
  inline get_new_batch_height(height: u32) -> u32 {
	let rounded_down: u32 = (height) / 1_000u32 * 1_000u32;
	let rounded_up: u32 = rounded_down + 1_000u32;
	return rounded_up;
  }
```
#### Create Withdraw Claim
`create_withdraw_claim` takes one argument: `withdrawal_shares`, as a u64. Withdrawal shares are the amount of shares to burn in exchange for their proportional amount of the protocol’s microcredits.
`create_withdraw_claim` is intended to be used in special circumstances for the protocol. The credits of the protocol should all be unbonded, which means that credits are not earning rewards, and withdrawers do not need to call `unbond_public` from the `credits.aleo` program.
In a nutshell, the concerns of the finalize portion of `create_withdraw_claim` are to:
- Assert that the protocol is fully unbonded from any validator
- Ensure that the withdrawer can withdraw – i.e. they are not currently withdrawing and they have at least as many shares as they are attempting to burn
- Create a `withdrawal_state` so that the withdrawer may claim their credits
- Update the protocol state
```aleo
function create_withdraw_claim:
	input r0 as u64.public;
	async create_withdraw_claim r0 self.caller into r1;
	output r1 as staking_lite.aleo/create_withdraw_claim.future;


finalize create_withdraw_claim:
	input r0 as u64.public;
	input r1 as address.public;
	contains withdrawals[r1] into r2;
	assert.eq r2 false;
	get.or_use credits.aleo/bonded[aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny] 0u64 into r3;
	assert.eq r3 0u64;
	get delegator_shares[r1] into r4;
	gte r4 r0 into r5;
	assert.eq r5 true;
	get total_balance[0u8] into r6;
	get total_shares[0u8] into r7;
	cast r0 into r8 as u128;
	mul r8 1000u128 into r9;
	cast r7 into r10 as u128;
	div r9 r10 into r11;
	cast r6 into r12 as u128;
	mul r12 r11 into r13;
	div r13 1000u128 into r14;
	cast r14 into r15 as u64;
	cast r15 block.height into r16 as withdrawal_state;
	set r16 into withdrawals[r1];
	get pending_withdrawal[0u8] into r17;
	add r17 r15 into r18;
	set r18 into pending_withdrawal[0u8];
	sub r6 r15 into r19;
	set r19 into total_balance[0u8];
	sub r7 r0 into r20;
	set r20 into total_shares[0u8];
	sub r4 r0 into r21;
	set r21 into delegator_shares[r1];
```leo
  transition create_withdraw_claim(withdrawal_shares: u64) {
	return then finalize(withdrawal_shares, self.caller);
  }


  finalize create_withdraw_claim(withdrawal_shares: u64, owner: address) {
	// Assert that they don't have any pending withdrawals
	let currently_withdrawing: bool = withdrawals.contains(owner);
	assert_eq(currently_withdrawing, false);


	let bonded: u64 = 0u64; // credits.aleo/bonded.get(CORE_PROTOCOL);
	assert_eq(bonded, 0u64);


	// Assert that they have enough to withdraw
	let delegator_balance: u64 = delegator_shares.get(owner);
	assert(delegator_balance >= withdrawal_shares);


	// Calculate withdrawal amount
	let current_balance: u64 = total_balance.get(0u8);
	let current_shares: u64 = total_shares.get(0u8);
	let withdraw_ratio: u128 = (withdrawal_shares as u128 * PRECISION_UNSIGNED) / current_shares as u128;
	let withdrawal_calculation: u128 = (current_balance as u128 * withdraw_ratio) / PRECISION_UNSIGNED;
	let total_withdrawal: u64 = withdrawal_calculation as u64;


	// Update withdrawals mappings
	let withdrawal: withdrawal_state = withdrawal_state {
  	microcredits: total_withdrawal,
  	claim_block: block.height
	};
	withdrawals.set(owner, withdrawal);


	// Update pending withdrawal
	let currently_pending: u64 = pending_withdrawal.get(0u8);
	pending_withdrawal.set(0u8, currently_pending + total_withdrawal);


	// Update total balance
	total_balance.set(0u8, current_balance - total_withdrawal);


	// Update total shares
	total_shares.set(0u8, current_shares - withdrawal_shares);


	// Update delegator_shares mapping
	delegator_shares.set(owner, delegator_balance - withdrawal_shares);
  }
```
#### Claim Withdrawal Public
`claim_withdrawal_public` takes two arguments: `recipient` as an address, and `amount` as a u64. Given that a withdrawer has a withdrawal claim, they can pass in a `recipient` to receive `amount`. Note, to keep the protocol simple, the `amount` must be the full amount of their withdrawal claim.
`claim_withdrawal_public` is intended to be used at any point that the withdrawer has a withdraw claim with a `claim_height` that is greater than or equal to the current block height.
In a nutshell, the concerns of the finalize portion of `claim_withdrawal_public` are to:
- Ensure that the withdrawer can withdraw and that the withdrawer is withdrawing everything in the claim
- Remove the `withdrawal_state` so that the withdrawer may claim more credits in a separate withdrawal process
- Update the protocol state
```aleo
function claim_withdrawal_public:
	input r0 as address.public;
	input r1 as u64.public;
	call credits.aleo/transfer_public r0 r1 into r2;
	async claim_withdrawal_public r2 r0 r1 into r3;
	output r3 as staking_lite.aleo/claim_withdrawal_public.future;


finalize claim_withdrawal_public:
	input r0 as credits.aleo/transfer_public.future;
	input r1 as address.public;
	input r2 as u64.public;
	await r0;
	get withdrawals[r1] into r3;
	gte block.height r3.claim_block into r4;
	assert.eq r4 true;
	assert.eq r3.microcredits r2;
	remove withdrawals[r1];
	get pending_withdrawal[0u8] into r5;
	sub r5 r2 into r6;
	set r6 into pending_withdrawal[0u8];
```
```leo
  transition claim_withdrawal_public(recipient: address, amount: u64) {
	credits.aleo/transfer_public(recipient, amount);


	return then finalize(recipient, amount);
  }


  finalize claim_withdrawal_public(owner: address, amount: u64) {
	let withdrawal: withdrawal_state = withdrawals.get(owner);
	assert(block.height >= withdrawal.claim_block);
	assert_eq(withdrawal.microcredits, amount);


	// Remove withdrawal
withdrawals.remove(owner);


	// Update pending withdrawal
	let currently_pending: u64 = pending_withdrawal.get(0u8);
	pending_withdrawal.set(0u8, currently_pending - amount);
  }
```


## Test Cases
We are implementing test cases to ensure this protocol works as expected, and always allows for depositors to recollect their funds. The major test cases we want to include in our suite are:
- The protocol funds are always able to be withdrawn by depositors
-- In normal operation
-- When everything has unbonded through the protocol
-- When a validator forcibly unbonds the protocol’s stake
- unbond_all always unbonds everything without exception
- validators may not hike up commission rates to affect unclaimed commission
- Depositors get their proportional amount of shares, rounded down the nearest share (at 1000 shares per microcredit for precision)

## Dependencies
As this is an application ARC, there are no dependencies other than what is currently available in Aleo, except for transfer_public_signer, which is necessary to remove private state from the program.

## Backwards Compatibility
Not necessary.

## Security & Compliance
This is an application ARC standard, so this only affects the security of managing assets on-chain. We will have this code audited by an external firm. For compliance purposes, this program will operate publicly, without records.

## References
- [Previous ARC-38 discussion](https://github.com/AleoHQ/ARCs/discussions/52)
- [Pull request for delegated staking](https://github.com/demox-labs/aleo-staking/pull/1)