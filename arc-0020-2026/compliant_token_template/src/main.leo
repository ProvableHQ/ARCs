import freezelist.aleo;
import multisig_core.aleo;

// Merkle proof helpers (outside program scope; callable from program fns).
const MAX_TREE_DEPTH: u32 = 15u32;

fn calculate_hash_for_nodes(sibling1: field, sibling2: field, indexbit: u32) -> field {
    let poseidon_params: [field; 3] = indexbit == 0u32 ? [0field, sibling1, sibling2] : [0field, sibling2, sibling1];
    return Poseidon4::hash_to_field(poseidon_params);
}

fn calculate_hash_for_leaves(sibling1: field, sibling2: field, indexbit: u32) -> field {
    let poseidon_params: [field; 3] = indexbit == 0u32 ? [1field, sibling1, sibling2] : [1field, sibling2, sibling1];
    return Poseidon4::hash_to_field(poseidon_params);
}

fn calculate_root_depth_siblings(merkle_proof: freezelist.aleo/MerkleProof) -> (field, u32) {
    let poseidon0: [field; 3] = merkle_proof.leaf_index % 2u32 == 0u32
        ? [1field, merkle_proof.siblings[0u32], merkle_proof.siblings[1u32]]
        : [1field, merkle_proof.siblings[1u32], merkle_proof.siblings[0u32]];
    let root: field = Poseidon4::hash_to_field(poseidon0);
    let depth: u32 = MAX_TREE_DEPTH;
    for i: u32 in 2u32..MAX_TREE_DEPTH + 1u32 {
        depth = (merkle_proof.siblings[i] == 0field && depth == MAX_TREE_DEPTH) ? (i - 1u32) : depth;
        let poseidon_n: [field; 3] = (merkle_proof.leaf_index / (2u32 ** (i - 1u32))) % 2u32 == 0u32
            ? [0field, root, merkle_proof.siblings[i]]
            : [0field, merkle_proof.siblings[i], root];
        root = (merkle_proof.siblings[i] == 0field) ? root : Poseidon4::hash_to_field(poseidon_n);
    }
    return (root, depth);
}

fn verify_non_inclusion(addr: address, merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> field {
    let (root1, depth1) = calculate_root_depth_siblings(merkle_proofs[0u32]);
    let (root2, depth2) = calculate_root_depth_siblings(merkle_proofs[1u32]);
    assert_eq(root1, root2);
    assert_eq(depth1, depth2);
    let addr_field: field = addr as field;
    if (merkle_proofs[0u32].leaf_index == merkle_proofs[1u32].leaf_index) {
        if (merkle_proofs[0u32].leaf_index == 0u32) {
            assert(addr_field < merkle_proofs[0u32].siblings[0u32]);
        } else {
            let last_index_leaf: u32 = 2u32 ** depth1 - 1u32;
            assert_eq(merkle_proofs[0u32].leaf_index, last_index_leaf);
            assert(addr_field > merkle_proofs[0u32].siblings[0u32]);
        }
    } else {
        assert(addr_field > merkle_proofs[0u32].siblings[0u32]);
        assert(addr_field < merkle_proofs[1u32].siblings[0u32]);
        let last_index_leaf: u32 = 2u32 ** depth1 - 1u32;
        assert(merkle_proofs[1u32].leaf_index <= last_index_leaf);
        assert_eq(merkle_proofs[0u32].leaf_index + 1u32, merkle_proofs[1u32].leaf_index);
    }
    return root1;
}

// ARC20Compliant: like ARC20 but transfer_private* require Merkle proofs for freeze-list compliance.
interface ARC20Compliant {
    record Token;
    record ComplianceRecord;

    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(recipient: address, amount: u128, input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(public recipient: address, public amount: u128, input_record: Token, sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (ComplianceRecord, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final);
    fn transfer_from_public_to_private(public owner: address, recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final);

    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
}

// DEPLOYER_ADDRESS: must match test account (AleoUtils.addresses[0]) for tests.
program compliant_token_template.aleo: ARC20Compliant {
    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });
            let wallet_signing_op_id_hash = BHP256::hash_to_field(multisig_core.aleo/WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = multisig_core.aleo/completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    // A helper for calculating a signing_op_id from the program's checksum and edition.
    fn get_signing_op_id_for_deploy(checksum: [u8; 32], edition: u16) -> field {
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
 const PAUSE_ROLE: u16 = 4u16; // can pause/unpause transfers
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

 // -------------------------
 // Called by token admins
 // -------------------------


 // Updates the address assigned to a given role.
 // Can only be called by the current role manager.
    fn update_role(public new_address: address, role: u16) -> Final {
        let caller = self.caller;
        return final {
            let current_role: u16 = address_to_role.get(caller);
            assert(current_role & MANAGER_ROLE == MANAGER_ROLE);
            if (caller == new_address) {
                assert(role & MANAGER_ROLE == MANAGER_ROLE);
            }
            address_to_role.set(new_address, role);
        };
    }

 // Initializes the freeze list, token specifications, the admin and the investigator.
 // Can be called only once and only by the INITIAL_ADMIN 
 // Sets the token metadata (name, symbol, decimals, max supply).
 // Sets the block height window, the initial empty Merkle root,
 // and initialize the freeze_list_last_index, freeze_list, and freeze_list_index with a ZERO_ADDRESS placeholder.
    fn initialize(
        public name: u128,
        public symbol: u128,
        public decimals: u8,
        public max_supply: u128,
        public admin: address,
    ) -> Final {
        let caller = self.caller;
        return final {
            let already_initialized: bool = token_info.contains(TOKEN_INFO_INDEX);
            assert_eq(already_initialized, false);
            assert_eq(caller, DEPLOYER_ADDRESS);
            address_to_role.set(admin, MANAGER_ROLE);
            let token: TokenInfo = TokenInfo {
                name: name,
                symbol: symbol,
                decimals: decimals,
                supply: 0u128,
                max_supply: max_supply,
            };
            token_info.set(TOKEN_INFO_INDEX, token);
            pause.set(PAUSE_STATUS_INDEX, false);
        };
    }

 // Generates a Credential record for the signer.
 // Allows future private transfers without needing to re-prove non-inclusion in the freeze list.
 // The signer's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    fn get_credentials(sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32]) -> (Credentials, Final) {
        let root: field = verify_non_inclusion(self.signer, sender_merkle_proofs);
        let credentials_record: Credentials = Credentials {
            owner: self.signer,
            freeze_list_root: root,
        };
        return (
            credentials_record,
            final {
                let current_root: field = freezelist.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
                let window: u32 = freezelist.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);
                if (current_root != root) {
                    let previous_root: field = freezelist.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
                    assert_eq(root, previous_root);
                    let updated_height: u32 = freezelist.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
                    assert(updated_height + window > block.height);
                }
            },
        );
    }

 // Mints new public tokens to the specified recipient’s balance.
 // Can only be called by a minter.
 // Ensures that the new total supply does not exceed the maximum supply.
 // Updates the recipient’s balance and the total token supply in the token metadata.
    fn mint_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & MINTER_ROLE == MINTER_ROLE);
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let token = token_info.get(TOKEN_INFO_INDEX);
            let new_supply: u128 = token.supply + amount;
            assert(new_supply <= token.max_supply);
            let balance = balances.get_or_use(recipient, 0u128);
            let new_balance = amount + balance;
            balances.set(recipient, new_balance);
            let new_metadata: TokenInfo = TokenInfo {
                name: token.name,
                symbol: token.symbol,
                decimals: token.decimals,
                supply: new_supply,
                max_supply: token.max_supply,
            };
            token_info.set(TOKEN_INFO_INDEX, new_metadata);
        };
    }

 // Mints new private tokens to the specified recipient.
 // Can only be called by a minter.
 // Ensures that the new total supply does not exceed the maximum supply.
 // Updates the total token supply in the token metadata.
    fn mint_private(recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount };
        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: ZERO_ADDRESS,
            recipient: recipient,
        };
        let caller = self.caller;
        return (
            compliance_record,
            token,
            final {
                let role: u16 = address_to_role.get(caller);
                assert(role & MINTER_ROLE == MINTER_ROLE);
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let token_meta = token_info.get(TOKEN_INFO_INDEX);
                let new_supply: u128 = token_meta.supply + amount;
                assert(new_supply <= token_meta.max_supply);
                let new_metadata: TokenInfo = TokenInfo {
                    name: token_meta.name,
                    symbol: token_meta.symbol,
                    decimals: token_meta.decimals,
                    supply: new_supply,
                    max_supply: token_meta.max_supply,
                };
                token_info.set(TOKEN_INFO_INDEX, new_metadata);
            },
        );
    }

 // Burns public tokens from the specified owner’s balance.
 // Can only be called by a burner.
 // Decreases the owner’s balance and reduces the total token supply in the token metadata.
    fn burn_public(public owner: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & BURNER_ROLE == BURNER_ROLE);
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let balance = balances.get(owner);
            let new_balance = balance - amount;
            balances.set(owner, new_balance);
            let token = token_info.get(TOKEN_INFO_INDEX);
            let new_metadata: TokenInfo = TokenInfo {
                name: token.name,
                symbol: token.symbol,
                decimals: token.decimals,
                supply: token.supply - amount,
                max_supply: token.max_supply,
            };
            token_info.set(TOKEN_INFO_INDEX, new_metadata);
        };
    }

 // Burns tokens from a private record (non-public asset).
 // Can only be called by a burner.
 // Reduces the amount in the provided private record and decreases the total token supply in the token metadata.
    fn burn_private(input_record: Token, public amount: u128) -> (ComplianceRecord, Token, Final) {
        let output_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount,
        };
        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: ZERO_ADDRESS,
        };
        let caller = self.caller;
        return (
            compliance_record,
            output_record,
            final {
                let role: u16 = address_to_role.get(caller);
                assert(role & BURNER_ROLE == BURNER_ROLE);
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let token = token_info.get(TOKEN_INFO_INDEX);
                let new_metadata: TokenInfo = TokenInfo {
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    supply: token.supply - amount,
                    max_supply: token.max_supply,
                };
                token_info.set(TOKEN_INFO_INDEX, new_metadata);
            },
        );
    }

 // -------------------------
 // Called by token owners/DeFi contracts
 // -------------------------

 // Transfers public tokens from the caller to the recipient.
 // Both sender and recipient must not be frozen in the freeze list.
    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let sender = self.caller;
        return final {
            let is_sender_frozen: bool = freezelist.aleo/freeze_list.get_or_use(sender, false);
            assert_eq(is_sender_frozen, false);
            let is_recipient_frozen: bool = freezelist.aleo/freeze_list.get_or_use(recipient, false);
            assert_eq(is_recipient_frozen, false);
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let sender_balance = balances.get(sender);
            balances.set(sender, sender_balance - amount);
            let recipient_balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, recipient_balance + amount);
        };
    }

 // Transfers public tokens from the signer to the recipient.
 // Both sender and recipient must not be frozen in the freeze list.
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let sender = self.signer;
        return final {
            let is_sender_frozen: bool = freezelist.aleo/freeze_list.get_or_use(sender, false);
            assert_eq(is_sender_frozen, false);
            let is_recipient_frozen: bool = freezelist.aleo/freeze_list.get_or_use(recipient, false);
            assert_eq(is_recipient_frozen, false);
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let sender_balance = balances.get(sender);
            balances.set(sender, sender_balance - amount);
            let recipient_balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, recipient_balance + amount);
        };
    }

 // Approves a spender to transfer the caller’s public assets up to a specified amount.
 // Increases the existing allowance if one is already set, otherwise creates a new allowance.
 // The allowance is stored using a hash of the owner–spender pair as the key.
    fn approve_public(public spender: address, public amount: u128) -> Final {
        let allowance: TokenAllowance = TokenAllowance {
            account: self.caller,
            spender: spender,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        return final {
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let current_allowance: u128 = allowances.get_or_use(allowance_key, 0u128);
            allowances.set(allowance_key, current_allowance + amount);
        };
    }

 // Reduces a spender’s allowance to transfer the caller’s public assets by a specified amount.
 // Decreases the existing allowance stored under the hash of the owner–spender pair.
 // If the reduction exceeds the current allowance, the VM will catch the underflow.
    fn unapprove_public(public spender: address, public amount: u128) -> Final {
        let allowance: TokenAllowance = TokenAllowance {
            account: self.caller,
            spender: spender,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        return final {
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let current_allowance: u128 = allowances.get(allowance_key);
            allowances.set(allowance_key, current_allowance - amount);
        };
    }

 // Transfers public tokens from the owner to the recipient.
 // Can be called by any spender with sufficient allowance from the owner.
 // Decreases the spender’s allowance by the transferred amount.
 // Both sender and recipient must not be frozen in the freeze list.
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final {
        let allowance: TokenAllowance = TokenAllowance {
            account: owner,
            spender: self.caller,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        return final {
            let is_sender_frozen: bool = freezelist.aleo/freeze_list.get_or_use(owner, false);
            assert_eq(is_sender_frozen, false);
            let is_recipient_frozen: bool = freezelist.aleo/freeze_list.get_or_use(recipient, false);
            assert_eq(is_recipient_frozen, false);
            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);
            let current_allowance: u128 = allowances.get(allowance_key);
            allowances.set(allowance_key, current_allowance - amount);
            let sender_balance = balances.get(owner);
            balances.set(owner, sender_balance - amount);
            let recipient_balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, recipient_balance + amount);
        };
    }

 // Transfers public tokens from the caller to a recipient as a private token.
 // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
 // The sender must not be frozen in the freeze list.
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount };
        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: self.caller,
            recipient: recipient,
        };
        let sender = self.caller;
        return (
            compliance_record,
            token,
            final {
                let is_sender_frozen: bool = freezelist.aleo/freeze_list.get_or_use(sender, false);
                assert_eq(is_sender_frozen, false);
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let sender_balance = balances.get(sender);
                balances.set(sender, sender_balance - amount);
            },
        );
    }

 // Transfers public tokens from an owner to a recipient as a private token.
 // Can be called by any spender with sufficient allowance from the owner.
 // Decreases the spender’s allowance by the transferred amount.
 // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
 // The sender must not be frozen in the freeze list.
    fn transfer_from_public_to_private(public owner: address, recipient: address, public amount: u128) -> (ComplianceRecord, Token, Final) {
        let token: Token = Token { owner: recipient, amount: amount };
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
        return (
            compliance_record,
            token,
            final {
                let is_sender_frozen: bool = freezelist.aleo/freeze_list.get_or_use(owner, false);
                assert_eq(is_sender_frozen, false);
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let current_allowance: u128 = allowances.get(allowance_key);
                allowances.set(allowance_key, current_allowance - amount);
                let sender_balance = balances.get(owner);
                balances.set(owner, sender_balance - amount);
            },
        );
    }

 // Transfers private tokens from the record owner to a recipient.
 // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
 // The sender must not be frozen in the freeze list.
 // The sender's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    fn transfer_private(
        recipient: address,
        amount: u128,
        input_record: Token,
        sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Token, Final) {
        let sender_root: field = verify_non_inclusion(input_record.owner, sender_merkle_proofs);
        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount,
        };
        let transfer_record: Token = Token { owner: recipient, amount: amount };
        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: input_record.owner,
            recipient: recipient,
        };
        return (
            compliance_record,
            updated_record,
            transfer_record,
            final {
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let current_root: field = freezelist.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
                let window: u32 = freezelist.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);
                if (current_root != sender_root) {
                    let previous_root: field = freezelist.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
                    assert_eq(sender_root, previous_root);
                    let updated_height: u32 = freezelist.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
                    assert(updated_height + window > block.height);
                }
            },
        );
    }

 // Transfers private tokens from the record owner to a recipient as a public tokens.
 // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
 // A Credentials record is emitted for the sender
 // Both sender and recipient must not be frozen in the freeze list.
 // The sender's privacy is preserved by proving non-inclusion in the freeze list Merkle tree.
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        input_record: Token,
        sender_merkle_proofs: [freezelist.aleo/MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Final) {
        let root: field = verify_non_inclusion(input_record.owner, sender_merkle_proofs);
        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount,
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
            final {
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let current_root: field = freezelist.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
                let window: u32 = freezelist.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);
                if (current_root != root) {
                    let previous_root: field = freezelist.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
                    assert_eq(root, previous_root);
                    let updated_height: u32 = freezelist.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
                    assert(updated_height + window > block.height);
                }
                let is_recipient_frozen: bool = freezelist.aleo/freeze_list.get_or_use(recipient, false);
                assert_eq(is_recipient_frozen, false);
                let recipient_balance = balances.get_or_use(recipient, 0u128);
                balances.set(recipient, recipient_balance + amount);
            },
        );
    }

 // Stops or resumes all token transfers.
 // Can only be called by an address with the PAUSE_ROLE.
    fn set_pause_status(pause_status: bool) -> Final {
        let caller = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & PAUSE_ROLE == PAUSE_ROLE);
            pause.set(PAUSE_STATUS_INDEX, pause_status);
        };
    }

    fn join(private token_1: Token, private token_2: Token) -> Token {
        let new_token: Token = Token {
            owner: token_1.owner,
            amount: token_1.amount + token_2.amount,
        };
        return new_token;
    }

    fn split(private token: Token, private amount: u128) -> (Token, Token) {
        let new_token_1: Token = Token { owner: token.owner, amount: amount };
        let new_token_2: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };
        return (new_token_1, new_token_2);
    }

 // Transfers private tokens from the record owner to a recipient.
 // A ComplianceRecord is emitted for the investigator, who must match the stored investigator role.
 // The sender must not be frozen in the freeze list.
 // The sender's privacy is preserved by using a Credentials record.
    fn transfer_private_with_creds(
        recipient: address,
        amount: u128,
        input_record: Token,
        credentials: Credentials,
    ) -> (ComplianceRecord, Token, Token, Credentials, Final) {
        let updated_record: Token = Token {
            owner: input_record.owner,
            amount: input_record.amount - amount,
        };
        let transfer_record: Token = Token { owner: recipient, amount: amount };
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
        let root: field = credentials.freeze_list_root;
        return (
            compliance_record,
            updated_record,
            transfer_record,
            credentials_record,
            final {
                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);
                let current_root: field = freezelist.aleo/freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
                let window: u32 = freezelist.aleo/block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);
                if (current_root != root) {
                    let previous_root: field = freezelist.aleo/freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
                    assert_eq(root, previous_root);
                    let updated_height: u32 = freezelist.aleo/root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
                    assert(updated_height + window > block.height);
                }
            },
        );
    }

}