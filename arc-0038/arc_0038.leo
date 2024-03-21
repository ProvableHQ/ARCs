import credits.aleo;

program arc_0038.aleo {
  // Owner of the program
  const ADMIN: address = aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
  // Address of this program
  const CORE_PROTOCOL: address = aleo17hwvp7fl5da40hd29heasjjm537uqce489hhuc3lwhxfm0njucpq0rvfny;
  const SHARES_TO_MICROCREDITS: u64 = 1_000u64;
  const PRECISION_UNSIGNED: u128 = 1000u128;
  const MAX_COMMISSION_RATE: u128 = 500u128;
  const UNBONDING_PERIOD: u32 = 360u32;
  const MINIMUM_BOND_POOL: u64 = 10_000_000_000u64;

  // 0u8 -> Whether the program has been initialized
  mapping is_initialized: u8 => bool;

  /** Commission rate: 0u8 -> u128
    * percentage of rewards taken as commission
    * relative to precision of 1000
    * e.g. 100u128 = 10%
  */
  mapping commission_percent: u8 => u128;

  // 0u8 -> address of validator
  // 1u8 -> the address of the next validator, automatically updated after calling "bond_all"
  mapping validator: u8 => address;

  // 0u8 -> total balance of microcredits pooled
  mapping total_balance: u8 => u64;

  // 0u8 -> total pool of delegator shares
  mapping total_shares: u8 => u64;

  // address -> number of shares held by the delegator with this address
  mapping delegator_shares: address => u64;

  // 0u8 -> balance pending withdrawal in microcredits
  mapping pending_withdrawal: u8 => u64;

  /** Unbonding allowed: 0u8 ->
    * The height at which the current withdrawal batch will be done unbonding
    * if not present or == 0u32, a new batch can begin unbonding
  */
  mapping current_batch_height: u8 => u32;

  struct withdrawal_state {
    microcredits: u64;
    claim_block: u32;
  }

  // address -> pending withdrawal for the delegator with this address
  mapping withdrawals: address => withdrawal_state;

  transition initialize(public commission_rate: u128, public validator_address: address) {
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

  transition initial_deposit(
    public input_record: credits.aleo/credits,
    public microcredits: u64,
    public validator_address: address
  ) -> credits.aleo/credits {
    assert_eq(self.caller, ADMIN);
    // Must be a credits record because credits.aleo uses self.caller for transfers
    let updated_record: credits.aleo/credits = credits.aleo/transfer_private_to_public(input_record, CORE_PROTOCOL, microcredits);
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

  inline get_commission(
    rewards: u128,
    commission_rate: u128,
  ) -> u64 {
    let commission: u128 = rewards * commission_rate / PRECISION_UNSIGNED;
    let commission_64: u64 = commission as u64;
    return commission_64;
  }

  inline calculate_new_shares(balance: u128, deposit: u128, shares: u128) -> u64 {
    let pool_ratio: u128 = ((shares * PRECISION_UNSIGNED) / balance);
    let new_total_shares: u128 = (balance + deposit) * pool_ratio;
    let diff: u128 = (new_total_shares / PRECISION_UNSIGNED) - shares;
    let shares_to_mint: u64 = diff as u64;
    return shares_to_mint;
  }

  transition set_commission_percent(public new_commission_rate: u128) {
    assert_eq(self.caller, ADMIN);
    assert(new_commission_rate < PRECISION_UNSIGNED);
    assert(new_commission_rate <= MAX_COMMISSION_RATE);

    return then finalize(new_commission_rate);
  }

  finalize set_commission_percent(new_commission_rate: u128) {
    // Make sure all commission is claimed before changing the rate
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits;
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

    commission_percent.set(0u8, new_commission_rate);
  }

  // Update the validator address, to be applied automatically on the next bond_all call
  transition set_next_validator(public validator_address: address) {
    assert_eq(self.caller, ADMIN);

    return then finalize(validator_address);
  }

  finalize set_next_validator(validator_address: address) {
    validator.set(1u8, validator_address);
  }

  transition unbond_all(public pool_balance: u64) {
    credits.aleo/unbond_public(pool_balance);

    return then finalize(pool_balance);
  }

  finalize unbond_all(pool_balance: u64) {
    let next_validator: bool = validator.contains(1u8);
    assert(next_validator);

    // Make sure all commission is claimed before unbonding
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits;
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

  transition claim_unbond() {
    credits.aleo/claim_unbond_public();

    return then finalize();
  }

  finalize claim_unbond() {
    current_batch_height.remove(0u8);
  }

  transition bond_all(public validator_address: address, public amount: u64) {
    // Call will fail if there is any balance still bonded to another validator
    credits.aleo/bond_public(validator_address, amount);

    return then finalize(validator_address, amount);
  }

  finalize bond_all(validator_address: address, amount: u64) {
    // Simulate call to credits.aleo/unbonding.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let unbonding_balance: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits;
    assert_eq(unbonding_balance, 0u64);

    let account_balance: u64 = total_balance.get(1u8); // credits.aleo/account.get(CORE_PROTOCOL);
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

  transition claim_commission() {
    assert_eq(self.caller, ADMIN);
    return then finalize();
  }

  finalize claim_commission() {
    // Distribute shares for new commission
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits;
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

  transition deposit_public(
    public input_record: credits.aleo/credits,
    public microcredits: u64
  ) -> credits.aleo/credits {
    // Must be a credits record because credits.aleo uses self.caller for transfers
    let updated_record: credits.aleo/credits = credits.aleo/transfer_private_to_public(input_record, CORE_PROTOCOL, microcredits);

    return (updated_record) then finalize(self.caller, microcredits);
  }

  finalize deposit_public(
    caller: address,
    microcredits: u64
  ) {
    // Distribute shares for new commission
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits; // credits.aleo/bonded.get(CORE_PROTOCOL).microcredits;
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

  transition withdraw_public(public withdrawal_shares: u64, public total_withdrawal: u64) {
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
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits; // credits.aleo/bonded.get(CORE_PROTOCOL).microcredits;
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

  inline get_new_batch_height(height: u32) -> u32 {
    let rounded_down: u32 = (height) / 1_000u32 * 1_000u32;
    let rounded_up: u32 = rounded_down + 1_000u32;
    return rounded_up;
  }

  transition create_withdraw_claim(public withdrawal_shares: u64) {
    return then finalize(withdrawal_shares, self.caller);
  }

  finalize create_withdraw_claim(withdrawal_shares: u64, owner: address) {
    // Assert that they don't have any pending withdrawals
    let currently_withdrawing: bool = withdrawals.contains(owner);
    assert_eq(currently_withdrawing, false);

    // Simulate call to credits.aleo/unbonding.get_or_use(CORE_PROTOCOL).microcredits;
    let default: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, default).microcredits;
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

  transition claim_withdrawal_public(public recipient: address, public amount: u64) {
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
}