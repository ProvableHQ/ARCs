import sealance_freezelist_registry.aleo;
import multisig_core.aleo;

program compliant_token_template.aleo {
    @custom
    async constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });

            let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = multisig_core.aleo/completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    // A helper for calculating a signing_op_id from the program's checksum and edition.
    // By deriving the signing_op_id from both we ensure that downgrades cannot take place.
    transition get_signing_op_id_for_deploy(checksum: [u8; 32], edition: u16) -> field {
        return BHP256::hash_to_field(ChecksumEdition { checksum: checksum, edition: edition });
    }

    record Token {
        owner: address,
        amount: u128
    }

    // Compliance record used for the investigator
    record ComplianceRecord {
        owner: address,
        amount: u128,
        sender: address,
        recipient: address
    }

    record Credentials {
        owner: address,
        freeze_list_root: field,
    }

    struct ChecksumEdition {
        checksum: [u8; 32],
        edition: u16,
    }

    struct TokenInfo {
        name: u128, // ASCII text represented in bits, and the u128 value of the bitstring
        symbol: u128, // ASCII text represented in bits, and the u128 value of the bitstring
        decimals: u8,
        supply: u128,
        max_supply: u128,
    }

    struct TokenAllowance {
        account: address,
        spender: address,
    }
    
    const TOKEN_INFO_INDEX: bool = true;
    // token specs
    mapping token_info: bool => TokenInfo;

    mapping balances: address => u128;
    mapping allowances: field => u128; // hash(account, spender) => TokenAllowance

    // Roles can be assigned using bitmasking to allow multiple roles per address
    const NONE_ROLE: u16 = 0u16;
    const MINTER_ROLE: u16 = 1u16;
    const BURNER_ROLE: u16 = 2u16;
    const PAUSE_ROLE: u16 = 4u16;   // can pause/unpause transfers
    const MANAGER_ROLE: u16 = 8u16; // can only assign roles
    mapping address_to_role: address => u16;

    // Only this address can deploy and initialize the program
    const DEPLOYER_ADDRESS: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    // This address receives compliance records (can be updated with the contract upgrade)
    const INVESTIGATOR_ADDRESS: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    const PAUSE_STATUS_INDEX: bool = true;
    mapping pause: bool => bool;

    const ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc; // ZERO_ADDRESS as field equals to 0field
    const CURRENT_FREEZE_LIST_ROOT_INDEX: u8 = 1u8;
    const PREVIOUS_FREEZE_LIST_ROOT_INDEX: u8 = 2u8;
    const BLOCK_HEIGHT_WINDOW_INDEX: bool = true;
    const ROOT_UPDATED_HEIGHT_INDEX: bool = true;
    // Defines the maximum depth of the Merkle tree used in freeze list proofs.
    // Trees deeper than this value are not supported.
    const MAX_TREE_DEPTH: u32 = 15u32;

    // -------------------------
    // Called by token admins
    // -------------------------


    // Updates the address assigned to a given role.
    // Can only be called by the current role manager.
    async transition update_role(public new_address: address, role: u16) -> Future {
        return f_update_role(new_address, self.caller, role);
    }
    async function f_update_role(new_address: address, caller: address, new_role: u16) {
        let current_role: u16 = address_to_role.get(caller);
        assert(current_role & MANAGER_ROLE == MANAGER_ROLE);
        
        if (caller == new_address) { 
            assert(new_role & MANAGER_ROLE == MANAGER_ROLE); 
        }

        address_to_role.set(new_address, new_role);

    }

    // Initializes the freeze list, token specifications, the admin and the investigator.
    // Can be called only once and only by the INITIAL_ADMIN    
    // Sets the token metadata (name, symbol, decimals, max supply).
    // Sets the block height window, the initial empty Merkle root,
    // and initialize the freeze_list_last_index, freeze_list, and freeze_list_index with a ZERO_ADDRESS placeholder.
    async transition initialize(
        public name: u128,
        public symbol: u128,
        public decimals: u8,
        public max_supply: u128,
        public admin: address,
    ) -> Future {
        return finalize_initialize(
            name,
            symbol,
            decimals,
            max_supply,
            admin,
            self.caller,
        );
    }
    async function finalize_initialize(
        name: u128,
        symbol: u128,
        decimals: u8,
        max_supply: u128,
        admin: address, 
        caller: address,
    ) {
        // Check if the token has already been initialized
        let already_initialized: bool = token_info.contains(TOKEN_INFO_INDEX);
        assert_eq(already_initialized, false);
        
        // Only the INITIAL_CONFIGURATION_ADDRESS can initialize the contract
        assert_eq(caller, DEPLOYER_ADDRESS);
        
        address_to_role.set(admin, MANAGER_ROLE);

        let token: TokenInfo = TokenInfo {
            name: name,
            symbol: symbol,
            decimals: decimals,
            supply: 0u128, // placeholder value; not used
            max_supply: max_supply
        };

        token_info.set(TOKEN_INFO_INDEX, token);

        pause.set(PAUSE_STATUS_INDEX, false);
    }

    // Generates a Credential record for the signer.
    // Allows future private transfers without needing to re-prove non-inclusion in the freeze list.
    // The signer's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    async transition get_credentials(sender_merkle_proofs: [MerkleProof;2]) -> (Credentials, Future) {
        let root: field = verify_non_inclusion(self.signer, sender_merkle_proofs);

        let credentials_record: Credentials = Credentials {
            owner: self.signer,
            freeze_list_root: root,
        };

        return (credentials_record, f_get_credentials(root));
    }
    async function f_get_credentials(root: field) {
        let current_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
        let window: u32 = sealance_freezelist_registry.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);

        if (current_root != root) {
            let previous_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
            assert_eq(root, previous_root);
            let updated_height: u32 = sealance_freezelist_registry.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
            assert(updated_height + window > block.height);
        }
    }

    // Mints new public tokens to the specified recipient’s balance.
    // Can only be called by a minter.
    // Ensures that the new total supply does not exceed the maximum supply.
    // Updates the recipient’s balance and the total token supply in the token metadata.
    async transition mint_public(
        public recipient: address,
        public amount: u128,
    ) -> Future {
        return finalize_mint_public(recipient, amount, self.caller);
    }
    async function finalize_mint_public(
        recipient: address,
        amount: u128,
        caller: address
    ) {

        let role: u16 = address_to_role.get(caller);
        assert(role & MINTER_ROLE == MINTER_ROLE);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let token = token_info.get(TOKEN_INFO_INDEX);
        // Check that the token supply + amount <= max_supply
        let new_supply: u128 = token.supply + amount;
        assert(new_supply <= token.max_supply);

        // Update the balance
        let balance = balances.get_or_use(recipient, 0u128);
        let new_balance = amount + balance;
        balances.set(recipient, new_balance);

        // Update the token supply
        let new_metadata: TokenInfo = TokenInfo {
            name: token.name,
            symbol: token.symbol,
            decimals: token.decimals,
            supply: new_supply,
            max_supply: token.max_supply,
        };
        token_info.set(TOKEN_INFO_INDEX, new_metadata);
    }

    // Mints new private tokens to the specified recipient.
    // Can only be called by a minter.
    // Ensures that the new total supply does not exceed the maximum supply.
    // Updates the total token supply in the token metadata.
    async transition mint_private(
        recipient: address,
        public amount: u128,
        ) -> (ComplianceRecord, Token, Future) {
        let token: Token = Token {
            owner: recipient,
            amount: amount,
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: ZERO_ADDRESS,
            recipient: recipient,
        };
        
        return (compliance_record, token, finalize_mint_private(amount, self.caller));
    }

    async function finalize_mint_private(
        amount: u128,
        caller: address,
    ) {
        let role: u16 = address_to_role.get(caller);
        assert(role & MINTER_ROLE == MINTER_ROLE);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let token = token_info.get(TOKEN_INFO_INDEX);

        // Check that the token supply + amount <= max_supply
        let new_supply: u128 = token.supply + amount;
        assert(new_supply <= token.max_supply);

        // Update the token supply
        let new_metadata: TokenInfo = TokenInfo {
            name: token.name,
            symbol: token.symbol,
            decimals: token.decimals,
            supply: new_supply,
            max_supply: token.max_supply,
        };
        token_info.set(TOKEN_INFO_INDEX, new_metadata);
    }

    // Burns public tokens from the specified owner’s balance.
    // Can only be called by a burner.
    // Decreases the owner’s balance and reduces the total token supply in the token metadata.
    async transition burn_public(
        public owner: address,
        public amount: u128
    ) -> Future {
        return finalize_burn_public(owner, amount, self.caller);
    }

    async function finalize_burn_public(
        owner: address,
        amount: u128,
        caller: address,
    ) {
        let role: u16 = address_to_role.get(caller);
        assert(role & BURNER_ROLE == BURNER_ROLE);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        // Update the balance
        let balance = balances.get(owner);
        let new_balance = balance - amount;
        balances.set(owner, new_balance);

        let token = token_info.get(TOKEN_INFO_INDEX);

        let new_metadata: TokenInfo = TokenInfo {
            name: token.name,
            symbol: token.symbol,
            decimals: token.decimals,
            supply: token.supply - amount, // underflow will be caught by the VM
            max_supply: token.max_supply,
        };
        token_info.set(TOKEN_INFO_INDEX, new_metadata);
    }

    // Burns tokens from a private record (non-public asset).
    // Can only be called by a burner.
    // Reduces the amount in the provided private record and decreases the total token supply in the token metadata.
    async transition burn_private(
        input_record: Token,
        public amount: u128
    ) -> (ComplianceRecord, Token, Future) {
        let output_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: ZERO_ADDRESS,
        };

        return (compliance_record, output_record, finalize_burn_private(amount, self.caller));
    }
    async function finalize_burn_private(
        amount: u128,
        caller: address,
    ) {
        let role: u16 = address_to_role.get(caller);
        assert(role & BURNER_ROLE == BURNER_ROLE);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let token = token_info.get(TOKEN_INFO_INDEX);

        // Update the token supply
        let new_metadata: TokenInfo = TokenInfo {
            name: token.name,
            symbol: token.symbol,
            decimals: token.decimals,
            supply: token.supply - amount, // underflow will be caught by the VM
            max_supply: token.max_supply,
        };
        token_info.set(TOKEN_INFO_INDEX, new_metadata);
    }

    // -------------------------
    // Called by token owners/DeFi contracts
    // -------------------------

    // Transfers public tokens from the caller to the recipient.
    // Both sender and recipient must not be frozen in the freeze list.
    async transition transfer_public(
        public recipient: address,
        public amount: u128
    ) -> Future {
        return finalize_transfer_public(recipient, amount, self.caller);
    }

    async function finalize_transfer_public(
        recipient: address,
        amount: u128,
        sender: address
    ) {
        let is_sender_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(sender, false);
        assert_eq(is_sender_frozen, false);
        let is_recipient_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(recipient, false);
        assert_eq(is_recipient_frozen, false);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let sender_balance = balances.get(sender);
        balances.set(sender, sender_balance - amount);

        let recipient_balance = balances.get_or_use(recipient, 0u128);
        balances.set(recipient, recipient_balance + amount);
    }

    // Transfers public tokens from the signer to the recipient.
    // Both sender and recipient must not be frozen in the freeze list.
    async transition transfer_public_as_signer(
        public recipient: address,
        public amount: u128
    ) -> Future {
        return f_transfer_public_as_signer(recipient, amount, self.signer);
    }

    async function f_transfer_public_as_signer(
        recipient: address,
        amount: u128,
        sender: address
    ) {
        let is_sender_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(sender, false);
        assert_eq(is_sender_frozen, false);
        let is_recipient_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(recipient, false);
        assert_eq(is_recipient_frozen, false);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let sender_balance = balances.get(sender);
        balances.set(sender, sender_balance - amount);

        let recipient_balance = balances.get_or_use(recipient, 0u128);
        balances.set(recipient, recipient_balance + amount);
    }

    // Approves a spender to transfer the caller’s public assets up to a specified amount.
    // Increases the existing allowance if one is already set, otherwise creates a new allowance.
    // The allowance is stored using a hash of the owner–spender pair as the key.
    async transition approve_public(
        public spender: address,
        public amount: u128
    ) -> Future {
        let allowance: TokenAllowance = TokenAllowance {
            account: self.caller,
            spender: spender
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);

        return finalize_approve_public(amount, allowance_key);
    }

    async function finalize_approve_public(
        amount: u128,
        allowance_key: field
    ) {

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let current_allowance: u128 = allowances.get_or_use(allowance_key, 0u128);
        // Increase or create the allowance amount
        allowances.set(allowance_key, current_allowance + amount);
    }

    // Reduces a spender’s allowance to transfer the caller’s public assets by a specified amount.
    // Decreases the existing allowance stored under the hash of the owner–spender pair.
    // If the reduction exceeds the current allowance, the VM will catch the underflow.
    async transition unapprove_public(
        public spender: address,
        public amount: u128
    ) -> Future {
        let allowance: TokenAllowance = TokenAllowance {
            account: self.caller,
            spender: spender
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);

        return finalize_unapprove_public(amount, allowance_key);
    }
    async function finalize_unapprove_public(
        amount: u128,
        allowance_key: field
    ) {

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let current_allowance: u128 = allowances.get(allowance_key);
        // Decrease the allowance amount
        allowances.set(allowance_key, current_allowance - amount);
    }

    // Transfers public tokens from the owner to the recipient.
    // Can be called by any spender with sufficient allowance from the owner.
    // Decreases the spender’s allowance by the transferred amount.
    // Both sender and recipient must not be frozen in the freeze list.
    async transition transfer_from_public(
        public owner: address,
        public recipient: address,
        public amount: u128
    ) -> Future {
        let allowance: TokenAllowance = TokenAllowance {
            account: owner,
            spender: self.caller,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);

        return finalize_transfer_from_public(owner, recipient, amount, allowance_key);
    }

    async function finalize_transfer_from_public(
        sender: address,
        recipient: address,
        amount: u128,
        allowance_key: field
    ) {
        let is_sender_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(sender, false);
        assert_eq(is_sender_frozen, false);
        let is_recipient_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(recipient, false);
        assert_eq(is_recipient_frozen, false);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        // Check that the spender is authorized to spend the amount
        let current_allowance: u128 = allowances.get(allowance_key);
        // Decrease the allowance by the amount being spent
        allowances.set(allowance_key, current_allowance - amount);

        let sender_balance = balances.get(sender);
        balances.set(sender, sender_balance - amount);

        let recipient_balance = balances.get_or_use(recipient, 0u128);
        balances.set(recipient, recipient_balance + amount);
    }

    // Transfers public tokens from the caller to a recipient as a private token.
    // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
    // The sender must not be frozen in the freeze list.
    async transition transfer_public_to_private(
        recipient: address,
        public amount: u128,
    ) -> (ComplianceRecord, Token, Future) {
        let token: Token = Token {
            owner: recipient,
            amount: amount
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: self.caller,
            recipient: recipient,
        };

        return (compliance_record, token, f_transfer_public_to_private(amount, self.caller));
    }

    async function f_transfer_public_to_private(
        amount: u128,
        sender: address,
    ) {
        let is_sender_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(sender, false);
        assert_eq(is_sender_frozen, false);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let sender_balance = balances.get(sender);
        balances.set(sender, sender_balance - amount);
    }

    // Transfers public tokens from an owner to a recipient as a private token.
    // Can be called by any spender with sufficient allowance from the owner.
    // Decreases the spender’s allowance by the transferred amount.
    // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
    // The sender must not be frozen in the freeze list.
    async transition transfer_from_public_to_private(
        public owner: address,
        recipient: address,
        public amount: u128,
    ) -> (ComplianceRecord, Token, Future) {

        let token: Token = Token {
            owner: recipient,
            amount: amount
        };

        let allowance: TokenAllowance = TokenAllowance {
            account: owner,
            spender: self.caller,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: owner,
            recipient: recipient,
        };

        return (compliance_record, token, f_transfer_from_public_to_priv(owner, amount, allowance_key));
    }

    async function f_transfer_from_public_to_priv(
        sender: address,
        amount: u128,
        allowance_key: field,
    ) {
        let is_sender_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(sender, false);
        assert_eq(is_sender_frozen, false);

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        // Check that the spender is authorized to spend the amount
        let current_allowance: u128 = allowances.get(allowance_key);
        // Decrease the allowance by the amount being spent
        allowances.set(allowance_key, current_allowance - amount);

        let sender_balance = balances.get(sender);
        balances.set(sender, sender_balance - amount);
    }

    // Transfers private tokens from the record owner to a recipient.
    // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
    // The sender must not be frozen in the freeze list.
    // The sender's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    async transition transfer_private(
        recipient: address,
        amount: u128,
        input_record: Token,
        sender_merkle_proofs: [MerkleProof;2],
    ) -> (ComplianceRecord, Token, Token, Future) {
        let sender_root: field = verify_non_inclusion(input_record.owner, sender_merkle_proofs);

        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount
        };

        let transfer_record: Token = Token {
            owner: recipient,
            amount: amount
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: recipient,
        };

        return (compliance_record, updated_record, transfer_record, f_transfer_private(sender_root));
    }

    async function f_transfer_private(root: field) {

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let current_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
        let window: u32 = sealance_freezelist_registry.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);

        if (current_root != root) {
            let previous_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
            assert_eq(root, previous_root);
            let updated_height: u32 = sealance_freezelist_registry.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
            assert(updated_height + window > block.height);
        }
    }

    // Transfers private tokens from the record owner to a recipient as a public tokens.
    // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
    // A Credentials record is emitted for the sender
    // Both sender and recipient must not be frozen in the freeze list.
    // The sender's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    async transition transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input_record: Token,
        sender_merkle_proofs: [MerkleProof; 2],
    ) -> (ComplianceRecord, Token, Future) {
        let root: field = verify_non_inclusion(input_record.owner, sender_merkle_proofs);

        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: recipient,
        };

        return (
            compliance_record,
            updated_record,
            f_transfer_private_to_public(
                root,
                recipient,
                amount
            )
        );
    }

    async function f_transfer_private_to_public(
        root: field,
        recipient: address,
        amount: u128    ) {
        
        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let current_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
        let window: u32 = sealance_freezelist_registry.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);

        if (current_root != root) {
            let previous_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
            assert_eq(root, previous_root);
            let updated_height: u32 = sealance_freezelist_registry.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
            assert(updated_height + window > block.height);
        } 

        let is_recipient_frozen: bool = sealance_freezelist_registry.aleo/freeze_list.get_or_use(recipient, false);
        assert_eq(is_recipient_frozen, false);

        let recipient_balance = balances.get_or_use(recipient, 0u128);
        balances.set(recipient, recipient_balance + amount);
    }

    // Stops or resumes all token transfers.
    // Can only be called by an address with the PAUSE_ROLE.
    async transition set_pause_status(pause_status: bool) -> Future {
        return f_set_pause_status(pause_status, self.caller);
    }

    async function f_set_pause_status(new_pause_status: bool, caller: address) {
        let role: u16 = address_to_role.get(caller);
        assert(role & PAUSE_ROLE == PAUSE_ROLE);
        
        pause.set(PAUSE_STATUS_INDEX, new_pause_status);
    }


    transition join(
        private token_1: Token,
        private token_2: Token
    ) -> Token {
        let new_token: Token = Token {
            owner: token_1.owner,
            amount: token_1.amount + token_2.amount
        };

        return new_token;
    }

    transition split(
        private token: Token,
        private amount: u128
    ) -> (Token, Token) {
        let new_token_1: Token = Token {
            owner: token.owner,
            amount: amount
        };
        let new_token_2: Token = Token {
            owner: token.owner,
            amount: token.amount - amount
        };

        return (new_token_1, new_token_2);
    }

    // Transfers private tokens from the record owner to a recipient.
    // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
    // The sender must not be frozen in the freeze list.
    // The sender's privacy is preserved by using a Credentials record.
    async transition transfer_private_with_creds(
        recipient: address,
        amount: u128,
        input_record: Token,
        credentials: Credentials,
    ) -> (ComplianceRecord, Token, Token, Credentials, Future) {
        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount
        };

        let transfer_record: Token = Token {
            owner: recipient,
            amount: amount
        };

        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: recipient,
        };

        let credentials_record: Credentials = Credentials {
            owner: credentials.owner,
            freeze_list_root: credentials.freeze_list_root,
        };

        return (compliance_record, updated_record, transfer_record, credentials_record, f_transfer_private_credentials(credentials.freeze_list_root));
    }

    async function f_transfer_private_credentials(root: field) {

        let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
        assert_eq(is_paused, false);

        let current_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
        let window: u32 = sealance_freezelist_registry.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);

        if (current_root != root) {
            let previous_root: field = sealance_freezelist_registry.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
            assert_eq(root, previous_root);
            let updated_height: u32 = sealance_freezelist_registry.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
            assert(updated_height + window > block.height);
        }
    }

    // Calculates the hash of two sibling nodes in a Merkle tree.
    // The order of the siblings depends on the index bit (0 = left, 1 = right).
    // Uses Poseidon hash to compute the result.
    inline calculate_hash_for_nodes(sibling1: field, sibling2: field, indexbit: u32) -> field {
        let poseidon_params: [field; 3] = indexbit == 0u32 ? [0field, sibling1, sibling2] : [0field, sibling2, sibling1];
        return Poseidon4::hash_to_field(poseidon_params);
    }

    inline calculate_hash_for_leaves(sibling1: field, sibling2: field, indexbit: u32) -> field {
        let poseidon_params: [field; 3] = indexbit == 0u32 ? [1field, sibling1, sibling2] : [1field, sibling2, sibling1];
        return Poseidon4::hash_to_field(poseidon_params);
    }

    // Calculates the Merkle root and the depth of a Merkle proof path.
    // Iteratively hashes the sibling path based on the leaf index to reconstruct the root.
    // Stops when a zero field is encountered in the siblings array, indicating the end of the valid path.
    // Returns the calculated root and the actual depth reached.
    inline calculate_root_depth_siblings(merkle_proof: MerkleProof) -> (public field, public u32) {
        let root: field = calculate_hash_for_leaves(merkle_proof.siblings[0u8], merkle_proof.siblings[1u8],  merkle_proof.leaf_index % 2u32);
        for i: u32 in 2u32..MAX_TREE_DEPTH + 1u32 {
            if (merkle_proof.siblings[i] == 0field) {
                return (root, i - 1u32);
            }
            root = calculate_hash_for_nodes(root, merkle_proof.siblings[i], (merkle_proof.leaf_index / (2u32**(i-1u32))) % 2u32);
        }
        return (root, MAX_TREE_DEPTH);
    }

    // Verifies non-inclusion of an address in a Merkle tree sorted in ascending order by address (as field).
    // Accepts two Merkle proofs representing the neighboring leaves around the missing address.
    // Returns the common Merkle root if the address is proven to be outside the tree.
    // If the tree is not sorted correctly, this function may return incorrect results.
    inline verify_non_inclusion(addr: address, merkle_proofs: [MerkleProof;2]) -> field {
        let (root1, depth1): (field, u32)= calculate_root_depth_siblings(merkle_proofs[0u32]);
        let (root2, depth2): (field, u32) = calculate_root_depth_siblings(merkle_proofs[1u32]);

        // Ensure the roots from the merkle proofs are the same
        assert_eq(root1, root2);
        // Ensure the depth of the merkle proofs is the same
        assert_eq(depth1, depth2);
        
        let addr_field: field = addr as field;
        if (merkle_proofs[0u32].leaf_index == merkle_proofs[1u32].leaf_index) {
            // Ensure that if the address is the most left leaf, it is less than the first sibling
            if (merkle_proofs[0u32].leaf_index == 0u32) {
                assert(addr_field < merkle_proofs[0u32].siblings[0u32]);
            } else {
                // Ensure that if the address is the most right leaf
                let last_index_leaf: u32 = 2u32 ** depth1 - 1u32;
                assert_eq(merkle_proofs[0u32].leaf_index, last_index_leaf);
                // Ensure that the address is bigger than the first sibling
                assert(addr_field > merkle_proofs[0u32].siblings[0u32]);
            }
        } else {
            // Ensure the address is in between the provided leaves
            assert(addr_field > merkle_proofs[0u32].siblings[0u32]);
            assert(addr_field < merkle_proofs[1u32].siblings[0u32]);
            // Ensure that the leaf indexes are not greater than the last possible leaf index
            let last_index_leaf: u32 = 2u32 ** depth1 - 1u32;
            assert(merkle_proofs[1u32].leaf_index <= last_index_leaf);
            // Ensure the leaves are adjacent
            assert_eq(merkle_proofs[0u32].leaf_index + 1u32, merkle_proofs[1u32].leaf_index);
        }
        
        return root1;
    }
}