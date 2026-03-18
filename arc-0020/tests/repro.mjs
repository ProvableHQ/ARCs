/**
 * Minimal reproducer:
 *   buildDevnodeDeploymentTransaction generates V9-format (function VKs only).
 *   At devnode V14, programs with record types are rejected:
 *   "expected N function and M record verifying keys after ConsensusVersion::V14"
 *
 * To reproduce:
 *   1. Start devnode: leo devnode start --home /tmp/test_devnode \
 *        --manual-block-creation \
 *        --private-key APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH
 *   2. Advance to block 17+ (V14): POST /testnet/block/create {"num_blocks":17}
 *   3. Run this script: node repro.mjs
 *
 * Expected: deployment accepted
 * Actual: "expected 22 function and 1 record verifying keys after ConsensusVersion::V14"
 */
import {
  Account, AleoNetworkClient, NetworkRecordProvider, ProgramManager,
  initThreadPool, getOrInitConsensusVersionTestHeights,
} from "@provablehq/sdk";

// Minimal program with one record type
const PROGRAM_WITH_RECORD = `\
program test_record_vk.aleo;

record Token:
    owner as address.private;
    amount as u64.private;

function mint:
    input r0 as address.private;
    input r1 as u64.private;
    cast r0 r1 into r2 as Token.record;
    output r2 as Token.record;

constructor:
    assert.eq edition 0u16;
`;

await initThreadPool();

// SDK requires exactly 13 heights. Cannot give 14 to reach V14.
// Attempt to pass 14 heights (to include V14 at block 17) panics:
//   "Expected exactly 13 ConsensusVersion heights."
// So we use 13 heights, capping at V9 (9999999 for V10+).
getOrInitConsensusVersionTestHeights("0,5,6,7,8,9,10,11,12,9999999,9999999,9999999,9999999");

const KEY = "APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH";
const account = new Account({ privateKey: KEY });
const pm = new ProgramManager(
  "http://localhost:3030",
  new NetworkRecordProvider(account, new AleoNetworkClient("http://localhost:3030"))
);
pm.setAccount(account);

console.log("Building deployment transaction...");
let tx;
try {
  tx = await pm.buildDevnodeDeploymentTransaction({
    program: PROGRAM_WITH_RECORD,
    priorityFee: 0,
    privateFee: false,
  });
} catch (e) {
  console.error("Build error:", e.message);
  process.exit(1);
}

const txObj = JSON.parse(tx);
const vks = txObj?.deployment?.verifying_keys ?? [];
console.log(`Transaction built. VK count: ${vks.length}`);
console.log("VK names:", vks.map(v => v[0]));
// Observed: VK count = 1 (only "mint"), no VK for "Token" record.
// Expected at V14: VK count = 2 (one for "mint" function, one for "Token" record).

console.log("\nBroadcasting...");
const resp = await fetch("http://localhost:3030/testnet/transaction/broadcast", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: tx,
});
const body = await resp.text();
console.log("Status:", resp.status);
console.log("Response:", body);
// At V14: "expected 1 function and 1 record verifying keys after ConsensusVersion::V14"
// At V9-V13: accepted (no record VK requirement)
