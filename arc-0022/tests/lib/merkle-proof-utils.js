/**
 * Merkle proof utilities for compliant_token_template tests.
 * Uses @sealance-io/policy-engine-aleo for proof generation.
 */
import { buildTree, generateLeaves, getLeafIndices, getSiblingPath } from "@sealance-io/policy-engine-aleo";

const SIBLINGS_LENGTH = 16;

/**
 * Convert a Merkle proof object to Leo struct string format.
 * @param {{ siblings: bigint[], leaf_index: number }} proof - Proof from getSiblingPath
 * @returns {string} Leo struct string, e.g. "{ siblings: [0field, ...], leaf_index: 1u32 }"
 */
export function formatMerkleProofForLeo(proof) {
  const siblings = proof.siblings ?? [];
  const padded = [...siblings];
  while (padded.length < SIBLINGS_LENGTH) {
    padded.push(0n);
  }
  const siblingsStr = padded
    .slice(0, SIBLINGS_LENGTH)
    .map((v) => `${v}field`)
    .join(", ");
  return `{ siblings: [${siblingsStr}], leaf_index: ${proof.leaf_index}u32 }`;
}

/**
 * Generate non-inclusion Merkle proofs for an address against a freeze list.
 * @param {string} address - Aleo address to prove non-inclusion for
 * @param {string[]} freezeListAddresses - Addresses in the freeze list (empty = only ZERO_ADDRESS)
 * @returns {string} Leo-format string for [MerkleProof; 2], e.g. "[{...}, {...}]"
 */
export function generateNonInclusionProof(address, freezeListAddresses = []) {
  const leaves = generateLeaves(freezeListAddresses);
  const tree = buildTree(leaves);
  const [leftIdx, rightIdx] = getLeafIndices(tree, address);
  const proof1 = getSiblingPath(tree, leftIdx, 15);
  const proof2 = getSiblingPath(tree, rightIdx, 15);
  const formatted1 = formatMerkleProofForLeo(proof1);
  const formatted2 = formatMerkleProofForLeo(proof2);
  return `[${formatted1}, ${formatted2}]`;
}
