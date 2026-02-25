program merkle_tree.aleo {
    @noupgrade
    async constructor() {}

    // Defines the maximum depth of the Merkle tree used in freeze list proofs.
    // Trees deeper than this value are not supported.
    const MAX_TREE_DEPTH: u32 = 15u32;
    
    struct MerkleProof {
        siblings: [field; 16],
        leaf_index: u32
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
    
    // Verifies that the given address is included in a Merkle tree.
    // Asserts that the address matches the first sibling (leaf node).
    // Computes the Merkle root and returns it for comparison against a known root.
    transition verify_inclusion(addr: address, merkle_proof: MerkleProof) -> field {
      assert_eq(addr as field, merkle_proof.siblings[0u32]);
      let (root, depth): (field, u32) = calculate_root_depth_siblings(merkle_proof);
      return root;
    } 

    // Verifies non-inclusion of an address in a Merkle tree sorted in ascending order by address (as field).
    // Accepts two Merkle proofs representing the neighboring leaves around the missing address.
    // Returns the common Merkle root if the address is proven to be outside the tree.
    // If the tree is not sorted correctly, this function may return incorrect results.
    transition verify_non_inclusion(addr: address, merkle_proofs: [MerkleProof;2]) -> field {
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