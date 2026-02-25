// The 'multisig_core' program.
//
// This contains a reusable implementation of an k-of-n multisig scheme that supports both Aleo
// signers and ECDSA signers. For more details see the README.md file.
program multisig_core.aleo {
    // The initial deployer, who is allowed to deploy the first edition of the program and call the init
    // transition.
    // When setting guard_create_wallet=true, this is also the only address that is allowed to create
    // the `self.address` "guard wallet".
    //
    // This address belongs to the first standard Aleo test account.
    // IMPORTANT! Remember to change this before deployment!
    const DEPLOYER_ADDRESS: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    const ALEO_ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    const ETH_ZERO_ADDRESS: [u8; 20] = [0u8; 20];
    const MAX_BLOCK_HEIGHT: u32 = 4294967295;  // 2**32 - 1

    @custom
    async constructor() {
        if (self.edition == 0u16) {
            assert_eq(self.program_owner, DEPLOYER_ADDRESS);
        } else {

            assert(program_settings_map.contains(true));
            let program_settings = program_settings_map.get(true);

            assert(program_settings.allow_upgrades);
            assert_eq(self.program_owner, program_settings.upgrader_address);
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Multisig settings - these are settings for the entire program
    ///////////////////////////////////////////////////////////////////////////

    struct ProgramSettings {
        // Whether upgrades are allowed. This serves as an upgrade kill switch, preventing
        // further program upgrades once it is set to false.
        allow_upgrades: bool,

        // The address that is allowed to perform upgrades, as long as allow_upgrades = true.
        // This is also the address that is allowed to turn off upgrades via the `disallow_upgrades`
        // transition.
        upgrader_address: address,

        // Whether we require a successful multisig operation to create a wallet.
        // If we do, the initiator must first create a wallet (by calling create_wallet)
        // with wallet_id=multisig_core.aleo (whatever that ends up being depends on the deployed
        // program name).
        // When create_wallet is called and this setting is set to true, we will check that
        // there is a completed signing operation with signing_op_id=hash(
        //   GuardedCreateWalletOp { wallet_id: wallet_id, threshold: ... }
        // )
        // Only if such completed signing op exists will we allow the create_wallet call to succeed.
        // This could come in handy for instances of this program that want to prevent the general
        // public from creating wallets on them. It can also help protect from people grabbing
        // wallet_ids that the deployer cares about.
        //
        // Note that the reason we hash the wallet_id inside a struct with a verbose field name
        // is so that in the future we could potentially guard other operations without worrying
        // about collisions in signing_op_id.
        guard_create_wallet: bool,
    }

    mapping program_settings_map: bool => ProgramSettings; // key is always "true"

    // Used to uniquely represent a signing_op_id when guard_create_wallet is used
    // (see comment in ProgramSettings).
    struct GuardedCreateWalletOp {
        wallet_id: address,
        threshold: u8,
        aleo_signers: [address; 4],
        ecdsa_signers: [[u8; 20]; 4],
    }

    ///////////////////////////////////////////////////////////////////////////
    // Wallet settings
    ///////////////////////////////////////////////////////////////////////////

    struct WalletAleoSigner {
        wallet_id: address,
        aleo_signer: address,
    }

    struct WalletEcdsaSigner {
        wallet_id: address,
        ecdsa_signer: [u8; 20],
    }

    struct WalletSettings {
        threshold: u8,
        num_signers: u8,
    }

    // Note that we do not distinguish between Aleo and ECDSA signers here since we're just storing hashes of their addresses
    // (together with the wallet_id).
    // Since Aleo addresses and Eth addresses are of a different size, collisions are extremely unlikely.
    mapping signers_map: field => bool; // hash(WalletAleoSigner or WalletEcdsaSigner) => true/false (whether this user is a signer or not)
    mapping wallets_map: address => WalletSettings; // wallet_id => WalletSettings

    ///////////////////////////////////////////////////////////////////////////
    // Signing operations
    ///////////////////////////////////////////////////////////////////////////

    // A unique identifier for a signing operation. Combining the user-provided signing_op_id
    // together with the wallet_id lets different wallets use the same signing_op_id across
    // different wallets.
    struct WalletSigningOpId {
        wallet_id: address,
        signing_op_id: field,
    }

    // A version of the above struct that includes a nonce.
    struct WalletSigningOpIdNonce {
        wallet_id: address,
        signing_op_id: field,
        nonce: u64,
    }

    // Data stored for a signing operation
    struct WalletSigningOp {
        // Number of valid signatures received so far.
        confirmations: u8,

        // The block height the signing op was initiated at.
        initiated_at_block: u32,

        // The last block.height we will accept signatures at.
        // If set to MAX_BLOCK_HEIGHT, the signing operation will never expire.
        expires_at_block: u32,

        // Round number: This starts at 1 and increases every time signing is initiated using the same signing_op_id.
        // (a previously-used signing_op_id can only be used again after expiration)
        round: u32,
    }

    // A confirmation that a specific signing operation (identified by a hash of
    // WalletSigningOpId) has been signed by a specific user (identified by a hash of WalletAleoSigner/WalletEcdsaSigner)
    struct SigningOpConfirmation {
        wallet_signing_op_id_hash: field,
        wallet_signer_hash: field,
    }

    mapping pending_signing_ops: field => WalletSigningOp; // hash(WalletSigningOpId) => WalletSigningOp

    // hash(SigningOpConfirmation) => pending signing op round at which the signature was provided.
    // By storing the round number we can ignore signatures from previous rounds.
    mapping pending_signing_confirmations: field => u32;

    mapping completed_signing_ops: field => u32; // hash(WalletSigningOpId) => block height when the signature that got us to the threshold was provided.

    mapping used_nonces: field => bool; // hash(WalletSigningOpIdNonce) => true for seen WalletSigningOpIdNonce

    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // Privileged operations
    ///////////////////////////////////////////////////////////////////////////

    // @notice Initialize the multisig_core program
    // @param upgrader_address The address that can upgrade the program
    // @param guard_create_wallet Whether to guard the creation of new wallets with
    //                            a multisig operation
    async transition init(upgrader_address: address, guard_create_wallet: bool) -> Future {
        let caller = self.caller;

        return async {
            assert_eq(caller, DEPLOYER_ADDRESS);

            assert(!program_settings_map.contains(true));
            program_settings_map.set(true, ProgramSettings {
                allow_upgrades: true,
                upgrader_address: upgrader_address,
                guard_create_wallet: guard_create_wallet,
            });
        };
    }

    // @notice Disallow any future upgrades
    async transition disallow_upgrades() -> Future {
        let caller = self.caller;
        return async {
            assert(program_settings_map.contains(true));
            let program_settings = program_settings_map.get(true);

            assert_eq(caller, program_settings.upgrader_address);

            program_settings_map.set(true, ProgramSettings {
                allow_upgrades: false,
                upgrader_address: program_settings.upgrader_address,
                guard_create_wallet: program_settings.guard_create_wallet,
            });
        };
    }

    // @notice Change the upgrader_address to a new address
    // @param new_upgrader_address The new upgrader address
    async transition set_upgrader_address(new_upgrader_address: address) -> Future {
        let caller = self.caller;
        return async {
            assert(program_settings_map.contains(true));
            let program_settings = program_settings_map.get(true);

            assert_eq(caller, program_settings.upgrader_address);
            assert(program_settings.allow_upgrades);

            program_settings_map.set(true, ProgramSettings {
                allow_upgrades: program_settings.allow_upgrades,
                upgrader_address: new_upgrader_address,
                guard_create_wallet: program_settings.guard_create_wallet,
            });
        };

    }

    ///////////////////////////////////////////////////////////////////////////
    // Create a new multisig wallet
    ///////////////////////////////////////////////////////////////////////////

    // @notice Create a new multisig wallet
    // @dev 4 of each signer was chosen arbitrarily, with the thinking that it will cover
    // @dev the majority of usecases. If more signers are needed, they can be added later
    // @dev via admin operations.
    // @param wallet_id The wallet id to create
    // @param threshold The threshold, specifying the minimum numer of signatures required
    //                  for operation completion.
    // @param aleo_signers The ALEO signers for the wallet (use ALEO_ZERO_ADDRESS for unused signers)
    // @param ecdsa_signers The ECDSA signers for the wallet (use ETH_ZERO_ADDRESS for unused signers)
    async transition create_wallet(
        public wallet_id: address,
        public threshold: u8,
        aleo_signers: [address; 4],
        ecdsa_signers: [[u8; 20]; 4],
    ) -> Future {
        // Note: This is further tested in the finalize method
        assert(threshold > 0u8 && threshold <= 8u8);

        let aleo_signer_hashes: [field; 4] = [
            BHP256::hash_to_field(WalletAleoSigner { wallet_id: wallet_id, aleo_signer: aleo_signers[0] }),
            BHP256::hash_to_field(WalletAleoSigner { wallet_id: wallet_id, aleo_signer: aleo_signers[1] }),
            BHP256::hash_to_field(WalletAleoSigner { wallet_id: wallet_id, aleo_signer: aleo_signers[2] }),
            BHP256::hash_to_field(WalletAleoSigner { wallet_id: wallet_id, aleo_signer: aleo_signers[3] }),
        ];
        let ecdsa_signer_hashes: [field; 4] = [
            BHP256::hash_to_field(WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signers[0] }),
            BHP256::hash_to_field(WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signers[1] }),
            BHP256::hash_to_field(WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signers[2] }),
            BHP256::hash_to_field(WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signers[3] }),
        ];

        let caller = self.caller;

        return async {
            // Ensure we are initialized and get program settings.
            assert(program_settings_map.contains(true));
            let program_settings = program_settings_map.get(true);

            // We might require a multisig operation for creating new wallets (unless this is the special wallet that manages that).
            if (program_settings.guard_create_wallet && wallet_id != self.address) {
                let signing_op_id = BHP256::hash_to_field(GuardedCreateWalletOp {
                    wallet_id: wallet_id,
                    threshold: threshold,
                    aleo_signers: aleo_signers,
                    ecdsa_signers: ecdsa_signers,
                });
                let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
                assert(completed_signing_ops.contains(wallet_signing_op_id_hash));
            } else if (wallet_id == self.address) {
                // Only the deployer can create the special wallet that manages new wallet creation.
                // Note that right now we do not allow changing guard_create_wallet after it has been set in `init`.
                // If at some point this changes, we will likely need to change this assertion as well.
                // At the moment we do not allow the special `self.address` wallet_id to be used regardless of whether
                // guard_create_wallet is enabled or not.
                assert_eq(caller, DEPLOYER_ADDRESS);
            }

            // Ensure the wallet does not already exist.
            assert(!wallets_map.contains(wallet_id));

            // Store signers + validate signers are unique
            let aleo_zero_addr_hash = BHP256::hash_to_field(WalletAleoSigner { wallet_id: wallet_id, aleo_signer: ALEO_ZERO_ADDRESS });
            let ecdsa_zero_addr_hash = BHP256::hash_to_field(WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ETH_ZERO_ADDRESS });

            let num_users: u8 = 0;

            for i: u8 in 0..4 {
                if (aleo_signer_hashes[i] != aleo_zero_addr_hash) {
                    assert(!signers_map.contains(aleo_signer_hashes[i]));
                    signers_map.set(aleo_signer_hashes[i], true);
                }
                // NOTE: We cannot simply do `num_users += 1` inside the `if` block above because it results in the following error:
                // Error [ETYC0372109]: Cannot re-assign to `num_users` from a conditional scope to an outer scope in an async function.
                num_users += (aleo_signer_hashes[i] != aleo_zero_addr_hash) ? 1 : 0;

                if (ecdsa_signer_hashes[i] != ecdsa_zero_addr_hash) {
                    assert(!signers_map.contains(ecdsa_signer_hashes[i]));
                    signers_map.set(ecdsa_signer_hashes[i], true);
                }
                num_users += (ecdsa_signer_hashes[i] != ecdsa_zero_addr_hash) ? 1 : 0;
            }

            assert(num_users >= threshold);

            // Create wallet by storing its settings.
            wallets_map.set(wallet_id, WalletSettings { threshold: threshold, num_signers: num_users });
        };
    }


    ///////////////////////////////////////////////////////////////////////////
    // Begin a signing operation
    ///////////////////////////////////////////////////////////////////////////

    // @notice Initiate a new signing operation
    // @param wallet_id The unique wallet identifier
    // @param signing_op_id The signing operation identifier. Must be one that has not been used previously,
    //                      or used previously and expired after reaching the expiration block height.
    // @param block_expiration How many blocks is this signing operation valid for before it expires?
    //                         Use MAX_BLOCK_HEIGHT to indicate no expiration.
    //                         This should be set high enough to allow signers sufficient time to provide signatures.
    //                         This only controls whether more signatures are accepted.
    //
    // NOTE: This code is duplicated inside `init_admin_op` due to Leo's limitation of not being able to call
    // one transition from another inside the same program.
    //
    async transition initiate_signing_op(public wallet_id: address, public signing_op_id: field, public block_expiration: u32) -> (field, Future) {
        assert(block_expiration > 0);
        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });

        let signer = WalletAleoSigner { wallet_id: wallet_id, aleo_signer: self.signer };
        let signer_hash = BHP256::hash_to_field(signer);

         return (wallet_signing_op_id_hash, finalize_initiate_signing_op(
            wallet_id,
            wallet_signing_op_id_hash,
            signer_hash,
            block_expiration,
            AdminOp {
                op: ADMIN_OP_INVALID,
                threshold: 0,
                aleo_signer: ALEO_ZERO_ADDRESS,
                ecdsa_signer: ETH_ZERO_ADDRESS,
            }));
    }

    // @notice Finalize the initiation of a signing operation (this is the "async" part of the initiate_signing_op transition)
    // @param wallet_id The wallet ID of the wallet that is initiating the signing operation.
    // @param wallet_signing_op_id_hash The hash of the wallet signing operation ID.
    // @param aleo_signer_hash The hash of the Aleo signer.
    // @param block_expiration How many blocks before the signing operation expires.
    // @param admin_op The admin operation that is being finalized (could be set to all zeros/default values to indicate no admin op)
    //
    // NOTE: This method has some specific behavior for when it is called from the context of finalizing an admin operation.
    // Ideally we would have a different async function for finalizing the admin operation that calls this function,
    // but Leo doesn't currently lets us do this. This was deemed to be too much code to duplicate, so instead we
    // always pass an `admin_op` and use the `ADMIN_OP_INVALID` op to indicate that this is not an admin operation.
    async function finalize_initiate_signing_op(
        wallet_id: address,
        wallet_signing_op_id_hash: field,
        aleo_signer_hash: field,
        block_expiration: u32,
        admin_op: AdminOp
    ) {
        // Ensure the wallet exists.
        assert(wallets_map.contains(wallet_id));

        // If signing op was completed, then we cannot re-initiate using the same id.
        let signing_complete = completed_signing_ops.contains(wallet_signing_op_id_hash);
        assert(!signing_complete);

        // Create a default pending signing op if one does not exist.
        if (!pending_signing_ops.contains(wallet_signing_op_id_hash)) {
            pending_signing_ops.set(wallet_signing_op_id_hash, WalletSigningOp {
                confirmations: 0,
                initiated_at_block: 0,
                expires_at_block: 0,
                round: 0,
            });
        }

        // Get existing pending signing op
        let existing_pending_op = pending_signing_ops.get(wallet_signing_op_id_hash);
        assert(signing_op_expired(existing_pending_op, block.height));

        let block_expiration_or_zero = (block_expiration == MAX_BLOCK_HEIGHT) ? 0u32 : block_expiration;
        let expires_at_block = (block_expiration == MAX_BLOCK_HEIGHT) ? MAX_BLOCK_HEIGHT : block.height + block_expiration_or_zero;
        let round = existing_pending_op.round + 1;

        // If signer is known then record it
        if (signers_map.contains(aleo_signer_hash)) {
            // Store the new pending signing op
            pending_signing_ops.set(wallet_signing_op_id_hash, WalletSigningOp {
                confirmations: 1,
                initiated_at_block: block.height,
                expires_at_block: expires_at_block,
                round: round,
            });

            let confirmation_hash =  BHP256::hash_to_field(SigningOpConfirmation {
                wallet_signing_op_id_hash: wallet_signing_op_id_hash,
                wallet_signer_hash: aleo_signer_hash,
            });

            assert(round > Mapping::get_or_use(pending_signing_confirmations, confirmation_hash, 0u32));
            pending_signing_confirmations.set(confirmation_hash, round);

            // Mark complete if possible
            let wallet_settings = wallets_map.get(wallet_id);
            if 1 >= wallet_settings.threshold {
                completed_signing_ops.set(wallet_signing_op_id_hash, block.height);
                // NOTE: We never remove from pending_signing_ops to ensure wallet_signing_op_id_hash is always unique
            }
        } else {
            pending_signing_ops.set(wallet_signing_op_id_hash, WalletSigningOp {
                confirmations: 0,
                initiated_at_block: block.height,
                expires_at_block: expires_at_block,
                round: round,
            });
        }

        // If this signing op was used for an admin operation, it must always be used for the same operation.
        // If it wasn't, then it must always be used for a non-admin operation.
        if (pending_admin_ops.contains(wallet_signing_op_id_hash)) {
            let existing_admin_op = pending_admin_ops.get(wallet_signing_op_id_hash);
            assert_eq(admin_op, existing_admin_op);
        } else {
            // Note that in cases where this finalize call is not an admin op, admin_op.op
            // will be ADMIN_OP_INVALID, so no admin op can be executed.
            // We always store a value here so that if a signing op gets re-used due to expiration,
            // it cannot be "upgraded" to an admin op or be re-purposed for a different admin op.
            pending_admin_ops.set(wallet_signing_op_id_hash, admin_op);
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Provide an Aleo signature to a signing operation
    ///////////////////////////////////////////////////////////////////////////

    // @notice Provide a signature for a given wallet_id+signing_op_id, for the current signing round.
    // @dev Note that by not enforcing the round is equal to a specific value, it is possible for the signer
    // @dev to sign an operation that is different than they were originally intending to sign - this can happen
    // @dev if a signing operation expires and a new one with the same signing_op_id is initiated, and the signer
    // @dev submits their signature after the new operation has been initiated.
    // @dev If this is a concern, use `sign_for_round`. The reason this method is provided is to provide a simpler user experience.
    // @dev Not having to know the current round makes it a bit easier to use, and in many cases this will be acceptable.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    async transition sign(public wallet_id: address, public signing_op_id: field) -> Future {
        let signer = WalletAleoSigner { wallet_id: wallet_id, aleo_signer: self.signer };
        let signer_hash = BHP256::hash_to_field(signer);

        return finalize_sign(wallet_id, signing_op_id, signer_hash, 0u32);
    }

    // @notice Provide a signature for a given wallet_id+signing_op_id, for a specific round.
    // @dev This is useful if you want to ensure that the signature is for a specific round, and not just the current round.
    // @dev See notes in `sign` above.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    // @param round The round to sign for
    async transition sign_for_round(public wallet_id: address, public signing_op_id: field, public round: u32) -> Future {
        let signer = WalletAleoSigner { wallet_id: wallet_id, aleo_signer: self.signer };
        let signer_hash = BHP256::hash_to_field(signer);

        return finalize_sign(wallet_id, signing_op_id, signer_hash, round);
    }

    // @notice Finalize a signing operation for a given wallet_id+signing_op_id, for a specific round.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    // @param signer_hash The hash of the signer (WalletAleoSigner or WalletEcdsaSigner)
    // @param round The round to sign for, or zero for current round.
    async function finalize_sign(wallet_id: address, signing_op_id: field, signer_hash: field, round: u32) {
        // Ensure the wallet exists.
        assert(wallets_map.contains(wallet_id));

        // Signer must be known.
        assert(signers_map.contains(signer_hash));

        // Signing op must exist and not be expired.
        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });
        assert(pending_signing_ops.contains(wallet_signing_op_id_hash));

        let signing_op = pending_signing_ops.get(wallet_signing_op_id_hash);
        assert(!signing_op_expired(signing_op, block.height));

        // Round must match if it is not 0
        assert(round == 0u32 || round == signing_op.round);

        // Track signer and ensure they cannot sign twice for the same operation.
        let confirmation_hash =  BHP256::hash_to_field(SigningOpConfirmation {
            wallet_signing_op_id_hash: wallet_signing_op_id_hash,
            wallet_signer_hash: signer_hash,
        });
        assert(signing_op.round > Mapping::get_or_use(pending_signing_confirmations, confirmation_hash, 0u32));
        pending_signing_confirmations.set(confirmation_hash, signing_op.round);

        // Increase confirmations
        let new_signing_op = WalletSigningOp {
            confirmations: signing_op.confirmations + 1,
            initiated_at_block: signing_op.initiated_at_block,
            expires_at_block: signing_op.expires_at_block,
            round: signing_op.round,
        };
        pending_signing_ops.set(wallet_signing_op_id_hash, new_signing_op);

        // Mark completed if possible
        let wallet_settings = wallets_map.get(wallet_id);
        // NOTE: We check the number of confirmations against the *current* threshold,
        // not the threshold that was set when signing was initiated.
        // While storing the threshold upon initiation is trivial, capturing a snapshot of the signer
        // set is difficult, so we just use the current settings.
        if new_signing_op.confirmations >= wallet_settings.threshold {
            completed_signing_ops.set(wallet_signing_op_id_hash, block.height);
        }

        // NOTE: We never remove from pending_signing_ops to ensure wallet_signing_op_id_hash is always unique
    }

    ///////////////////////////////////////////////////////////////////////////
    // Provide an ECDSA signature to a signing operation
    ///////////////////////////////////////////////////////////////////////////

    // @notice Provide an ECDSA signature for a given wallet_id+signing_op_id, for the current signing round.
    // @dev Note that by not enforcing the round is equal to a specific value, it is possible for the signer
    // @dev to sign an operation that is different than they were originally intending to sign - this can happen
    // @dev if a signing operation expires and a new one with the same signing_op_id is initiated, and the signer
    // @dev submits their signature after the new operation has been initiated.
    // @dev If this is a concern, use `sign_ecdsa_for_round`. The reason this method is provided is to provide a simpler user experience.
    // @dev Not having to know the current round makes it a bit easier to use, and in many cases this will be acceptable.
    // @dev Nonce is a random number that has not been used previously. It is included in the data covered by the signature and prevents
    // @dev signature replay attacks.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    // @param ecdsa_signer The Ethererum address bytes that produced the signature
    // @param sig The ECDSA signature
    // @param nonce The nonce used for this signature
    async transition sign_ecdsa(public wallet_id: address, public signing_op_id: field, public ecdsa_signer: [u8; 20], public sig: [u8; 65], public nonce: u64) -> Future {
        let signer = WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signer };

        return finalize_sign_ecdsa(wallet_id, signing_op_id, signer, sig, nonce, 0u32);
    }

    // @notice Provide an ECDSA signature for a given wallet_id+signing_op_id, for a specific signing round.
    // @dev This is useful if you want to ensure that the signature is for a specific round, and not just the current round.
    // @dev See notes in `sign_ecdsa` above.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    // @param ecdsa_signer The Ethererum address bytes that produced the signature
    // @param sig The ECDSA signature
    // @param nonce The nonce used for this signature
    // @param round The signing round
    async transition sign_ecdsa_for_round(public wallet_id: address, public signing_op_id: field, public ecdsa_signer: [u8; 20], public sig: [u8; 65], public nonce: u64, public round: u32) -> Future {
        let signer = WalletEcdsaSigner { wallet_id: wallet_id, ecdsa_signer: ecdsa_signer };

        return finalize_sign_ecdsa(wallet_id, signing_op_id, signer, sig, nonce, round);
    }

    // @notice Finalize the signing operation.
    // @param wallet_id The wallet id the signing operation belongs to
    // @param signing_op_id The signing operation id
    // @param signer The signer of the signature
    // @param sig The ECDSA signature
    // @param nonce The nonce used for this signature
    // @param round The signing round
    async function finalize_sign_ecdsa(wallet_id: address, signing_op_id: field, signer: WalletEcdsaSigner, sig: [u8; 65], nonce: u64, round: u32) {
        // Ensure the wallet exists.
        assert(wallets_map.contains(wallet_id));

        // Signer must be known.
        let signer_hash = BHP256::hash_to_field(signer);
        assert(signers_map.contains(signer_hash));

        // Nonce must be unique for this wallet_id/signing_op_id
        let nonce_hash = BHP256::hash_to_field(WalletSigningOpIdNonce { wallet_id: wallet_id, signing_op_id: signing_op_id, nonce: nonce });
        assert(!used_nonces.contains(nonce_hash));
        used_nonces.set(nonce_hash, true);

        // Signing op must exist and not be expired.
        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });
        assert(pending_signing_ops.contains(wallet_signing_op_id_hash));

        let signing_op = pending_signing_ops.get(wallet_signing_op_id_hash);
        assert(!signing_op_expired(signing_op, block.height));

        // Round must match if it is not 0
        assert(round == 0u32 || round == signing_op.round);

        // Signature must be valid.
        // NOTE: The signature is over the hash of a `WalletSigningOpIdNonce`, capturing
        // the wallet_id, signing_op_id and nonce.
        let hash_bits: [bool; 253] = Serialize::to_bits_raw(nonce_hash);
        let padded_bits: [bool; 256] = [false; 256];
        for i: u8 in 0..253 {
            padded_bits[i] = hash_bits[i];
        }
        let bytes = Deserialize::from_bits_raw::[[u8; 32]](padded_bits);
        let digest = to_eth_signed_message_hash(bytes);
        assert(ECDSA::verify_digest_eth(sig, signer.ecdsa_signer, digest));

        // Track signer and ensure they cannot sign twice for the same operation.
        let confirmation_hash =  BHP256::hash_to_field(SigningOpConfirmation {
            wallet_signing_op_id_hash: wallet_signing_op_id_hash,
            wallet_signer_hash: signer_hash,
        });
        assert(signing_op.round > Mapping::get_or_use(pending_signing_confirmations, confirmation_hash, 0u32));
        pending_signing_confirmations.set(confirmation_hash, signing_op.round);

        // Increase confirmations
        let new_signing_op = WalletSigningOp {
            confirmations: signing_op.confirmations + 1,
            initiated_at_block: signing_op.initiated_at_block,
            expires_at_block: signing_op.expires_at_block,
            round: signing_op.round,
        };
        pending_signing_ops.set(wallet_signing_op_id_hash, new_signing_op);

        // Mark completed if possible
        let wallet_settings = wallets_map.get(wallet_id);
        // NOTE: We check the number of confirmations against the *current* threshold,
        // not the threshold that was set when signing was initiated.
        // While storing the threshold upon initiation is trivial, capturing a snapshot of the signer
        // set is difficult, so we just use the current settings.
        if new_signing_op.confirmations >= wallet_settings.threshold {
            completed_signing_ops.set(wallet_signing_op_id_hash, block.height);
        }

        // NOTE: We never remove from pending_signing_ops to ensure wallet_signing_op_id_hash is always unique
    }

    ///////////////////////////////////////////////////////////////////////////
    // Admin operations
    ///////////////////////////////////////////////////////////////////////////

    const ADMIN_OP_INVALID: u8 = 0;
    const ADMIN_OP_CHANGE_THRESHOLD: u8 = 1;
    const ADMIN_OP_ADD_SIGNER: u8 = 2;
    const ADMIN_OP_REMOVE_SIGNER: u8 = 3;

    // An administrative operation
    struct AdminOp {
        op: u8,

        // Only used for ADMIN_OP_CHANGE_THRESHOLD
        threshold: u8,

        // Only used for ADMIN_OP_ADD_SIGNER and ADMIN_OP_REMOVE_SIGNER.
        // Only one of the two can be provided, the other has to be set to the zero address.
        aleo_signer: address,
        ecdsa_signer: [u8; 20],
    }

    // @notice A helper for hashing an AdminOp.
    // @param wallet_id The wallet ID.
    // @param admin_op The admin operation.
    inline get_admin_op_wallet_signer_hash(wallet_id: address, admin_op: AdminOp) -> field {
        assert(admin_op.op == ADMIN_OP_ADD_SIGNER || admin_op.op == ADMIN_OP_REMOVE_SIGNER);

        let wallet_signer_hash = 0field;

        if (admin_op.aleo_signer != ALEO_ZERO_ADDRESS) {
            wallet_signer_hash = BHP256::hash_to_field(WalletAleoSigner {
                wallet_id: wallet_id,
                aleo_signer: admin_op.aleo_signer,
            });
        }

        if (admin_op.ecdsa_signer != ETH_ZERO_ADDRESS) {
            assert_eq(wallet_signer_hash, 0field);
            wallet_signer_hash = BHP256::hash_to_field(WalletEcdsaSigner {
                wallet_id: wallet_id,
                ecdsa_signer: admin_op.ecdsa_signer,
            });
        }

        assert_neq(wallet_signer_hash, 0field);

        return wallet_signer_hash;
    }

    mapping pending_admin_ops: field => AdminOp; // hash(WalletSigningOpId) => AdminOp

    // @notice A helper for ensuring an AdminOp is valid.
    // @param admin_op The admin operation to validate.
    function assert_valid_admin_op(admin_op: AdminOp) {
        if (admin_op.op == ADMIN_OP_CHANGE_THRESHOLD) {
            assert_neq(admin_op.threshold, 0u8);
            assert_eq(admin_op.aleo_signer, ALEO_ZERO_ADDRESS);
            assert_eq(admin_op.ecdsa_signer, ETH_ZERO_ADDRESS);
        } else if (admin_op.op == ADMIN_OP_ADD_SIGNER || admin_op.op == ADMIN_OP_REMOVE_SIGNER) {
            assert_eq(admin_op.threshold, 0u8);
            if (admin_op.aleo_signer == ALEO_ZERO_ADDRESS && admin_op.ecdsa_signer == ETH_ZERO_ADDRESS) {
                assert(false);
            } else if (admin_op.aleo_signer != ALEO_ZERO_ADDRESS && admin_op.ecdsa_signer != ETH_ZERO_ADDRESS) {
                assert(false);
            }
        } else {
            assert(false);
        }
    }

    // @notice Initialize a new admin operation
    // @param wallet_id The wallet id the admin operation applies to
    // @param signing_op_id The signing op id
    // @param block_expiration Number of blocks this operation is valid for before it expires
    // @param admin_op The admin operation to perform
    async transition init_admin_op(public wallet_id: address, public signing_op_id: field, public block_expiration: u32, admin_op: AdminOp) -> (field, Future) {
        assert_valid_admin_op(admin_op);

        // NOTE: This is duplicated from initiate_signing_op
        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });
        let signer = WalletAleoSigner { wallet_id: wallet_id, aleo_signer: self.signer };
        let signer_hash = BHP256::hash_to_field(signer);
        let init_signing_op_fut = finalize_initiate_signing_op(wallet_id, wallet_signing_op_id_hash, signer_hash, block_expiration, admin_op);

        return (wallet_signing_op_id_hash, init_signing_op_fut);
    }

    // @notice Execute an admin operation once it has been fully signed.
    // @param wallet_id The wallet id the admin operation applies to
    // @param signing_op_id The signing op id
    // @param admin_op The admin operation to perform
    async transition exec_admin_op(public wallet_id: address, public signing_op_id: field, admin_op: AdminOp) -> Future {
        assert_valid_admin_op(admin_op);

        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });

        return async {
            // Ensure the wallet exists.
            assert(wallets_map.contains(wallet_id));

            // Ensure signing was completed
            let signing_complete = completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);

            // Ensure we have a pending admin op that matches the wallet_signing_op_id_hash
            let pending_admin_op = pending_admin_ops.get(wallet_signing_op_id_hash);
            assert_eq(pending_admin_op, admin_op);

            // Removing is crucial, otherwise the operation can be executed twice.
            pending_admin_ops.remove(wallet_signing_op_id_hash);

            // Execute the admin op
            let wallet_settings = wallets_map.get(wallet_id);

            if (admin_op.op == ADMIN_OP_CHANGE_THRESHOLD) {
                assert(admin_op.threshold <= wallet_settings.num_signers);
                wallets_map.set(wallet_id, WalletSettings {
                    threshold: admin_op.threshold,
                    num_signers: wallet_settings.num_signers,
                });
            } else if (admin_op.op == ADMIN_OP_ADD_SIGNER) {
                let wallet_signer_hash = get_admin_op_wallet_signer_hash(wallet_id, admin_op);

                assert(!signers_map.contains(wallet_signer_hash));
                signers_map.set(wallet_signer_hash, true);

                wallets_map.set(wallet_id, WalletSettings {
                    threshold: wallet_settings.threshold,
                    num_signers: wallet_settings.num_signers + 1
                });
            } else if (admin_op.op == ADMIN_OP_REMOVE_SIGNER) {
                let wallet_signer_hash = get_admin_op_wallet_signer_hash(wallet_id, admin_op);

                assert(signers_map.contains(wallet_signer_hash));
                signers_map.remove(wallet_signer_hash);

                assert(wallet_settings.num_signers - 1 >= wallet_settings.threshold);
                wallets_map.set(wallet_id, WalletSettings {
                    threshold: wallet_settings.threshold,
                    num_signers: wallet_settings.num_signers - 1
                });
            } else {
                assert(false);
            }
        };
    }

    ///////////////////////////////////////////////////////////////////////////
    // Helpers
    ///////////////////////////////////////////////////////////////////////////

    // @notice Check if a given WalletSigningOp has expired at a given block height
    // @param signing_op The WalletSigningOp to check
    // @param block_height The block height to check against
    inline signing_op_expired(signing_op: WalletSigningOp, block_height: u32) -> bool {
        return signing_op.expires_at_block < block_height;
    }

    // @notice Get the hash of a WalletSigningOpId
    // @param wallet_id The wallet ID
    // @param signing_op_id The signing op ID
    function get_signing_op_id_hash_fn(wallet_id: address, signing_op_id: field) -> field {
        return BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });

    }

    // @notice Get the hash of a WalletSigningOpId
    // @param wallet_id The wallet ID
    // @param signing_op_id The signing op ID
    transition get_signing_op_id_hash(public wallet_id: address, public signing_op_id: field) -> field {
        return get_signing_op_id_hash_fn(wallet_id, signing_op_id);
    }

    // @notice Get the hash of a GuardedCreateWalletOp
    // @param wallet_id The wallet ID
    // @param threshold The threshold of the wallet
    // @param aleo_signers The list of Aleo signers
    // @param ecdsa_signers The list of ECDSA signers
    transition guarded_create_wallet_op_hash(
        public wallet_id: address,
        public threshold: u8,
        aleo_signers: [address; 4],
        ecdsa_signers: [[u8; 20]; 4],
    ) -> field {
        return BHP256::hash_to_field(GuardedCreateWalletOp {
            wallet_id: wallet_id,
            threshold: threshold,
            aleo_signers: aleo_signers,
            ecdsa_signers: ecdsa_signers,
        });
    }

    // @notice Ensure a given signing operation has been completed for a given wallet id.
    // @param wallet_id The wallet ID
    // @param signing_op_id The signing op ID
    async transition assert_signing_completed(public wallet_id: address, public signing_op_id: field) -> Future {
        let fut = fin_assert_signing_completed(wallet_id, signing_op_id);
        return fut;
    }

    // @notice The async part of `assert_signing_completed`
    // @param wallet_id The wallet ID
    // @param signing_op_id The signing op ID
    async function fin_assert_signing_completed(wallet_id: address, signing_op_id: field) {
        let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: wallet_id, signing_op_id: signing_op_id });
        let signing_complete = completed_signing_ops.contains(wallet_signing_op_id_hash);
        assert(signing_complete);
    }

    // @notice Calculate a message hash based on the message prefixing and hashing defined in EIP-191
    // @param hash The hash to sign using the method defined in EIP-191
    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        let digest: [u8; 60] = [0u8; 60];

        // Ethereum Signed Message prefix: "\x19Ethereum Signed Message:\n32"
        digest[0] = 25u8;   // \x19
        digest[1] = 69u8;   // E
        digest[2] = 116u8;  // t
        digest[3] = 104u8;  // h
        digest[4] = 101u8;  // e
        digest[5] = 114u8;  // r
        digest[6] = 101u8;  // e
        digest[7] = 117u8;  // u
        digest[8] = 109u8;  // m
        digest[9] = 32u8;   // (space)
        digest[10] = 83u8;  // S
        digest[11] = 105u8; // i
        digest[12] = 103u8; // g
        digest[13] = 110u8; // n
        digest[14] = 101u8; // e
        digest[15] = 100u8; // d
        digest[16] = 32u8;  // (space)
        digest[17] = 77u8;  // M
        digest[18] = 101u8; // e
        digest[19] = 115u8; // s
        digest[20] = 115u8; // s
        digest[21] = 97u8;  // a
        digest[22] = 103u8; // g
        digest[23] = 101u8; // e
        digest[24] = 58u8;  // :
        digest[25] = 10u8;  // \n
        digest[26] = 51u8;  // '3'
        digest[27] = 50u8;  // '2'

        // Copy hash bytes (32 bytes)
        for i in 0u8..32u8 {
            digest[28u8 + i] = hash[i];
        }

        let hash_bits = Keccak256::hash_to_bits_raw(digest);
        return Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
    }
}
