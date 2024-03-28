import credits.aleo;

program arc_0038.aleo {
  // Owner of the program
  const ADMIN: address = aleo1kf3dgrz9lqyklz8kqfy0hpxxyt78qfuzshuhccl02a5x43x6nqpsaapqru;
  // Address of this program
  const CORE_PROTOCOL: address = aleo1j0zju7f0fpgv98gulyywtkxk6jca99l6425uqhnd5kccu4jc2grstjx0mt;
  const SHARES_TO_MICROCREDITS: u64 = 1000u64;
  const PRECISION_UNSIGNED: u128 = 1000u128;
  const MAX_COMMISSION_RATE: u128 = 500u128;
  const UNBONDING_PERIOD: u32 = 360u32;
  const MINIMUM_BOND_AMOUNT: u64 = 1000000000u64;

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

  // 0u8 -> balance of deposits that have not been bonded, updated when calling "bond_all"
  mapping pending_deposits: u8 => u64;

  // 0u8 -> total pool of delegator shares
  mapping total_shares: u8 => u64;

  // address -> number of shares held by the delegator with this address
  mapping delegator_shares: address => u64;

  // 0u8 -> balance pending withdrawal currently unbonding
  // 1u8 -> balance pending withdrawal owned by the program
  mapping pending_withdrawal: u8 => u64;

  /** Unbonding allowed: 0u8 ->
    * The height at which the current withdrawal batch will be done unbonding
    * if not present or == 0u32, a new batch can begin unbonding
  */
  mapping current_batch_height: u8 => u32;

  struct withdrawal_state {
    microcredits: u64,
    claim_block: u32
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
    let initialized: bool = is_initialized.get_or_use(0u8, false);
    assert_eq(initialized, false);

    is_initialized.set(0u8, true);
    commission_percent.set(0u8, commission_rate);
    validator.set(0u8, validator_address);
    total_shares.set(0u8, 0u64);
    total_balance.set(0u8, 0u64);
    pending_deposits.set(0u8, 0u64);
    pending_withdrawal.set(0u8, 0u64);
    pending_withdrawal.set(1u8, 0u64);
    current_batch_height.set(0u8, 0u32);
  }

  transition initial_deposit(
    public microcredits: u64,
    public validator_address: address
  ) {
    assert_eq(self.caller, ADMIN);
    // credits.aleo/transfer_public_as_signer(CORE_PROTOCOL, microcredits);
    credits.aleo/transfer_public(CORE_PROTOCOL, microcredits);
    credits.aleo/bond_public(validator_address, microcredits);

    return then finalize(microcredits);
  }

  finalize initial_deposit(microcredits: u64) {
    assert(is_initialized.get(0u8));

    let balance: u64 = total_balance.get_or_use(0u8, 0u64);
    let shares: u64 = total_shares.get_or_use(0u8, 0u64);
    assert_eq(balance, 0u64);
    assert_eq(shares, 0u64);

    total_balance.set(0u8, microcredits);
    shares = microcredits * SHARES_TO_MICROCREDITS;
    total_shares.set(0u8, shares);
    delegator_shares.set(ADMIN, shares);
  }

  inline get_commission(
    rewards: u128,
    commission_rate: u128,
  ) -> u64 {
    let commission: u128 = rewards * commission_rate / PRECISION_UNSIGNED;
    let commission_64: u64 = commission as u64;
    return commission_64;
  }

  transition get_commission_test(rewards: u128, commission_rate: u128) -> u64 {
    return get_commission(rewards, commission_rate);
  }

  inline calculate_new_shares(bonded_balance: u128, pending_deposit_pool: u128, deposit: u128, shares: u128) -> u64 {
    let full_balance: u128 = bonded_balance + pending_deposit_pool;
    let new_total_shares: u128 = (shares * PRECISION_UNSIGNED) * (full_balance + deposit) / (full_balance * PRECISION_UNSIGNED);
    let diff: u128 = new_total_shares - shares;
    let shares_to_mint: u64 = diff as u64;
    return shares_to_mint;
  }

  transition calculate_new_shares_test(bonded_balance: u128, pending_deposit_pool: u128, deposit: u128, shares: u128) -> u64 {
    return calculate_new_shares(bonded_balance, pending_deposit_pool, deposit, shares);
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
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    let current_balance: u64 = total_balance.get(0u8);
    let current_shares: u64 = total_shares.get(0u8);
    let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
    let commission_rate: u128 = commission_percent.get(0u8);
    let new_commission: u64 = get_commission(rewards as u128, commission_rate);
    current_balance += rewards - new_commission;

    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, new_commission as u128, current_shares as u128);
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

    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    // Assert that the pool was fully unbonded
    assert_eq(bonded, 0u64);

    // Make sure all commission is claimed before unbonding
    let base_unbonding: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let unbonding: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base_unbonding).microcredits;
    let unbonding_withdrawals: u64 = pending_withdrawal.get(0u8);
    let previously_bonded: u64 = unbonding - unbonding_withdrawals;
    let current_balance: u64 = total_balance.get(0u8);
    let current_shares: u64 = total_shares.get(0u8);
    let rewards: u64 = previously_bonded > current_balance ? previously_bonded - current_balance : 0u64;
    let commission_rate: u128 = commission_percent.get(0u8);
    let new_commission: u64 = get_commission(rewards as u128, commission_rate);
    current_balance += rewards - new_commission;

    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, new_commission as u128, current_shares as u128);
    let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
    delegator_shares.set(ADMIN, current_commission + new_commission_shares);

    total_shares.set(0u8, current_shares + new_commission_shares);
    total_balance.set(0u8, current_balance + new_commission);
  }

  transition claim_unbond() {
    credits.aleo/claim_unbond_public();

    return then finalize();
  }

  finalize claim_unbond() {
    current_batch_height.remove(0u8);
    let unbonding_withdrawals: u64 = pending_withdrawal.get(0u8);
    let already_claimed: u64 = pending_withdrawal.get(1u8);
    already_claimed += unbonding_withdrawals;

    pending_withdrawal.set(0u8, 0u64);
    pending_withdrawal.set(1u8, already_claimed);
  }

  transition bond_all(public validator_address: address, public amount: u64) {
    // Call will fail if there is any balance still bonded to another validator
    credits.aleo/bond_public(validator_address, amount);

    return then finalize(validator_address, amount);
  }

  finalize bond_all(validator_address: address, amount: u64) {
    let account_balance: u64 = total_balance.get(1u8); // credits.aleo/account.get(CORE_PROTOCOL);
    let pending_withdrawals: u64 = pending_withdrawal.get(1u8);
    assert(account_balance >= pending_withdrawals);

    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    let current_balance: u64 = total_balance.get(0u8);
    let pending_deposit_balance: u64 = pending_deposits.get(0u8);

    pending_deposit_balance = pending_deposit_balance + current_balance - bonded;
    pending_deposits.set(0u8, pending_deposit_balance);
    total_balance.set(0u8, bonded);

    // Set validator
    let next_validator: address = validator.get(1u8);
    assert_eq(validator_address, next_validator);

    validator.set(0u8, next_validator);
    validator.remove(1u8);
  }

  transition bond_deposits(public validator_address: address, public amount: u64) {
    // Call will fail if there is any balance still bonded to another validator
    credits.aleo/bond_public(validator_address, amount);

    return then finalize(validator_address, amount);
  }

  finalize bond_deposits(validator_address: address, amount: u64) {
    let account_balance: u64 = total_balance.get(1u8); // credits.aleo/account.get(CORE_PROTOCOL);
    let pending_withdrawals: u64 = pending_withdrawal.get(1u8);
    assert(account_balance >= pending_withdrawals);

    let current_balance: u64 = total_balance.get(0u8);
    let pending_deposit_balance: u64 = pending_deposits.get(0u8);

    pending_deposit_balance = pending_deposit_balance - amount;
    pending_deposits.set(0u8, pending_deposit_balance);
    total_balance.set(0u8, current_balance + amount);

    let has_next_validator: bool = validator.contains(1u8);
    assert_eq(has_next_validator, false);
  }

  transition claim_commission() {
    assert_eq(self.caller, ADMIN);
    return then finalize();
  }

  finalize claim_commission() {
    // Distribute shares for new commission
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    let current_balance: u64 = total_balance.get(0u8);
    let current_shares: u64 = total_shares.get(0u8);
    let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
    let commission_rate: u128 = commission_percent.get(0u8);
    let new_commission: u64 = get_commission(rewards as u128, commission_rate);
    current_balance += rewards - new_commission;

    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, new_commission as u128, current_shares as u128);
    let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
    delegator_shares.set(ADMIN, current_commission + new_commission_shares);

    total_shares.set(0u8, current_shares + new_commission_shares);
    total_balance.set(0u8, current_balance + new_commission);
  }

  transition deposit_public(
    public microcredits: u64
  ) {
    // credits.aleo/transfer_public_as_signer(CORE_PROTOCOL, microcredits);
    credits.aleo/transfer_public(CORE_PROTOCOL, microcredits);
    return then finalize(self.caller, microcredits);
  }

  finalize deposit_public(
    caller: address,
    microcredits: u64
  ) {
    // Distribute shares for new commission
    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits; // credits.aleo/bonded.get(CORE_PROTOCOL).microcredits;
    let current_balance: u64 = total_balance.get(0u8);
    let current_shares: u64 = total_shares.get(0u8);
    let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
    let commission_rate: u128 = commission_percent.get(0u8);
    let new_commission: u64 = get_commission(rewards as u128, commission_rate);
    current_balance += rewards - new_commission;

    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, new_commission as u128, current_shares as u128);
    let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
    delegator_shares.set(ADMIN, current_commission + new_commission_shares);

    current_shares += new_commission_shares;
    current_balance += new_commission;
    // Update total balance
    total_balance.set(0u8, current_balance);

    // Calculate mint for deposit
    let new_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, microcredits as u128, current_shares as u128);

    // Ensure mint amount is valid
    assert(new_shares >= 1u64);

    // Update delegator_shares mapping
    let shares: u64 = delegator_shares.get_or_use(caller, 0u64);
    delegator_shares.set(caller, shares + new_shares);

    // Update total shares
    total_shares.set(0u8, current_shares + new_shares);

    // Update pending_deposits
    let pending: u64 = pending_deposits.get(0u8);
    pending_deposits.set(0u8, pending + microcredits);
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

    // Prevent a full unbond if there are pending deposits to maintain the minimum bond amount
    // Simulate call to credits.aleo/unbonding.get_or_use(CORE_PROTOCOL).microcredits;
    let base_unbonding: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let unbonding: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base_unbonding).microcredits;
    let unbonding_withdrawals: u64 = pending_withdrawal.get(0u8);
    let newly_unbonded: u64 = unbonding - unbonding_withdrawals;
    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let sufficient_deposits: bool = newly_unbonded - total_withdrawal + pending_deposit_pool >= MINIMUM_BOND_AMOUNT;

    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    // Allow the withdrawal if the pool is still bonded, or if there are not enough deposits to maintain the minimum bond amount
    assert(bonded >= MINIMUM_BOND_AMOUNT || !sufficient_deposits);

    // Distribute shares for new commission
    // Add back the withdrawal amount to appropriately calculate rewards before the withdrawal
    bonded += total_withdrawal;
    let current_balance: u64 = total_balance.get(0u8);
    let current_shares: u64 = total_shares.get(0u8);
    let rewards: u64 = bonded > current_balance ? bonded - current_balance : 0u64;
    let commission_rate: u128 = commission_percent.get(0u8);
    let new_commission: u64 = get_commission(rewards as u128, commission_rate);
    current_balance += rewards - new_commission;

    let new_commission_shares: u64 = calculate_new_shares(current_balance as u128, pending_deposit_pool as u128, new_commission as u128, current_shares as u128);
    let current_commission: u64 = delegator_shares.get_or_use(ADMIN, 0u64);
    delegator_shares.set(ADMIN, current_commission + new_commission_shares);

    current_shares += new_commission_shares;
    current_balance += new_commission;

    // Calculate full pool size
    let full_pool: u128 = current_balance as u128 + pending_deposit_pool as u128;

    // Calculate withdrawal amount
    let withdrawal_calculation: u128 = (withdrawal_shares as u128 * full_pool as u128 * PRECISION_UNSIGNED) / (current_shares as u128 * PRECISION_UNSIGNED);

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
    pending_withdrawal.set(0u8, unbonding_withdrawals + total_withdrawal);

    // Update total balance
    total_balance.set(0u8, current_balance - total_withdrawal);

    // Update total shares
    total_shares.set(0u8, current_shares - withdrawal_shares);

    // Update delegator_shares mapping
    delegator_shares.set(owner, delegator_balance - withdrawal_shares);
  }

  inline get_new_batch_height(height: u32) -> u32 {
    let rounded_down: u32 = (height) / 1000u32 * 1000u32;
    let rounded_up: u32 = rounded_down + 1000u32;
    return rounded_up;
  }

  transition get_new_batch_height_test(height: u32) -> u32 {
    return get_new_batch_height(height);
  }

  transition create_withdraw_claim(public withdrawal_shares: u64) {
    return then finalize(withdrawal_shares, self.caller);
  }

  finalize create_withdraw_claim(withdrawal_shares: u64, owner: address) {
    // Assert that they don't have any pending withdrawals
    let currently_withdrawing: bool = withdrawals.contains(owner);
    assert_eq(currently_withdrawing, false);

    // Simulate call to credits.aleo/bonded.get_or_use(CORE_PROTOCOL).microcredits;
    let base: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let bonded: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base).microcredits;
    assert_eq(bonded, 0u64);

    // Simulate call to credits.aleo/unbonding.get_or_use(CORE_PROTOCOL).microcredits;
    let base_unbonding: withdrawal_state = withdrawal_state {
      microcredits: 0u64,
      claim_block: 0u32
    };
    let unbonding: u64 = withdrawals.get_or_use(CORE_PROTOCOL, base_unbonding).microcredits;
    assert_eq(unbonding, 0u64);

    // Assert that they have enough to withdraw
    let delegator_balance: u64 = delegator_shares.get(owner);
    assert(delegator_balance >= withdrawal_shares);

    // Calculate withdrawal amount
    let current_balance: u64 = total_balance.get(0u8);
    let pending_deposit_pool: u64 = pending_deposits.get(0u8);
    let full_pool: u128 = current_balance as u128 + pending_deposit_pool as u128;
    let current_shares: u64 = total_shares.get(0u8);
    let withdrawal_calculation: u128 = (withdrawal_shares as u128 * full_pool * PRECISION_UNSIGNED) / (current_shares as u128 * PRECISION_UNSIGNED);
    let total_withdrawal: u64 = withdrawal_calculation as u64;

    // Update withdrawals mappings
    let claim_height: u32 = block.height + 1u32;
    let withdrawal: withdrawal_state = withdrawal_state {
      microcredits: total_withdrawal,
      claim_block: claim_height
    };
    withdrawals.set(owner, withdrawal);

    // Update pending withdrawal
    let currently_pending: u64 = pending_withdrawal.get(1u8);
    pending_withdrawal.set(1u8, currently_pending + total_withdrawal);

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
    let currently_pending: u64 = pending_withdrawal.get(1u8);
    pending_withdrawal.set(1u8, currently_pending - amount);
  }
}