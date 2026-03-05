/**
 * ARC-0020 Integration Tests
 *
 * Tests the full program stack using the @provablehq/sdk devnode transaction
 * builder, which generates dummy proofs accepted by a local devnode but not
 * by mainnet validators.
 *
 * Prerequisites
 * =============
 * 1. Install dependencies:
 *      npm install
 *
 * 2. Start a fresh devnode in a separate terminal:
 *      npm run devnode
 *
 *    Which runs:
 *      leo devnode start \
 *        --home /tmp/arc0020_devnode \
 *        --manual-block-creation \
 *        --private-key APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH
 *
 *    NOTE: The devnode uses compiled-in TEST_CONSENSUS_VERSION_HEIGHTS from
 *    snarkVM (b0dd5c5). V9 activates at block 12. The --consensus-heights CLI
 *    flag is NOT applied by the devnode binary (ignored by start.rs).
 *
 * 3. Run:
 *      node test.js
 *
 * WASM SDK Compatibility Note
 * ===========================
 * Consensus Versions
 * ==================
 * Devnode uses compiled-in TEST_CONSENSUS_VERSION_HEIGHTS (snarkVM b0dd5c5):
 *   V9 activates at block 12. The --consensus-heights CLI flag is ignored.
 * SDK WASM uses SDK_CONSENSUS_HEIGHTS (12 heights): first 12 devnode heights.
 * Both agree: at block 12, ConsensusVersion = V9.
 * Leo CLI uses CLI_CONSENSUS_HEIGHTS (14 heights): all 14 devnode heights.
 *
 * WASM SDK Compatibility Note
 * ===========================
 * The @provablehq/sdk@0.9.16 WASM parser does not support all AVM V9 syntax.
 * The following patterns cause parse failures:
 *   - Struct field access in mapping operands (e.g. mapping[r5.field])
 *   - Cross-program type arrays as function parameters ([pkg.aleo/Type; N])
 *   - call.dynamic instruction
 *
 * Workarounds applied:
 *   - credits_clone: inline simplified source (transfer/record ops only, no staking)
 *   - freezelist_program: inline simplified source (no verify_non_inclusion_priv)
 *   - stablecoin_program: inline simplified source (no MerkleProof-param functions)
 *   - wrappers: SDK-deployed at V9 (SDK_CONSENSUS_HEIGHTS keeps SDK at V9;
 *     leo 3.4.0 cannot parse the `interface` keyword in wrapper Leo source)
 *   - direct_dispatcher, wrapper_dispatcher: deployed via leo CLI subprocess
 *     (leo deploy --save --skip-deploy-certificate)
 *
 * Programs deployed (in dependency order)
 * ========================================
 *   merkle_tree, multisig_core, credits_clone*, freezelist_program*,
 *   token_registry, stablecoin_program*, token_interface,
 *   credits_wrapper, registry_wrapper, stablecoin_wrapper,
 *   fixed_registry_wrapper, direct_dispatcher**, wrapper_dispatcher**
 *
 *   * simplified test-only source (omits V9-incompatible functions)
 *   ** deployed via leo CLI (call.dynamic not parseable by WASM SDK)
 *
 * Key scenarios tested
 * ====================
 *  token_registry:          initialize, register_token, mint_public, transfer_public
 *  fixed_registry_wrapper:  mint_public, transfer_public,
 *                           transfer_public_to_private (vault-in),
 *                           join, split, transfer_private,
 *                           transfer_private_to_public (vault-out),
 *                           mint_private
 *  registry_wrapper:        transfer_public, transfer_public_to_private,
 *                           transfer_private_to_public
 *  wrapper_dispatcher:      register_route, transfer_public (dispatched)
 *  direct_dispatcher:       register_route
 */

import { readFileSync, readdirSync, mkdtempSync, mkdirSync, writeFileSync, copyFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { spawnSync } from "child_process";
import {
  Account,
  AleoNetworkClient,
  NetworkRecordProvider,
  ProgramManager,
  initThreadPool,
  getOrInitConsensusVersionTestHeights,
} from "@provablehq/sdk";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const DEVNODE_URL = "http://localhost:3030";

// Leo devnet genesis private key — pre-funded in the genesis block.
const PRIVATE_KEY = "APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH";
const ACCOUNT     = new Account({ privateKey: PRIVATE_KEY });
const ADDRESS     = ACCOUNT.address().to_string();

// A second account for transfer recipients.
// Generated fresh each run (we only need the address, not the key).
const RECIPIENT_ACCOUNT = new Account();
const RECIPIENT_ADDRESS = RECIPIENT_ACCOUNT.address().to_string();

// Token parameters.
// TOKEN_ID = 1field matches HARDCODED_TOKEN_ID in fixed_registry_wrapper.aleo.
const TOKEN_ID       = "1field";
const TOKEN_NAME     = "84117u128";     // "TEST" ASCII-packed little-endian into u128
const TOKEN_SYMBOL   = "84117u128";
const TOKEN_DECIMALS = "6u8";
const TOKEN_MAX      = "1000000000000000u128";  // 1 billion with 6 decimal places

// Root of the programs directory, relative to this file.
const __dir       = dirname(fileURLToPath(import.meta.url));
const PROGRAMS_DIR = join(__dir, "..", "programs");

// Leo CLI path for CLI-based deployments.
const LEO_CLI = "/Users/pranav/work/Aleo/leo/target/release/leo";

// Consensus heights for the SDK WASM (12 heights for testnet WASM with 12 versions).
// The first 9 entries match the devnode heights (V9 activates at block 12).
// V10-V12 activation heights are set to a large value so the SDK never advances
// past V9 for our test block range. This ensures the SDK builds V9-format
// deployment transactions (with program_checksum + program_owner + num_functions VKs)
// which the devnode (snarkVM b0dd5c5) accepts at any consensus version.
const SDK_CONSENSUS_HEIGHTS = "0,5,6,7,8,9,10,11,12,9999999,9999999,9999999";

// Consensus heights for leo CLI (14 heights matching snarkVM b0dd5c5 exactly).
// load_test_consensus_heights_inner panics if count != NUM_CONSENSUS_VERSIONS (14).
const CLI_CONSENSUS_HEIGHTS = "0,5,6,7,8,9,10,11,12,13,14,15,16,17";

// ---------------------------------------------------------------------------
// Simplified program sources
// ---------------------------------------------------------------------------
// The SDK WASM v0.9.16 cannot parse certain AVM V9 syntax. We provide
// simplified versions of three programs that:
//   1. Keep the same program name (so imports work).
//   2. Keep all mappings (for cross-program reads).
//   3. Expose the same functions called by wrappers.
//   4. Omit functions that use unsupported syntax.
// ---------------------------------------------------------------------------

/**
 * credits_clone.aleo — simplified (no staking functions).
 *
 * Full program uses `mapping[r5.field]` (struct field as mapping key) in
 * staking functions (bond_validator, unbond_public, etc.), which the WASM
 * parser doesn't support. Transfer functions are unchanged.
 */
const CREDITS_CLONE_SIMPLIFIED = `\
program credits_clone.aleo;

record credits:
    owner as address.private;
    microcredits as u64.private;

mapping account:
    key as address.public;
    value as u64.public;

function transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    async transfer_public self.caller r1 r0 into r2;
    output r2 as credits_clone.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as address.public;
    get account[r0] into r3;
    sub r3 r1 into r4;
    set r4 into account[r0];
    get.or_use account[r2] 0u64 into r5;
    add r5 r1 into r6;
    set r6 into account[r2];

function transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u64.public;
    async transfer_public_as_signer self.signer r1 r0 into r2;
    output r2 as credits_clone.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as address.public;
    get account[r0] into r3;
    sub r3 r1 into r4;
    set r4 into account[r0];
    get.or_use account[r2] 0u64 into r5;
    add r5 r1 into r6;
    set r6 into account[r2];

function transfer_private:
    input r0 as credits.record;
    input r1 as address.private;
    input r2 as u64.private;
    cast r1 r2 into r3 as credits.record;
    sub r0.microcredits r2 into r4;
    cast r0.owner r4 into r5 as credits.record;
    output r3 as credits.record;
    output r5 as credits.record;

function transfer_private_to_public:
    input r0 as credits.record;
    input r1 as address.public;
    input r2 as u64.public;
    sub r0.microcredits r2 into r3;
    cast r0.owner r3 into r4 as credits.record;
    async transfer_private_to_public r1 r2 into r5;
    output r4 as credits.record;
    output r5 as credits_clone.aleo/transfer_private_to_public.future;

finalize transfer_private_to_public:
    input r0 as address.public;
    input r1 as u64.public;
    get.or_use account[r0] 0u64 into r2;
    add r2 r1 into r3;
    set r3 into account[r0];

function transfer_public_to_private:
    input r0 as address.private;
    input r1 as u64.public;
    cast r0 r1 into r2 as credits.record;
    async transfer_public_to_private self.caller r1 into r3;
    output r2 as credits.record;
    output r3 as credits_clone.aleo/transfer_public_to_private.future;

finalize transfer_public_to_private:
    input r0 as address.public;
    input r1 as u64.public;
    get account[r0] into r2;
    sub r2 r1 into r3;
    set r3 into account[r0];

function join:
    input r0 as credits.record;
    input r1 as credits.record;
    add r0.microcredits r1.microcredits into r2;
    cast r0.owner r2 into r3 as credits.record;
    output r3 as credits.record;

function split:
    input r0 as credits.record;
    input r1 as u64.private;
    cast r0.owner r1 into r2 as credits.record;
    sub r0.microcredits r1 into r3;
    sub r3 10000u64 into r4;
    cast r0.owner r4 into r5 as credits.record;
    output r2 as credits.record;
    output r5 as credits.record;

constructor:
    assert.eq edition 0u16;
`;

/**
 * freezelist_program.aleo — simplified (no Merkle proof functions, no constructor).
 *
 * Full program uses [merkle_tree.aleo/MerkleProof; 2u32] in verify_non_inclusion_priv,
 * which the WASM parser doesn't support. All mappings are preserved (stablecoin_program
 * reads them via cross-program mapping reads).
 */
const FREEZELIST_SIMPLIFIED = `\
program freezelist_program.aleo;

mapping address_to_role:
    key as address.public;
    value as u16.public;

mapping freeze_list:
    key as address.public;
    value as boolean.public;

mapping freeze_list_index:
    key as u32.public;
    value as address.public;

mapping freeze_list_last_index:
    key as boolean.public;
    value as u32.public;

mapping freeze_list_root:
    key as u8.public;
    value as field.public;

mapping root_updated_height:
    key as boolean.public;
    value as u32.public;

mapping block_height_window:
    key as boolean.public;
    value as u32.public;

function initialize:
    input r0 as address.public;
    input r1 as u32.public;
    async initialize self.caller r0 r1 into r2;
    output r2 as freezelist_program.aleo/initialize.future;

finalize initialize:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u32.public;
    contains freeze_list_root[1u8] into r3;
    assert.eq r3 false;
    assert.eq r0 aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    set 8u16 into address_to_role[r1];
    set r2 into block_height_window[true];
    set 0u32 into freeze_list_last_index[true];
    set 3642222252059314292809609689035560016959342421640560347114299934615987159853field into freeze_list_root[1u8];
    set false into freeze_list[aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc];
    set aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into freeze_list_index[0u32];

function update_role:
    input r0 as address.public;
    input r1 as u16.private;
    async update_role self.caller r0 r1 into r2;
    output r2 as freezelist_program.aleo/update_role.future;

finalize update_role:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u16.public;
    get address_to_role[r0] into r3;
    and r3 8u16 into r4;
    is.eq r4 8u16 into r5;
    assert.eq r5 true;
    is.eq r0 r1 into r6;
    branch.eq r6 false to end_then_0_52;
    and r2 8u16 into r7;
    is.eq r7 8u16 into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_53;
    position end_then_0_52;
    position end_otherwise_0_53;
    set r2 into address_to_role[r1];

function update_block_height_window:
    input r0 as u32.public;
    async update_block_height_window self.caller r0 into r1;
    output r1 as freezelist_program.aleo/update_block_height_window.future;

finalize update_block_height_window:
    input r0 as address.public;
    input r1 as u32.public;
    get address_to_role[r0] into r2;
    and r2 16u16 into r3;
    is.eq r3 16u16 into r4;
    assert.eq r4 true;
    set r1 into block_height_window[true];

function update_freeze_list:
    input r0 as address.public;
    input r1 as boolean.public;
    input r2 as u32.public;
    input r3 as field.public;
    input r4 as field.public;
    async update_freeze_list self.caller r3 r4 r0 r1 r2 into r5;
    output r5 as freezelist_program.aleo/update_freeze_list.future;

finalize update_freeze_list:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as address.public;
    input r4 as boolean.public;
    input r5 as u32.public;
    get address_to_role[r0] into r6;
    and r6 16u16 into r7;
    is.eq r7 16u16 into r8;
    assert.eq r8 true;
    get freeze_list_root[1u8] into r9;
    assert.eq r1 r9;
    set r9 into freeze_list_root[2u8];
    set r2 into freeze_list_root[1u8];
    get.or_use freeze_list[r3] false into r10;
    assert.neq r4 r10;
    set r4 into freeze_list[r3];
    get.or_use freeze_list_index[r5] aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r11;
    branch.eq r4 false to end_then_0_54;
    assert.eq r11 aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    get freeze_list_last_index[true] into r12;
    add r12 1u32 into r13;
    gte r13 r5 into r14;
    assert.eq r14 true;
    lt r12 r5 into r15;
    branch.eq r15 false to end_then_1_56;
    set r5 into freeze_list_last_index[true];
    branch.eq true true to end_otherwise_1_57;
    position end_then_1_56;
    position end_otherwise_1_57;
    set r3 into freeze_list_index[r5];
    branch.eq true true to end_otherwise_0_55;
    position end_then_0_54;
    assert.eq r11 r3;
    set aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into freeze_list_index[r5];
    position end_otherwise_0_55;
    set block.height into root_updated_height[true];

function verify_non_inclusion_pub:
    input r0 as address.public;
    async verify_non_inclusion_pub r0 into r1;
    output r1 as freezelist_program.aleo/verify_non_inclusion_pub.future;

finalize verify_non_inclusion_pub:
    input r0 as address.public;
    get.or_use freeze_list[r0] false into r1;
    assert.eq r1 false;

constructor:
    assert.eq edition 0u16;
`;

/**
 * stablecoin_program.aleo — simplified (no MerkleProof-param functions, no constructor).
 *
 * Full program uses [merkle_tree.aleo/MerkleProof; 2u32] in get_credentials,
 * transfer_private, and transfer_private_to_public. Those are omitted.
 * All public transfer functions used by stablecoin_wrapper are preserved.
 */
const STABLECOIN_SIMPLIFIED = `\
import freezelist_program.aleo;
program stablecoin_program.aleo;

record Token:
    owner as address.private;
    amount as u128.private;

record ComplianceRecord:
    owner as address.private;
    amount as u128.private;
    sender as address.private;
    recipient as address.private;

record Credentials:
    owner as address.private;
    freeze_list_root as field.private;

struct TokenInfo:
    name as u128;
    symbol as u128;
    decimals as u8;
    supply as u128;
    max_supply as u128;

struct TokenAllowance:
    account as address;
    spender as address;

mapping token_info:
    key as boolean.public;
    value as TokenInfo.public;

mapping balances:
    key as address.public;
    value as u128.public;

mapping allowances:
    key as field.public;
    value as u128.public;

mapping address_to_role:
    key as address.public;
    value as u16.public;

mapping pause:
    key as boolean.public;
    value as boolean.public;

function update_role:
    input r0 as address.public;
    input r1 as u16.private;
    async update_role self.caller r0 r1 into r2;
    output r2 as stablecoin_program.aleo/update_role.future;

finalize update_role:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u16.public;
    get address_to_role[r0] into r3;
    and r3 8u16 into r4;
    is.eq r4 8u16 into r5;
    assert.eq r5 true;
    is.eq r0 r1 into r6;
    branch.eq r6 false to end_then_0_62;
    and r2 8u16 into r7;
    is.eq r7 8u16 into r8;
    assert.eq r8 true;
    branch.eq true true to end_otherwise_0_63;
    position end_then_0_62;
    position end_otherwise_0_63;
    set r2 into address_to_role[r1];

function initialize:
    input r0 as u128.public;
    input r1 as u128.public;
    input r2 as u8.public;
    input r3 as u128.public;
    input r4 as address.public;
    async initialize self.caller r4 r0 r1 r2 r3 into r5;
    output r5 as stablecoin_program.aleo/initialize.future;

finalize initialize:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    input r3 as u128.public;
    input r4 as u8.public;
    input r5 as u128.public;
    contains token_info[true] into r6;
    assert.eq r6 false;
    assert.eq r0 aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    set 8u16 into address_to_role[r1];
    cast r2 r3 r4 0u128 r5 into r7 as TokenInfo;
    set r7 into token_info[true];
    set false into pause[true];

function mint_public:
    input r0 as address.public;
    input r1 as u128.public;
    async mint_public self.caller r1 r0 into r2;
    output r2 as stablecoin_program.aleo/mint_public.future;

finalize mint_public:
    input r0 as address.public;
    input r1 as u128.public;
    input r2 as address.public;
    get address_to_role[r0] into r3;
    and r3 1u16 into r4;
    is.eq r4 1u16 into r5;
    assert.eq r5 true;
    get pause[true] into r6;
    assert.eq r6 false;
    get token_info[true] into r7;
    add r7.supply r1 into r8;
    lte r8 r7.max_supply into r9;
    assert.eq r9 true;
    get.or_use balances[r2] 0u128 into r10;
    add r1 r10 into r11;
    set r11 into balances[r2];
    cast r7.name r7.symbol r7.decimals r8 r7.max_supply into r12 as TokenInfo;
    set r12 into token_info[true];

function transfer_public:
    input r0 as address.public;
    input r1 as u128.public;
    async transfer_public self.caller r0 r1 into r2;
    output r2 as stablecoin_program.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r3;
    assert.eq r3 false;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r4;
    assert.eq r4 false;
    get pause[true] into r5;
    assert.eq r5 false;
    get balances[r0] into r6;
    sub r6 r2 into r7;
    set r7 into balances[r0];
    get.or_use balances[r1] 0u128 into r8;
    add r8 r2 into r9;
    set r9 into balances[r1];

function transfer_public_as_signer:
    input r0 as address.public;
    input r1 as u128.public;
    async transfer_public_as_signer self.signer r0 r1 into r2;
    output r2 as stablecoin_program.aleo/transfer_public_as_signer.future;

finalize transfer_public_as_signer:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u128.public;
    get.or_use freezelist_program.aleo/freeze_list[r0] false into r3;
    assert.eq r3 false;
    get.or_use freezelist_program.aleo/freeze_list[r1] false into r4;
    assert.eq r4 false;
    get pause[true] into r5;
    assert.eq r5 false;
    get balances[r0] into r6;
    sub r6 r2 into r7;
    set r7 into balances[r0];
    get.or_use balances[r1] 0u128 into r8;
    add r8 r2 into r9;
    set r9 into balances[r1];

function set_pause_status:
    input r0 as boolean.private;
    async set_pause_status self.caller r0 into r1;
    output r1 as stablecoin_program.aleo/set_pause_status.future;

finalize set_pause_status:
    input r0 as address.public;
    input r1 as boolean.public;
    get address_to_role[r0] into r2;
    and r2 4u16 into r3;
    is.eq r3 4u16 into r4;
    assert.eq r4 true;
    set r1 into pause[true];

constructor:
    assert.eq edition 0u16;
`;

// ---------------------------------------------------------------------------
// Program loader and field encoding utilities
// ---------------------------------------------------------------------------

/** Read the compiled .aleo source from a program's build directory. */
function readProgram(relPath) {
  return readFileSync(join(PROGRAMS_DIR, relPath, "build", "main.aleo"), "utf8");
}

/**
 * Encode a string as a Leo field literal using little-endian byte packing.
 *
 * This is how Aleo represents program names and function names as field elements.
 * Each character's ASCII byte value is packed little-endian (byte[0] is the least
 * significant). The result is the decimal representation followed by "field".
 *
 * Examples (matches constants in wrapper_dispatcher.aleo):
 *   programNameToField("aleo")            → "1868917857field"     (NETWORK_ALEO)
 *   programNameToField("transfer_public") → "516175629116388850284097790795674228field"
 *
 * @param {string} name - program name (e.g. "fixed_registry_wrapper.aleo") or function name
 * @returns {string} Leo field literal string, e.g. "12345field"
 */
function programNameToField(name) {
  const bytes = Buffer.from(name, "utf8");
  let result = 0n;
  for (let i = 0; i < bytes.length; i++) {
    result += BigInt(bytes[i]) * (256n ** BigInt(i));
  }
  return result.toString() + "field";
}

// Precomputed program ID fields (used as `program_id` parameters in dispatchers).
const PROGRAM_ID = {
  fixed_registry_wrapper: programNameToField("fixed_registry_wrapper.aleo"),
  registry_wrapper:       programNameToField("registry_wrapper.aleo"),
  token_registry:         programNameToField("token_registry.aleo"),
};

const src = {
  // ── SDK-deployed (4 slots, blocks 13–16, one per block) ──────────────────
  // snarkVM limits to 1 public-fee deployment per fee payer per block.
  // SDK generates V9-format transactions (valid at blocks 12–16; rejected at 17+).

  // Block 13 (V10): merkle_tree — no deps, SDK-parseable AVM.
  merkle_tree:        readProgram("lib/merkle_tree"),
  // Block 14 (V11): credits_clone — simplified (staking fns removed, no imports).
  credits_clone:      CREDITS_CLONE_SIMPLIFIED,
  // Block 15 (V12): freezelist_program — simplified (MerkleProof fns removed, no imports).
  freezelist_program: FREEZELIST_SIMPLIFIED,
  // Block 16 (V13): stablecoin_program — simplified (MerkleProof fns removed).
  stablecoin_program: STABLECOIN_SIMPLIFIED,

  // ── Leo CLI-deployed (blocks 17+, V14-format VKs) ────────────────────────
  // Leo CLI (snarkVM b0dd5c5) generates V14-format deployment transactions.
  // Imports are resolved from the devnode (--endpoint flag).
  // Programs with `interface` Leo syntax require stripped temp-dir approach.

  // token_interface: interfaces stripped (Leo 3.4.0 can't parse `interface X {}`)
  token_interface_dir:        join(PROGRAMS_DIR, "wrappers/token_interface"),
  // token_registry: normal Leo source, no interface issues
  token_registry_dir:         join(PROGRAMS_DIR, "tokens/token_registry"),
  // multisig_core: normal Leo source, V11 syntax (accepted at V14)
  multisig_core_dir:          join(PROGRAMS_DIR, "lib/multisig_core"),
  // Wrappers: interface clause stripped (Leo 3.4.0 can't parse `: InterfaceName`)
  credits_wrapper_dir:        join(PROGRAMS_DIR, "wrappers/credits_wrapper"),
  registry_wrapper_dir:       join(PROGRAMS_DIR, "wrappers/registry_wrapper"),
  stablecoin_wrapper_dir:     join(PROGRAMS_DIR, "wrappers/stablecoin_wrapper"),
  fixed_registry_wrapper_dir: join(PROGRAMS_DIR, "wrappers/fixed_registry_wrapper"),
  // Dispatchers: dyn record not parseable by Leo 3.4.0 — expected fail
  direct_dispatcher_dir:  join(PROGRAMS_DIR, "dispatchers/direct_dispatcher"),
  wrapper_dispatcher_dir: join(PROGRAMS_DIR, "dispatchers/wrapper_dispatcher"),
};

// ---------------------------------------------------------------------------
// SDK setup
// ---------------------------------------------------------------------------

// initThreadPool enables multi-threaded WASM execution.
await initThreadPool();

// getOrInitConsensusVersionTestHeights must be called with the same heights list
// as the devnode's --consensus-heights flag. This configures the WASM layer to
// use the correct consensus version when building transactions.
// Must be called before any buildDevnode* method.
// The testnet SDK WASM requires exactly 12 heights.
// Heights: 0-10 increment by 1; last entry is large so version stays at 11
// once height exceeds 10. Version = count of entries ≤ current block height.
getOrInitConsensusVersionTestHeights(SDK_CONSENSUS_HEIGHTS);

const networkClient  = new AleoNetworkClient(DEVNODE_URL);
const recordProvider = new NetworkRecordProvider(ACCOUNT, networkClient);
const pm             = new ProgramManager(DEVNODE_URL, recordProvider);
pm.setAccount(ACCOUNT);

// ---------------------------------------------------------------------------
// Devnode helpers
// ---------------------------------------------------------------------------

// The SDK's AleoNetworkClient appends "/testnet" to the base URL automatically.
// Raw fetch calls must use the /testnet/ prefix explicitly.
const DEVNODE_API = `${DEVNODE_URL}/testnet`;

/** Advance the devnode by one block (required in --manual-block-creation mode). */
async function advanceBlock() {
  const res = await fetch(`${DEVNODE_API}/block/create`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ num_blocks: 1 }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`POST /testnet/block/create ${res.status}: ${body}`);
  }
}

/** Get the current block height. */
async function getHeight() {
  const res = await fetch(`${DEVNODE_API}/block/height/latest`);
  if (!res.ok) throw new Error(`GET /testnet/block/height/latest ${res.status}`);
  return parseInt(await res.text(), 10);
}

/** Poll until the devnode is ready. */
async function waitForDevnode(timeoutMs = 30_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try { await getHeight(); return; } catch { /* not ready */ }
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error("devnode not reachable after " + timeoutMs + "ms");
}

/** Fetch a transaction from the devnode by ID (as plain JSON). */
async function getTransaction(txId) {
  return pm.networkClient.getTransaction(txId);
}

/**
 * Decrypt record outputs from a transition that belong to `account`.
 * Returns plaintext record strings.
 *
 * @param {object} txData          - parsed transaction JSON
 * @param {Account} account        - owner account for decryption
 * @param {number} transitionIndex - which transition to inspect (default 0)
 */
function decryptRecordOutputs(txData, account, transitionIndex = 0) {
  const transitions = txData?.execution?.transitions ?? [];
  const transition  = transitions[transitionIndex];
  if (!transition) return [];

  return (transition.outputs ?? [])
    .filter(o => o.type === "record")
    .flatMap(o => {
      try {
        // decryptRecord throws if the record doesn't belong to this account.
        const plaintext = account.decryptRecord(o.value);
        // plaintext is a RecordPlaintext WASM object; toString() gives Leo format.
        return [plaintext.toString()];
      } catch {
        return []; // record belongs to a different account
      }
    });
}

// ---------------------------------------------------------------------------
// Deploy / execute helpers
// ---------------------------------------------------------------------------

/**
 * Build and submit a deployment transaction WITHOUT advancing the block.
 *
 * Used by `deploy` to submit and then advance exactly one block per program.
 * Returns null if already deployed, otherwise the transaction ID string.
 *
 * NOTE: SDK WASM generates V9-format transactions (valid at blocks 13–16).
 * At block 17+ (V14), the devnode rejects V9-format VKs. Use deployViaCLI
 * or deployWithStrippedInterfaces for programs deployed at block 17+.
 *
 * @param {string} programSource - compiled .aleo source
 * @returns {string|null} transaction ID, or null if already deployed
 */
async function deployNoAdvance(programSource) {
  let tx;
  try {
    tx = await pm.buildDevnodeDeploymentTransaction({
      program: programSource,
      priorityFee: 0,
      privateFee: false,
    });
  } catch (e) {
    if (String(e).includes("already exists on the network")) {
      return null;
    }
    throw e;
  }
  try {
    return await pm.networkClient.submitTransaction(tx);
  } catch (e) {
    if (String(e).includes("already exists on the network")) {
      return null;
    }
    throw e;
  }
}

/**
 * Deploy a single program and immediately advance the block.
 *
 * @param {string} programSource - compiled .aleo source
 * @returns {string|null} transaction ID
 */
async function deploy(programSource) {
  const txId = await deployNoAdvance(programSource);
  if (txId === null) {
    console.log("    (already deployed — skipping)");
    return null;
  }
  await advanceBlock();
  console.log(`    txid: ${txId}`);
  return txId;
}

/**
 * Build a deployment transaction via the Leo CLI and broadcast it WITHOUT
 * advancing the block. Returns null if already deployed, otherwise the txId.
 *
 * NOTE: snarkVM allows only 1 public-fee deployment per fee payer per block.
 * This function does NOT advance the block — callers must advance separately.
 *
 * @param {string} programDir - path to the Leo program directory
 * @param {string} programId  - e.g. "multisig_core.aleo"
 * @returns {string|null} transaction ID or null if already deployed
 */
async function deployViaCLINoAdvance(programDir, programId) {
  const tmpDir = mkdtempSync("/private/tmp/claude/arc0020_deploy_");
  const result = spawnSync(
    LEO_CLI,
    [
      "deploy",
      "--skip-deploy-certificate",
      "--save", tmpDir,
      "--devnet",
      "--network", "testnet",
      "--consensus-heights", CLI_CONSENSUS_HEIGHTS,
      "--endpoint", DEVNODE_URL,
      "--private-key", PRIVATE_KEY,
      "--yes",
      "--path", programDir,
    ],
    { timeout: 120_000, encoding: "utf8", cwd: programDir },
  );

  if (result.status !== 0) {
    const msg = result.stderr || result.stdout || "unknown error";
    if (msg.includes("already exists on the network") || msg.includes("already exists in the ledger")) {
      return null;
    }
    throw new Error(`leo deploy failed for ${programId}: ${msg.slice(0, 400)}`);
  }

  // Find the saved transaction JSON file.
  const files = readdirSync(tmpDir);
  const txFile = files.find(f => f.endsWith(".json"));
  if (!txFile) {
    throw new Error(`leo deploy --save produced no JSON in ${tmpDir}. stdout: ${result.stdout.slice(0, 400)}`);
  }
  const txJson = readFileSync(join(tmpDir, txFile), "utf8");

  // Broadcast to the devnode.
  const resp = await fetch(`${DEVNODE_API}/transaction/broadcast`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: txJson,
  });
  if (!resp.ok) {
    const body = await resp.text();
    if (body.includes("already exists on the network") || body.includes("already exists in the ledger") || body.includes("is already deployed")) {
      return null;
    }
    throw new Error(`broadcast failed for ${programId}: ${resp.status} ${body}`);
  }
  return await resp.json();
}

/**
 * Deploy a program via the Leo CLI and advance the block.
 *
 * Used for programs the WASM SDK cannot parse (e.g., those using call.dynamic).
 * Uses `leo deploy --save --skip-deploy-certificate` to build a deployment
 * transaction with placeholder certificates (no ZK proofs), saves the
 * transaction JSON, then broadcasts it manually and advances the block.
 *
 * @param {string} programDir - path to the Leo program directory (containing program.json)
 * @param {string} programId  - e.g. "wrapper_dispatcher.aleo"
 * @returns {string|null} transaction ID or null if already deployed
 */
async function deployViaCLI(programDir, programId) {
  const txId = await deployViaCLINoAdvance(programDir, programId);
  if (txId === null) {
    console.log("    (already deployed — skipping)");
    return null;
  }
  await advanceBlock();
  console.log(`    txid: ${txId}`);
  return txId;
}

/**
 * Deploy a Leo program from a TEMPORARY directory containing a Leo 3.4.0-compatible
 * version of the source code, then advance the block.
 *
 * Used for programs whose Leo source uses syntax unsupported by Leo 3.4.0
 * (specifically the `interface X {}` definition blocks and `: InterfaceName`
 * implementation clauses). A temp directory is created with the interface
 * syntax stripped. Leo can then compile and generate a V14-format deployment.
 *
 * Two transformations are applied to src/main.leo:
 *   1. `interface X : ... { ... }` blocks removed (for token_interface.aleo)
 *   2. `program X.aleo : InterfaceName {` → `program X.aleo {` (for wrappers)
 *
 * @param {string} programDir - original Leo program directory
 * @param {string} programId  - e.g. "credits_wrapper.aleo"
 * @returns {string|null} transaction ID or null if already deployed
 */
async function deployWithStrippedInterfaces(programDir, programId) {
  const tmpDir = mkdtempSync("/private/tmp/claude/arc0020_stripped_");
  mkdirSync(join(tmpDir, "src"), { recursive: true });

  // Read original Leo source and strip interface syntax.
  let leoSrc = readFileSync(join(programDir, "src", "main.leo"), "utf8");

  // Remove `interface X { ... }` definition blocks.
  // These blocks may span multiple lines and have nested content.
  // Strategy: collect lines, track brace depth, drop interface blocks.
  const outLines = [];
  let inInterface = false;
  let depth = 0;
  for (const line of leoSrc.split("\n")) {
    if (!inInterface && /^\s*interface\s+\w/.test(line)) {
      inInterface = true;
      depth = 0;
    }
    if (inInterface) {
      depth += (line.match(/\{/g) || []).length;
      depth -= (line.match(/\}/g) || []).length;
      if (depth <= 0) inInterface = false;
      continue; // drop interface lines
    }
    outLines.push(line);
  }
  leoSrc = outLines.join("\n");

  // Strip `: InterfaceName` (+ possible `+ InterfaceName` chains) from program declaration.
  leoSrc = leoSrc.replace(/^(program \S+\.aleo)\s*:[^{]+\{/m, "$1 {");

  writeFileSync(join(tmpDir, "src", "main.leo"), leoSrc);
  copyFileSync(join(programDir, "program.json"), join(tmpDir, "program.json"));

  // Run leo deploy from the temp dir. Leo resolves imports from the devnode.
  const result = spawnSync(
    LEO_CLI,
    [
      "deploy",
      "--skip-deploy-certificate",
      "--save", tmpDir,
      "--devnet",
      "--network", "testnet",
      "--consensus-heights", CLI_CONSENSUS_HEIGHTS,
      "--endpoint", DEVNODE_URL,
      "--private-key", PRIVATE_KEY,
      "--yes",
      "--path", tmpDir,
    ],
    { timeout: 120_000, encoding: "utf8", cwd: tmpDir },
  );

  if (result.status !== 0) {
    const msg = result.stderr || result.stdout || "unknown error";
    if (msg.includes("already exists on the network") || msg.includes("already exists in the ledger")) {
      return null;
    }
    throw new Error(`leo deploy (stripped) failed for ${programId}: ${msg.slice(0, 500)}`);
  }

  const files = readdirSync(tmpDir);
  const txFile = files.find(f => f.endsWith(".json") && f !== "program.json");
  if (!txFile) {
    throw new Error(`leo deploy --save produced no TX JSON in ${tmpDir}. stdout: ${result.stdout.slice(0, 400)}`);
  }
  const txJson = readFileSync(join(tmpDir, txFile), "utf8");

  const resp = await fetch(`${DEVNODE_API}/transaction/broadcast`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: txJson,
  });
  if (!resp.ok) {
    const body = await resp.text();
    if (body.includes("already exists on the network") || body.includes("already exists in the ledger") || body.includes("is already deployed")) {
      console.log("    (already deployed — skipping)");
      return null;
    }
    throw new Error(`broadcast failed for ${programId}: ${resp.status} ${body}`);
  }
  const txId = await resp.json();
  await advanceBlock();
  console.log(`    txid: ${txId}`);
  return txId;
}

/**
 * Execute a program function on the devnode with a dummy proof.
 *
 * Skips real proof generation (skipProof: true), making execution nearly
 * instantaneous compared to real proof generation (~minutes).
 *
 * @param {string}   programName  - e.g. "token_registry.aleo"
 * @param {string}   functionName - e.g. "mint_public"
 * @param {string[]} inputs       - Leo literal strings for each parameter
 * @returns {{ txId: string, txData: object }}
 */
async function execute(programName, functionName, inputs) {
  const tx = await pm.buildDevnodeExecutionTransaction({
    privateKey:  ACCOUNT.privateKey(),
    programName,
    functionName,
    privateFee:  false,
    inputs,
    priorityFee: 0,
  });
  const txId   = await pm.networkClient.submitTransaction(tx);
  await advanceBlock();
  const txData = await getTransaction(txId);
  console.log(`    ${programName}/${functionName} → ${txId}`);
  return { txId, txData };
}

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

async function runTests() {
  let passed = 0, failed = 0;
  for (const { name, fn } of tests) {
    process.stdout.write(`\n[ ${name} ]\n`);
    try {
      await fn();
      console.log("  ✓ pass");
      passed++;
    } catch (err) {
      console.error(`  ✗ FAIL: ${err.message ?? err}`);
      failed++;
    }
  }
  console.log("\n" + "─".repeat(60));
  console.log(`${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

// Shared state: records captured from transaction outputs.
const captured = {
  fixedWrapperToken1: null,   // from vault-in #1 (200_000)
  fixedWrapperToken2: null,   // from vault-in #2 (100_000)
  registryWrapperToken: null, // from registry_wrapper vault-in
};

// ---------------------------------------------------------------------------
// Tests: 1 — Connectivity + V9 block advance
// ---------------------------------------------------------------------------

test("devnode is reachable", async () => {
  await waitForDevnode(20_000);
  const h = await getHeight();
  console.log(`  height: ${h}`);
});

test("advance to ConsensusVersion V9 (block 12)", async () => {
  // ConsensusVersion = count of activation heights <= current block height.
  // Devnode compiled-in TEST_CONSENSUS_VERSION_HEIGHTS (snarkVM b0dd5c5):
  //   V1@0, V2@5, V3@6, V4@7, V5@8, V6@9, V7@10, V8@11, V9@12, ...
  // At block 12: heights ≤ 12 = [0,5,6,7,8,9,10,11,12] = 9 entries = V9.
  // SDK_CONSENSUS_HEIGHTS aligned: same 9 entries → SDK also sees V9 at block 12. ✓
  const current = await getHeight();
  const target  = 12;
  const needed  = Math.max(0, target - current);
  console.log(`  current height: ${current}, advancing ${needed} blocks to reach block ${target}`);
  for (let i = 0; i < needed; i++) {
    await advanceBlock();
  }
  const after = await getHeight();
  console.log(`  height after advance: ${after}`);
  if (after < target) throw new Error(`height ${after} < ${target} required for V9`);
});

// ---------------------------------------------------------------------------
// Tests: 2 — Deploy all programs
// ---------------------------------------------------------------------------
//
// Block height timeline (TEST_CONSENSUS_VERSION_HEIGHTS in snarkVM b0dd5c5):
//   block 12 = V9  (constructor required for new deployments)
//   block 13 = V10
//   block 14 = V11
//   block 15 = V12
//   block 16 = V13
//   block 17 = V14 (V14-format VKs required — SDK V9-format REJECTED)
//
// Deployment order:
//   Blocks 13–16 (SDK, V9-format):
//     merkle_tree → credits_clone → freezelist_program → stablecoin_program
//   Blocks 17+ (Leo CLI, V14-format):
//     token_interface, token_registry, multisig_core,
//     credits_wrapper, registry_wrapper, stablecoin_wrapper, fixed_registry_wrapper,
//     direct_dispatcher (fail), wrapper_dispatcher (fail)
//
// KEY CONSTRAINT: snarkVM allows only 1 public-fee deployment per fee payer per
// block. Trying to deploy multiple programs in one block causes all but the first
// to be ABORTED ("Another deployment in the block from the same public fee payer").
//
// IMPORTANT: Leo CLI generates V14-format VKs (valid at any block height).
//   - Normal programs: deployed from their source dir directly.
//   - Programs with Leo `interface` syntax (unsupported in leo 3.4.0): deployed
//     via deployWithStrippedInterfaces() which strips interface syntax to a
//     temp dir and lets Leo recompile. The AVM output is functionally identical.
//
// FRESH DEVNODE REQUIRED: On a dirty devnode, already-deployed programs are
// skipped, but if some are missing they'll attempt deployment. Leo CLI deploys
// work at any block height (V14-format). SDK deploys at block 17+ (V14) fail.
// For a fully clean run: `npm run devnode:clean` then `npm run devnode`.

// SDK slot 1 — block 13 (V10): merkle_tree (no imports, clean AVM)
test("deploy merkle_tree.aleo", async () => { await deploy(src.merkle_tree); });

// SDK slot 2 — block 14 (V11): credits_clone simplified (no imports)
test("deploy credits_clone.aleo (simplified)", async () => { await deploy(src.credits_clone); });

// SDK slot 3 — block 15 (V12): freezelist_program simplified (no imports)
test("deploy freezelist_program.aleo (simplified)", async () => { await deploy(src.freezelist_program); });

// SDK slot 4 — block 16 (V13): stablecoin_program simplified (imports freezelist @ block 15)
test("deploy stablecoin_program.aleo (simplified)", async () => { await deploy(src.stablecoin_program); });

// Leo CLI — block 17+ (V14-format):

// token_interface: has `interface X {}` definitions (Leo 3.4.0 unsupported).
// deployWithStrippedInterfaces strips interface blocks → empty program body.
test("deploy token_interface.aleo (via leo CLI, stripped)", async () => {
  await deployWithStrippedInterfaces(src.token_interface_dir, "token_interface.aleo");
});

// token_registry: normal Leo source, no interface issues.
test("deploy token_registry.aleo (via leo CLI)", async () => {
  await deployViaCLI(src.token_registry_dir, "token_registry.aleo");
});

// multisig_core: no imports, V11 syntax (accepted at V14).
test("deploy multisig_core.aleo (via leo CLI)", async () => {
  await deployViaCLI(src.multisig_core_dir, "multisig_core.aleo");
});

// Wrappers: `: token_interface.aleo/InterfaceName` stripped for Leo 3.4.0.
// Imports (credits_clone, token_registry, etc.) resolved from devnode.
test("deploy credits_wrapper.aleo (via leo CLI, stripped)", async () => {
  await deployWithStrippedInterfaces(src.credits_wrapper_dir, "credits_wrapper.aleo");
});
test("deploy registry_wrapper.aleo (via leo CLI, stripped)", async () => {
  await deployWithStrippedInterfaces(src.registry_wrapper_dir, "registry_wrapper.aleo");
});
test("deploy stablecoin_wrapper.aleo (via leo CLI, stripped)", async () => {
  await deployWithStrippedInterfaces(src.stablecoin_wrapper_dir, "stablecoin_wrapper.aleo");
});
test("deploy fixed_registry_wrapper.aleo (via leo CLI, stripped)", async () => {
  await deployWithStrippedInterfaces(src.fixed_registry_wrapper_dir, "fixed_registry_wrapper.aleo");
});

// Dispatchers: `dyn record` not parseable by Leo 3.4.0 — expected fail.
test("deploy direct_dispatcher.aleo (via leo CLI)", async () => {
  await deployViaCLI(src.direct_dispatcher_dir, "direct_dispatcher.aleo");
});
test("deploy wrapper_dispatcher.aleo (via leo CLI)", async () => {
  await deployViaCLI(src.wrapper_dispatcher_dir, "wrapper_dispatcher.aleo");
});

// ---------------------------------------------------------------------------
// Tests: 3 — token_registry bootstrap
// ---------------------------------------------------------------------------

test("token_registry/initialize", async () => {
  await execute("token_registry.aleo", "initialize", []);
});

test("token_registry/register_token (token_id=1field)", async () => {
  // register_token(token_id, name, symbol, decimals, max_supply,
  //                external_authorization_required, external_authorization_party)
  await execute("token_registry.aleo", "register_token", [
    TOKEN_ID, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, TOKEN_MAX,
    "false",  // no external authorization
    ADDRESS,  // external_authorization_party (unused when false)
  ]);
});

test("token_registry/mint_public (1_000_000 to deployer)", async () => {
  // mint_public(token_id, recipient, amount, authorized_until)
  await execute("token_registry.aleo", "mint_public", [
    TOKEN_ID, ADDRESS, "1000000u128", "0u32",
  ]);
});

test("token_registry/transfer_public (500_000 deployer → recipient)", async () => {
  // transfer_public(token_id, recipient, amount)
  await execute("token_registry.aleo", "transfer_public", [
    TOKEN_ID, RECIPIENT_ADDRESS, "500000u128",
  ]);
});

// ---------------------------------------------------------------------------
// Tests: 4 — fixed_registry_wrapper: public operations
//   Delegates directly to token_registry; no vault involvement.
//   token_id = HARDCODED_TOKEN_ID = 1field (baked in at compile time).
// ---------------------------------------------------------------------------

test("fixed_registry_wrapper/mint_public (1_000_000 to deployer)", async () => {
  // mint_public(recipient, amount) — HARDCODED_TOKEN_ID used internally.
  // Deployer is admin of TOKEN_ID from the register_token step.
  await execute("fixed_registry_wrapper.aleo", "mint_public", [
    ADDRESS, "1000000u128",
  ]);
});

test("fixed_registry_wrapper/transfer_public (100_000 deployer → recipient)", async () => {
  // transfer_public(token_id, recipient, amount)
  // token_id must equal HARDCODED_TOKEN_ID = 1field.
  await execute("fixed_registry_wrapper.aleo", "transfer_public", [
    TOKEN_ID, RECIPIENT_ADDRESS, "100000u128",
  ]);
});

// ---------------------------------------------------------------------------
// Tests: 5 — fixed_registry_wrapper: vault-in
//   transfer_public_to_private debits the signer's public registry balance
//   and creates a wrapper Token record for the specified recipient.
//   The wrapper's registry balance increases by `amount` (vault invariant).
// ---------------------------------------------------------------------------

test("fixed_registry_wrapper/transfer_public_to_private 200_000 (vault-in #1)", async () => {
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "transfer_public_to_private",
    [TOKEN_ID, ADDRESS, "200000u128"],
  );
  // Capture the Token record for subsequent join/split/transfer_private tests.
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no record output decryptable");
  captured.fixedWrapperToken1 = records[0];
  console.log(`  captured: ${records[0].slice(0, 80)}...`);
});

test("fixed_registry_wrapper/transfer_public_to_private 100_000 (vault-in #2)", async () => {
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "transfer_public_to_private",
    [TOKEN_ID, ADDRESS, "100000u128"],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no record output decryptable");
  captured.fixedWrapperToken2 = records[0];
  console.log(`  captured: ${records[0].slice(0, 80)}...`);
});

// ---------------------------------------------------------------------------
// Tests: 6 — fixed_registry_wrapper: local record operations
//   join, split, transfer_private contain no finalize block — they are pure
//   record transformations executed in the AVM with dummy proofs.
// ---------------------------------------------------------------------------

test("fixed_registry_wrapper/join (200_000 + 100_000 = 300_000)", async () => {
  if (!captured.fixedWrapperToken1) throw new Error("requires vault-in #1");
  if (!captured.fixedWrapperToken2) throw new Error("requires vault-in #2");
  // join(r1: Token, r2: Token) -> Token
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "join",
    [captured.fixedWrapperToken1, captured.fixedWrapperToken2],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no joined record output");
  captured.fixedWrapperToken1 = records[0]; // 300_000
  console.log(`  joined (300_000): ${records[0].slice(0, 80)}...`);
});

test("fixed_registry_wrapper/split 300_000 → 120_000 + 180_000", async () => {
  if (!captured.fixedWrapperToken1) throw new Error("requires joined record");
  // split(input: Token, amount: u128) -> (Token, Token)
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "split",
    [captured.fixedWrapperToken1, "120000u128"],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length < 2) throw new Error(`expected 2 outputs, got ${records.length}`);
  captured.fixedWrapperToken1 = records[0]; // 120_000
  captured.fixedWrapperToken2 = records[1]; // 180_000
  console.log(`  split[0] (120_000): ${records[0].slice(0, 80)}...`);
  console.log(`  split[1] (180_000): ${records[1].slice(0, 80)}...`);
});

test("fixed_registry_wrapper/transfer_private (30_000 to recipient)", async () => {
  if (!captured.fixedWrapperToken1) throw new Error("requires split record");
  // transfer_private(recipient: address, amount: u128, input: Token)
  //   → (change: Token, out: Token, Final)
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "transfer_private",
    [RECIPIENT_ADDRESS, "30000u128", captured.fixedWrapperToken1],
  );
  // Only the sender's change record can be decrypted with ACCOUNT.viewKey().
  const records = decryptRecordOutputs(txData, ACCOUNT);
  console.log(`  sender change records decryptable: ${records.length}`);
  if (records.length > 0) {
    captured.fixedWrapperToken1 = records[0]; // change record (90_000)
    console.log(`  change (90_000): ${records[0].slice(0, 80)}...`);
  }
});

// ---------------------------------------------------------------------------
// Tests: 7 — fixed_registry_wrapper: vault-out
//   transfer_private_to_public consumes a Token record, releases the
//   wrapper's registry balance to the recipient.
//   Vault invariant: wrapper's registry balance decreases by `amount`.
// ---------------------------------------------------------------------------

test("fixed_registry_wrapper/transfer_private_to_public vault-out (50_000 to recipient)", async () => {
  if (!captured.fixedWrapperToken1) throw new Error("requires Token record");
  // transfer_private_to_public(recipient: address, amount: u128, input: Token)
  //   → (change: Token, Final)
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "transfer_private_to_public",
    [RECIPIENT_ADDRESS, "50000u128", captured.fixedWrapperToken1],
  );
  // Change record for sender.
  const records = decryptRecordOutputs(txData, ACCOUNT);
  console.log(`  change records: ${records.length}`);
  if (records.length > 0) {
    console.log(`  change: ${records[0].slice(0, 80)}...`);
  }
});

// ---------------------------------------------------------------------------
// Tests: 8 — fixed_registry_wrapper: mint_private
//   Vault-in via minting: calls token_registry/mint_public with
//   self.address as recipient, then creates a private Token record.
// ---------------------------------------------------------------------------

test("fixed_registry_wrapper/mint_private (50_000 to deployer)", async () => {
  // mint_private(recipient: address, amount: u128) → (Token, Final)
  const { txData } = await execute(
    "fixed_registry_wrapper.aleo", "mint_private",
    [ADDRESS, "50000u128"],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no minted record decryptable");
  console.log(`  minted: ${records[0].slice(0, 80)}...`);
});

// ---------------------------------------------------------------------------
// Tests: 9 — registry_wrapper: public ops and vault cycle
//   registry_wrapper is a multi-token wrapper: token_id is explicit on all ops.
// ---------------------------------------------------------------------------

test("registry_wrapper/transfer_public (10_000 deployer → recipient)", async () => {
  await execute("registry_wrapper.aleo", "transfer_public", [
    TOKEN_ID, RECIPIENT_ADDRESS, "10000u128",
  ]);
});

test("registry_wrapper/transfer_public_to_private vault-in (50_000)", async () => {
  const { txData } = await execute(
    "registry_wrapper.aleo", "transfer_public_to_private",
    [TOKEN_ID, ADDRESS, "50000u128"],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no record from vault-in");
  captured.registryWrapperToken = records[0];
  console.log(`  captured: ${records[0].slice(0, 80)}...`);
});

test("registry_wrapper/join (need 2 records → run vault-in #2 first)", async () => {
  // Get a second record for join.
  const { txData } = await execute(
    "registry_wrapper.aleo", "transfer_public_to_private",
    [TOKEN_ID, ADDRESS, "30000u128"],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  if (records.length === 0) throw new Error("no record from second vault-in");
  const r2 = records[0];

  // join(r1: Token, r2: Token) -> Token
  const { txData: joinData } = await execute(
    "registry_wrapper.aleo", "join",
    [captured.registryWrapperToken, r2],
  );
  const joined = decryptRecordOutputs(joinData, ACCOUNT);
  if (joined.length === 0) throw new Error("no joined record");
  captured.registryWrapperToken = joined[0]; // 80_000
  console.log(`  joined (80_000): ${joined[0].slice(0, 80)}...`);
});

test("registry_wrapper/transfer_private_to_public vault-out (20_000 to recipient)", async () => {
  if (!captured.registryWrapperToken) throw new Error("requires Token record");
  const { txData } = await execute(
    "registry_wrapper.aleo", "transfer_private_to_public",
    [RECIPIENT_ADDRESS, "20000u128", captured.registryWrapperToken],
  );
  const records = decryptRecordOutputs(txData, ACCOUNT);
  console.log(`  change records: ${records.length}`);
});

// ---------------------------------------------------------------------------
// Tests: 10 — wrapper_dispatcher: on-chain routing
//   The dispatcher maps token_id → wrapper program address (as field).
//   register_route stores the mapping; transfer_public verifies and dispatches.
//
//   NOTE: wrapper program IDs as field values are computed from the program
//   name bytes packed little-endian. programNameToField() computes this.
// ---------------------------------------------------------------------------

test("wrapper_dispatcher/register_route (TOKEN_ID → fixed_registry_wrapper)", async () => {
  // program_id is the program name bytes packed little-endian into a field element.
  // programNameToField("fixed_registry_wrapper.aleo") computes this at runtime.
  await execute("wrapper_dispatcher.aleo", "register_route", [
    TOKEN_ID, PROGRAM_ID.fixed_registry_wrapper,
  ]);
});

test("wrapper_dispatcher/transfer_public (route dispatches to fixed_registry_wrapper)", async () => {
  // transfer_public(token_id, recipient, amount, program_id)
  // Dispatches to fixed_registry_wrapper.aleo/transfer_public via call.dynamic.
  // Finalize verifies token_routes[token_id] == program_id (set above).
  await execute("wrapper_dispatcher.aleo", "transfer_public", [
    TOKEN_ID, RECIPIENT_ADDRESS, "1000u128", PROGRAM_ID.fixed_registry_wrapper,
  ]);
});

// ---------------------------------------------------------------------------
// Tests: 11 — direct_dispatcher: generic dispatch
//   Registers (program_id, network_id, token_id, convention) routes.
//   dispatch_f_a_u and dispatch_a_u provide typed generic dispatch.
// ---------------------------------------------------------------------------

test("direct_dispatcher/register_route (TOKEN_ID → token_registry)", async () => {
  // register_route(program_id: field, network_id: field, token_id: field, convention: u8)
  // NETWORK_ALEO = programNameToField("aleo") = 1868917857field (matches wrapper_dispatcher constant).
  // convention = 1 = ARC-0020 interface convention.
  const NETWORK_ALEO = programNameToField("aleo"); // 1868917857field
  const CONVENTION   = "1u8";
  await execute("direct_dispatcher.aleo", "register_route", [
    PROGRAM_ID.token_registry, NETWORK_ALEO, TOKEN_ID, CONVENTION,
  ]);
});

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

console.log("ARC-0020 Integration Tests");
console.log("=".repeat(60));
console.log(`Devnode:   ${DEVNODE_URL}`);
console.log(`Signer:    ${ADDRESS}`);
console.log(`Recipient: ${RECIPIENT_ADDRESS}`);
console.log(`Token ID:  ${TOKEN_ID}`);
console.log();

await runTests();
