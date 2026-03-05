// Leo analog of the built-in credits.aleo program (credits_clone).
// This file is for local testing and specification purposes only.
// In production, programs import credits.aleo directly from the AVM.
//
// Source: https://raw.githubusercontent.com/AleoNet/snarkVM/refs/heads/mainnet/synthesizer/program/src/resources/credits.aleo
//
// Exceptions from on-chain:
// - Renamed to credits_clone.aleo for local imports

program credits_clone.aleo {

    // -------------------------
    // Structs
    // -------------------------

    struct committee_state {
        is_open: bool,
        commission: u8,
    }

    struct bond_state {
        validator: address,
        microcredits: u64,
    }

    struct unbond_state {
        microcredits: u64,
        height: u32,
    }

    // -------------------------
    // Records
    // -------------------------

    record credits {
        owner: address,
        microcredits: u64,
    }

    // -------------------------
    // Mappings
    // -------------------------

    mapping committee: address => committee_state;
    mapping delegated: address => u64;
    mapping metadata: address => u32;  // Value type is u32, not u64, to match the on-chain program.
    mapping bonded: address => bond_state;
    mapping unbonding: address => unbond_state;
    mapping account: address => u64;
    mapping withdraw: address => address;

    // The metadata mapping uses special addresses as keys.
    // The committee count is stored at aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc.
    // The delegator count is stored at aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0.

    // -------------------------
    // Constructor
    // -------------------------

    @noupgrade
    constructor() {}

    // -------------------------
    // Functions
    // -------------------------

    // Allows a validator to bond their microcredits to themselves and specify a withdrawal address
    // and commission percentage.
    fn bond_validator(
        public withdrawal: address,
        public amount: u64,
        public commission: u8,
    ) -> Final {
        // Ensure the withdrawal address is not the validator address.
        assert(self.signer != withdrawal);
        // Determine if the amount is at least 1 credit.
        assert(amount >= 1_000_000u64);
        // Ensure the commission percentage does not exceed 100%.
        assert(commission <= 100u8);

        let validator: address = self.signer;
        return final {
            // Retrieve the withdrawal address for the validator.
            let stored_withdrawal: address = withdraw.get_or_use(validator, withdrawal);
            // Ensure that the withdrawal address is consistent.
            assert(withdrawal == stored_withdrawal);

            // Construct the initial committee state (is_open = true by default).
            let initial_committee: committee_state = committee_state { is_open: true, commission: commission };
            // Retrieve the committee state of the specified validator.
            let current_committee: committee_state = committee.get_or_use(validator, initial_committee);
            // Ensure the commission percentage remains unchanged.
            assert(commission == current_committee.commission);

            // Construct the initial bond state.
            let initial_bond: bond_state = bond_state { validator: validator, microcredits: 0u64 };
            // Get the bond state for the validator, or default to the initial bond state.
            let current_bond: bond_state = bonded.get_or_use(validator, initial_bond);
            // Enforce the validator matches in the bond state (must be self-bonded).
            assert(current_bond.validator == validator);

            // Increment the amount of microcredits for the bond state.
            let new_microcredits: u64 = current_bond.microcredits + amount;
            let new_bond: bond_state = bond_state { validator: validator, microcredits: new_microcredits };

            // Include total pre-delegated amount when deciding if validator has enough credits.
            let existing_delegated: u64 = delegated.get_or_use(validator, 0u64);
            let total_delegated: u64 = amount + existing_delegated;
            // Enforce total is at least 10 million credits.
            assert(total_delegated >= 10_000_000_000_000u64);

            // Get the balance of the validator. Fails if account doesn't exist.
            let bal: u64 = account.get(validator);
            // Decrement the balance.
            let new_bal: u64 = bal - amount;

            // For a new validator, verify that it is not yet registered in the committee.
            let is_in_committee: bool = committee.contains(validator);
            if (!is_in_committee) {
                // Set the withdrawal address on first entry.
                withdraw.set(validator, stored_withdrawal);

                // Check if the initial bond amount is at least 100 credits.
                assert(amount >= 100_000_000u64);

                // Get the committee size.
                let committee_size: u32 = metadata.get_or_use(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, 0u32);
                // Increment the committee size by one.
                metadata.set(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, committee_size + 1u32);

                // Check if the validator exists in the unbonding state.
                let is_unbonding: bool = unbonding.contains(validator);
                // Ensure the validator is not currently unbonding.
                assert(!is_unbonding);
            }

            // Update the committee state of the specified validator.
            committee.set(validator, current_committee);
            // Update the delegated amount.
            delegated.set(validator, total_delegated);
            // Update the bond state for the validator.
            bonded.set(validator, new_bond);
            // Update the balance of the validator.
            account.set(validator, new_bal);
        };
    }

    // Allows any delegator to bond their microcredits to a validator and specify a withdrawal address.
    fn bond_public(
        public validator: address,
        public withdrawal: address,
        public amount: u64,
    ) -> Final {
        // Determine if the amount is at least one credit.
        assert(amount >= 1_000_000u64);
        // Do not allow self-bonding. Validators start with bond_validator.
        assert(self.caller != validator);

        let caller: address = self.caller;
        return final {
            // Retrieve the withdrawal address for the staker.
            let stored_withdrawal: address = withdraw.get_or_use(caller, withdrawal);
            // Ensure that the withdrawal address is consistent.
            assert(withdrawal == stored_withdrawal);

            // Check if the delegator is already bonded to the validator.
            let is_bonded: bool = bonded.contains(caller);
            if (!is_bonded) {
                // Set the withdrawal address on first entry.
                withdraw.set(caller, withdrawal);

                // Ensure that the validator is open to new stakers.
                let default_committee: committee_state = committee_state { is_open: true, commission: 0u8 };
                let validator_state: committee_state = committee.get_or_use(validator, default_committee);
                assert(validator_state.is_open);

                // Get the number of delegators.
                let delegator_count: u32 = metadata.get_or_use(aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0, 0u32);
                // Increment the number of bonded delegators by one.
                let new_count: u32 = delegator_count + 1u32;
                // Enforce that the number of delegators is less than or equal to 100,000.
                assert(new_count <= 100_000u32);
                // Set the new number of delegators.
                metadata.set(aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0, new_count);
            }

            // Construct the initial bond state.
            let initial_bond: bond_state = bond_state { validator: validator, microcredits: 0u64 };
            // Get the bond state for the caller, or default to the initial bond state.
            let current_bond: bond_state = bonded.get_or_use(caller, initial_bond);
            // Enforce the validator matches in the bond state.
            assert(current_bond.validator == validator);

            // Increment the microcredits in the bond state.
            let new_microcredits: u64 = current_bond.microcredits + amount;
            // Enforce cumulative bond is at least 10 thousand credits.
            assert(new_microcredits >= 10_000_000_000u64);
            let new_bond: bond_state = bond_state { validator: validator, microcredits: new_microcredits };

            // Get the balance of the caller. Fails if account doesn't exist.
            let bal: u64 = account.get(caller);
            // Decrement the balance.
            let new_bal: u64 = bal - amount;

            // Get current total delegated amount.
            let existing_delegated: u64 = delegated.get_or_use(validator, 0u64);
            let new_delegated: u64 = amount + existing_delegated;

            // Check if the validator exists in the unbonding state.
            let is_unbonding: bool = unbonding.contains(validator);
            // Ensure the validator currently is not unbonding.
            assert(!is_unbonding);

            // Update the bond state for the caller.
            bonded.set(caller, new_bond);
            // Update the balance of the caller.
            account.set(caller, new_bal);
            // Update delegated amount.
            delegated.set(validator, new_delegated);
        };
    }

    // Allows any staker to unbond their microcredits from a validator,
    // callable only by using the withdrawal address of the staker or the validator.
    fn unbond_public(
        public staker: address,
        public amount: u64,
    ) -> Final {
        let caller: address = self.caller;
        return final {
            let unlock_height: u32 = block.height + 360u32;
            let default_unbond: unbond_state = unbond_state { microcredits: 0u64, height: unlock_height };

            // Retrieve the staker's bond state. Fails if doesn't exist.
            let bond: bond_state = bonded.get(staker);

            // Get the staker's withdrawal address.
            let staker_withdrawal: address = withdraw.get(staker);
            // Check if the caller's address equals the staker's withdrawal address.
            let caller_is_staker_withdrawal: bool = caller == staker_withdrawal;

            // Check if the validator's withdrawal address has been set.
            let validator_has_withdrawal: bool = withdraw.contains(bond.validator);
            // Get the validator's withdrawal address (zero address as default).
            let zero_addr: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
            let validator_withdrawal: address = withdraw.get_or_use(bond.validator, zero_addr);
            // Check if the validator's withdrawal address matches the caller.
            let caller_is_validator_withdrawal: bool = caller == validator_withdrawal;
            // AND the withdraw address has been set (prevents edge case with zero address).
            let forced_unbond: bool = validator_has_withdrawal && caller_is_validator_withdrawal;

            // Either the caller is the staker's withdrawal address OR the validator's.
            let has_permission: bool = caller_is_staker_withdrawal || forced_unbond;
            assert(has_permission);

            // Check if bonded to self (validator) or to a different address (delegator).
            let is_self_bonded: bool = bond.validator == staker;

            if (!is_self_bonded) {
                // Unbond the delegator.

                // Retrieve or initialize the unbonding state.
                let existing_unbond: unbond_state = unbonding.get_or_use(staker, default_unbond);
                // Retrieve the delegated amount in microcredits for the validator.
                let total_delegated: u64 = delegated.get(bond.validator);

                // Calculate new bonded microcredits after requested unbond.
                let new_bond_amount: u64 = bond.microcredits - amount;

                // Check if the delegator will fall below 10,000 bonded credits.
                let below_min: bool = new_bond_amount < 10_000_000_000u64;

                // If the validator is forcing the delegator to unbond OR delegator falls below minimum.
                let full_unbond: bool = forced_unbond || below_min;

                // Determine the amount to unbond: full bond if below min, otherwise requested amount.
                let unbond_amount: u64 = full_unbond ? bond.microcredits : amount;

                // Increment existing unbond amount by the new unbond amount.
                let new_unbond_total: u64 = existing_unbond.microcredits + unbond_amount;
                // Store the new unbonding state.
                unbonding.set(staker, unbond_state { microcredits: new_unbond_total, height: unlock_height });

                // Calculate the new delegated total for the validator.
                let new_total_delegated: u64 = total_delegated - unbond_amount;
                // Store the new delegated total.
                delegated.set(bond.validator, new_total_delegated);

                if (!full_unbond) {
                    // Partial unbond: update the bonded state.
                    bonded.set(staker, bond_state { validator: bond.validator, microcredits: new_bond_amount });
                } else {
                    // Full unbond: remove the bonded state and decrement the delegator count.
                    bonded.remove(staker);
                    let delegator_count: u32 = metadata.get(aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0);
                    metadata.set(aleo1qgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqanmpl0, delegator_count - 1u32);
                }

                // Check if the new delegated total is at least 10M credits.
                let delegated_sufficient: bool = new_total_delegated >= 10_000_000_000_000u64;
                if (!delegated_sufficient) {
                    // Delegated total below 10M: check if validator needs to be removed from committee.
                    let validator_in_committee: bool = committee.contains(bond.validator);
                    if (validator_in_committee) {
                        // Remove the validator from the committee.
                        let validator_bond: bond_state = bonded.get(bond.validator);
                        let current_delegated: u64 = delegated.get(bond.validator);

                        // Remove the validator from the committee.
                        committee.remove(bond.validator);
                        // Decrement the committee size.
                        let committee_count: u32 = metadata.get(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
                        metadata.set(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, committee_count - 1u32);
                        // Decrease the delegated total by the bonded amount.
                        delegated.set(bond.validator, current_delegated - validator_bond.microcredits);
                        // Remove the bonded state.
                        bonded.remove(bond.validator);
                        // Retrieve or initialize the unbonding state.
                        let existing_validator_unbond: unbond_state = unbonding.get_or_use(bond.validator, default_unbond);
                        // Increment the unbond amount by the full bonded amount.
                        let new_validator_unbonding: u64 = validator_bond.microcredits + existing_validator_unbond.microcredits;
                        unbonding.set(bond.validator, unbond_state { microcredits: new_validator_unbonding, height: unlock_height });
                    }
                }
            } else {
                // Unbond the validator (self-bonded case).

                // Check if the committee contains the validator.
                // By invariant, self-bonded validators are always in committee.
                let validator_in_committee: bool = committee.contains(bond.validator);
                if (validator_in_committee) {
                    let validator_bond: bond_state = bonded.get(bond.validator);
                    let current_delegated: u64 = delegated.get(bond.validator);

                    // Check if the current delegated amount is already below 10M credits.
                    let already_below_min: bool = current_delegated < 10_000_000_000_000u64;

                    if (!already_below_min) {
                        // Calculate updated values after unbonding.
                        let new_delegated: u64 = current_delegated - amount;
                        let new_self_bond: u64 = validator_bond.microcredits - amount;

                        // Check if the new bond state is below the required minimums.
                        let self_bond_ok: bool = new_self_bond >= 100_000_000u64;
                        let total_ok: bool = new_delegated >= 10_000_000_000_000u64;
                        let keep_validator: bool = self_bond_ok && total_ok;

                        if (keep_validator) {
                            // Partial unbond: the validator remains in the committee.
                            let existing_unbond: unbond_state = unbonding.get_or_use(bond.validator, default_unbond);
                            unbonding.set(bond.validator, unbond_state { microcredits: existing_unbond.microcredits + amount, height: unlock_height });
                            delegated.set(bond.validator, new_delegated);
                            bonded.set(bond.validator, bond_state { validator: bond.validator, microcredits: new_self_bond });
                        } else {
                            // Remove the validator because the required thresholds are no longer met.
                            committee.remove(bond.validator);
                            let committee_count: u32 = metadata.get(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
                            metadata.set(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, committee_count - 1u32);
                            delegated.set(bond.validator, current_delegated - validator_bond.microcredits);
                            bonded.remove(bond.validator);
                            let existing_unbond: unbond_state = unbonding.get_or_use(bond.validator, default_unbond);
                            unbonding.set(bond.validator, unbond_state { microcredits: validator_bond.microcredits + existing_unbond.microcredits, height: unlock_height });
                        }
                    } else {
                        // Remove the validator because it is already below the 10 million credit minimum.
                        committee.remove(bond.validator);
                        let committee_count: u32 = metadata.get(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
                        metadata.set(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, committee_count - 1u32);
                        delegated.set(bond.validator, current_delegated - validator_bond.microcredits);
                        bonded.remove(bond.validator);
                        let existing_unbond: unbond_state = unbonding.get_or_use(bond.validator, default_unbond);
                        unbonding.set(bond.validator, unbond_state { microcredits: validator_bond.microcredits + existing_unbond.microcredits, height: unlock_height });
                    }
                }
            }
        };
    }

    // Allows any staker to claim their microcredits to their withdrawal address
    // after the unbonding period.
    fn claim_unbond_public(
        public staker: address,
    ) -> Final {
        return final {
            // Get the unbond state. Fails if doesn't exist.
            let state: unbond_state = unbonding.get(staker);
            // Determine if unbonding is complete.
            assert(block.height >= state.height);

            // Get the withdrawal address for the staker.
            let withdrawal: address = withdraw.get(staker);

            // Add the unbonded amount to the withdrawal address public balance.
            let bal: u64 = account.get_or_use(withdrawal, 0u64);
            account.set(withdrawal, bal + state.microcredits);

            // Remove the unbond state for the staker.
            unbonding.remove(staker);

            // Check if the staker is still bonded.
            let is_bonded: bool = bonded.contains(staker);
            if (!is_bonded) {
                // If the staker is no longer bonded, remove the withdrawal address.
                withdraw.remove(staker);
            }
        };
    }

    fn set_validator_state(
        public is_open: bool,
    ) -> Final {
        let caller: address = self.caller;
        return final {
            let state: committee_state = committee.get(caller);
            committee.set(caller, committee_state { is_open: is_open, commission: state.commission });
        };
    }

    fn transfer_public(
        public recipient: address,
        public amount: u64,
    ) -> Final {
        let caller: address = self.caller;
        return final {
            let sender_bal: u64 = account.get(caller);
            account.set(caller, sender_bal - amount);
            let recipient_bal: u64 = account.get_or_use(recipient, 0u64);
            account.set(recipient, recipient_bal + amount);
        };
    }

    fn transfer_public_as_signer(
        public recipient: address,
        public amount: u64,
    ) -> Final {
        let signer: address = self.signer;
        return final {
            let sender_bal: u64 = account.get(signer);
            account.set(signer, sender_bal - amount);
            let recipient_bal: u64 = account.get_or_use(recipient, 0u64);
            account.set(recipient, recipient_bal + amount);
        };
    }

    // recipient and amount are private (no public keyword) to match on-chain.
    // Output order: receiver record first, then change record.
    fn transfer_private(
        input: credits,
        recipient: address,
        amount: u64,
    ) -> (credits, credits) {
        let receiver: credits = credits { owner: recipient, microcredits: amount };
        let change: credits = credits { owner: input.owner, microcredits: input.microcredits - amount };
        return (receiver, change);
    }

    fn transfer_private_to_public(
        input: credits,
        public recipient: address,
        public amount: u64,
    ) -> (credits, Final) {
        let change: credits = credits { owner: input.owner, microcredits: input.microcredits - amount };
        return (change, final {
            let recipient_bal: u64 = account.get_or_use(recipient, 0u64);
            account.set(recipient, recipient_bal + amount);
        });
    }

    // recipient is private (no public keyword) to match on-chain.
    fn transfer_public_to_private(
        recipient: address,
        public amount: u64,
    ) -> (credits, Final) {
        let caller: address = self.caller;
        let output: credits = credits { owner: recipient, microcredits: amount };
        return (output, final {
            let sender_bal: u64 = account.get(caller);
            account.set(caller, sender_bal - amount);
        });
    }

    fn join(
        first: credits,
        second: credits,
    ) -> credits {
        return credits { owner: first.owner, microcredits: first.microcredits + second.microcredits };
    }

    // amount is private (no public keyword) to match on-chain.
    // Deducts a 10,000 microcredit fee from the second record.
    fn split(
        input: credits,
        amount: u64,
    ) -> (credits, credits) {
        let first: credits = credits { owner: input.owner, microcredits: amount };
        let second: credits = credits { owner: input.owner, microcredits: input.microcredits - amount - 10_000u64 };
        return (first, second);
    }

}
