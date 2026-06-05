// The 'IARC22' library.
const MAX_TREE_DEPTH: u32 = 15u32;

// ZERO_ADDRESS as field == 0field
const ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

// EMPTY_ROOT == hash of H(ZERO_ADDRESS, ZERO_ADDRESS)
const EMPTY_ROOT: field = 3642222252059314292809609689035560016959342421640560347114299934615987159853field;

struct MerkleProof {
    siblings: [field; MAX_TREE_DEPTH + 1],
    leaf_index: u32,
}

//=============================================================
//               MERKLE TREE HELPER FUNCTIONS
//=============================================================
// Calculates the hash of two sibling nodes in a Merkle tree.
// The order of the siblings depends on the index bit (0 = left, 1 = right).
// Uses Poseidon hash to compute the result.
fn calculate_hash_for_nodes(sibling1: field, sibling2: field, indexbit: u32) -> field {
    let poseidon_params: [field; 3] = indexbit == 0u32 ? [0field, sibling1, sibling2] : [
        0field,
        sibling2,
        sibling1,
    ];
    return Poseidon4::hash_to_field(poseidon_params);
}

fn calculate_hash_for_leaves(sibling1: field, sibling2: field, indexbit: u32) -> field {
    let poseidon_params: [field; 3] = indexbit == 0u32 ? [1field, sibling1, sibling2] : [
        1field,
        sibling2,
        sibling1,
    ];
    return Poseidon4::hash_to_field(poseidon_params);
}

// Calculates the Merkle root and the depth of a Merkle proof path.
// Iteratively hashes the sibling path based on the leaf index to reconstruct the root.
// Stops when a zero field is encountered in the siblings array, indicating the end of the valid path.
// Returns the calculated root and the actual depth reached.
fn calculate_root_depth_siblings(merkle_proof: MerkleProof) -> (field, u32) {
    let root: field = calculate_hash_for_leaves(
        merkle_proof.siblings[0u8],
        merkle_proof.siblings[1u8],
        merkle_proof.leaf_index % 2u32,
    );
    for i: u32 in 2u32..MAX_TREE_DEPTH + 1u32 {
        if (merkle_proof.siblings[i] == 0field) {
            return (root, i - 1u32);
        }
        root = calculate_hash_for_nodes(
            root,
            merkle_proof.siblings[i],
            (merkle_proof.leaf_index / (2u32 ** (i - 1u32))) % 2u32,
        );
    }
    return (root, MAX_TREE_DEPTH);
}

// Verifies that the given address is included in a Merkle tree.
// Asserts that the address matches the first sibling (leaf node).
// Computes the Merkle root and returns it for comparison against a known root.
fn verify_inclusion(addr: address, merkle_proof: MerkleProof) -> field {
    assert_eq(addr as field, merkle_proof.siblings[0u32]);
    let (root, depth): (field, u32) = calculate_root_depth_siblings(merkle_proof);
    return root;
}

// Verifies non-inclusion of an address in a Merkle tree sorted in ascending order by address (as field).
// Accepts two Merkle proofs representing the neighboring leaves around the missing address.
// Returns the common Merkle root if the address is proven to be outside the tree.
// If the tree is not sorted correctly, this function may return incorrect results.
fn verify_non_inclusion(addr: address, merkle_proofs: [MerkleProof; 2]) -> field {
    let (root1, depth1): (field, u32) = calculate_root_depth_siblings(merkle_proofs[0u32]);
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

interface IARC22Freezelist {
    fn initialize(public admin: address, public blocks: u32) -> Final;
    fn update_freeze_list(
        public account: address,
        public is_frozen: bool,
        public index: u32,
        public existing_root: field,
        public new_root: field,
    ) -> Final;
    fn verify_non_inclusion_pub(public account: address) -> Final;
    fn verify_non_inclusion_priv(account: address, merkle_proof: [MerkleProof; 2u32]) -> Final;

    //=============================================================
    //                VIEW FUNCTIONS
    //=============================================================
    view fn is_frozen_address(account: address) -> bool;
    view fn is_frozen_index(index: u32) -> bool;
    view fn current_freeze_list_root() -> field;
    view fn previous_freeze_list_root() -> field;
    view fn root_updated_height() -> u32;
    view fn block_height_window() -> u32;
}

interface IARC22 {
    record Token {
        owner: address,
        amount: u128,
        ..
    }

    record ComplianceRecord {
        owner: address,     // INVESTIGATOR_ADDRESS
        amount: u128,
        sender: address,    // ZERO_ADDRESS for mint paths
        recipient: address, // ZERO_ADDRESS for burn paths
        .. 
    }

    //=============================================================
    //               APPROVAL FUNCTIONS
    //=============================================================
    fn approve_public(public spender: address, public amount: u128) -> Final;
    fn unapprove_public(public spender: address, public amount: u128) -> Final;

    //=============================================================
    //               TRANSFER FUNCTIONS
    //=============================================================
    fn transfer_public(public recipient: address, public amount: u128) -> Final;
    fn transfer_private(
        private recipient: address,
        private amount: u128,
        private input_record: Token,
        private sender_merkle_proofs: [MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Token, Final);
    fn transfer_private_to_public(
        public recipient: address,
        public amount: u128,
        private input_record: Token,
        private sender_merkle_proofs: [MerkleProof; 2u32],
    ) -> (ComplianceRecord, Token, Final);
    fn transfer_public_to_private(recipient: address, public amount: u128) -> (
        ComplianceRecord, Token, Final,
    );
    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final;
    fn transfer_from_public_to_private(
        public owner: address,
        private recipient: address,
        public amount: u128,
    ) -> (ComplianceRecord, Token, Final);
    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final;

    //=============================================================
    //               JOIN/SPLIT FUNCTIONS
    //=============================================================
    fn join(input_1: Token, input_2: Token) -> Token;
    fn split(input: Token, amount: u128) -> (Token, Token);

    //=============================================================
    //                VIEW FUNCTIONS
    //=============================================================
    view fn balance_of(account: address) -> u128;
    view fn allowance(owner: address, spender: address) -> u128;
    view fn supply() -> u128;
    view fn max_supply() -> u128;
    view fn decimals() -> u8;
    view fn name() -> identifier;
    view fn symbol() -> identifier;
}
