import merkle_tree.aleo;
import multisig_core.aleo;

program freezelist.aleo {
    @custom
    constructor() {
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(
                ChecksumEdition { checksum: self.checksum, edition: self.edition },
            );
            let wallet_signing_op_id_hash = BHP256::hash_to_field(
                multisig_core.aleo::WalletSigningOpId {
                    wallet_id: self.address,
                    signing_op_id: signing_op_id,
                },
            );
            let signing_complete = multisig_core.aleo::completed_signing_ops
                .contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    const ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    const EMPTY_ROOT: field = 3642222252059314292809609689035560016959342421640560347114299934615987159853field;
    const DEPLOYER_ADDRESS: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    const NONE_ROLE: u16 = 0u16;
    const MANAGER_ROLE: u16 = 8u16;
    const FREEZELIST_MANAGER_ROLE: u16 = 16u16;
    mapping address_to_role: address => u16;

    const CURRENT_FREEZE_LIST_ROOT_INDEX: u8 = 1u8;
    const PREVIOUS_FREEZE_LIST_ROOT_INDEX: u8 = 2u8;
    const ROOT_UPDATED_HEIGHT_INDEX: bool = true;
    const BLOCK_HEIGHT_WINDOW_INDEX: bool = true;
    const FREEZE_LIST_LAST_INDEX: bool = true;

    struct ChecksumEdition {
        checksum: [u8; 32],
        edition: u16,
    }

    struct MerkleProof {
        siblings: [field; 16],
        leaf_index: u32,
    }

    mapping freeze_list: address => bool;
    mapping freeze_list_index: u32 => address;
    mapping freeze_list_last_index: bool => u32;
    mapping freeze_list_root: u8 => field;
    mapping root_updated_height: bool => u32;
    mapping block_height_window: bool => u32;

    fn initialize(public admin: address, public blocks: u32) -> Final {
        let caller = self.caller;
        return final {
            let is_already_initialized: bool = freeze_list_root
                .contains(CURRENT_FREEZE_LIST_ROOT_INDEX);
            assert_eq(is_already_initialized, false);
            assert_eq(caller, DEPLOYER_ADDRESS);
            address_to_role.set(admin, MANAGER_ROLE);
            block_height_window.set(BLOCK_HEIGHT_WINDOW_INDEX, blocks);
            freeze_list_last_index.set(FREEZE_LIST_LAST_INDEX, 0u32);
            freeze_list_root.set(CURRENT_FREEZE_LIST_ROOT_INDEX, EMPTY_ROOT);
            freeze_list.set(ZERO_ADDRESS, false);
            freeze_list_index.set(0u32, ZERO_ADDRESS);
        };
    }

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

    fn update_block_height_window(public blocks: u32) -> Final {
        let caller = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & FREEZELIST_MANAGER_ROLE == FREEZELIST_MANAGER_ROLE);
            block_height_window.set(BLOCK_HEIGHT_WINDOW_INDEX, blocks);
        };
    }

    fn update_freeze_list(
        public account: address,
        public is_frozen: bool,
        public frozen_index: u32,
        public previous_root: field,
        public new_root: field,
    ) -> Final {
        let caller = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & FREEZELIST_MANAGER_ROLE == FREEZELIST_MANAGER_ROLE);
            let old_root: field = freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
            assert_eq(previous_root, old_root);
            freeze_list_root.set(PREVIOUS_FREEZE_LIST_ROOT_INDEX, old_root);
            freeze_list_root.set(CURRENT_FREEZE_LIST_ROOT_INDEX, new_root);
            let stored_is_frozen = freeze_list.get_or_use(account, false);
            assert_neq(is_frozen, stored_is_frozen);
            freeze_list.set(account, is_frozen);
            let current_address_at_index: address = freeze_list_index
                .get_or_use(frozen_index,ZERO_ADDRESS);
            if (is_frozen) {
                assert_eq(current_address_at_index, ZERO_ADDRESS);
                let last_index: u32 = freeze_list_last_index.get(FREEZE_LIST_LAST_INDEX);
                assert(last_index + 1u32 >= frozen_index);
                if (last_index < frozen_index) {
                    freeze_list_last_index.set(FREEZE_LIST_LAST_INDEX, frozen_index);
                }
                freeze_list_index.set(frozen_index, account);
            } else {
                assert_eq(current_address_at_index, account);
                freeze_list_index.set(frozen_index, ZERO_ADDRESS);
            }
            root_updated_height.set(ROOT_UPDATED_HEIGHT_INDEX, block.height);
        };
    }

    fn verify_non_inclusion_pub(public account: address) -> Final {
        return final {
            let is_frozen: bool = freeze_list.get_or_use(account, false);
            assert_eq(is_frozen, false);
        };
    }

    fn verify_non_inclusion_priv(
        account: address,
        merkle_proof: [merkle_tree.aleo::MerkleProof; 2u32],
    ) -> Final {
        let root: field = merkle_tree.aleo::verify_non_inclusion(account, merkle_proof);
        return final {
            let current_root: field = freeze_list_root.get(CURRENT_FREEZE_LIST_ROOT_INDEX);
            if (current_root != root) {
                let previous_root: field = freeze_list_root.get(PREVIOUS_FREEZE_LIST_ROOT_INDEX);
                assert_eq(root, previous_root);
                let window: u32 = block_height_window.get(BLOCK_HEIGHT_WINDOW_INDEX);
                let updated_height: u32 = root_updated_height.get(ROOT_UPDATED_HEIGHT_INDEX);
                assert(updated_height + window > block.height);
            }
        };
    }
}
