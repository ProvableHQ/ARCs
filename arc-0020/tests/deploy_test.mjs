import { ProgramManager, AleoKeyProvider, PrivateKey, Program, initThreadPool, getOrInitConsensusVersionTestHeights } from "@provablehq/sdk";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

await initThreadPool();
getOrInitConsensusVersionTestHeights("0,5,6,7,8,9,10,11,12,9999999,9999999,9999999,9999999");

const __dir = dirname(fileURLToPath(import.meta.url));
const base = join(__dir, "..", "programs");

const PRIVATE_KEY = PrivateKey.from_string("APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH");
const DEVNODE = "http://localhost:3030";
const TIMEOUT_MS = 30000;

function readProg(rel) {
  return readFileSync(join(base, rel, "build/main.aleo"), "utf8");
}

// Programs to test: [display name, relative path under programs/]
const programs = [
  ["token_registry",         "tokens/token_registry"],
  ["multisig_core",          "lib/multisig_core"],
  ["credits_wrapper",        "wrappers/credits_wrapper"],
  ["registry_wrapper",       "wrappers/registry_wrapper"],
  ["stablecoin_wrapper",     "wrappers/stablecoin_wrapper"],
  ["fixed_registry_wrapper", "wrappers/fixed_registry_wrapper"],
  ["wrapper_dispatcher",     "dispatchers/wrapper_dispatcher"],
  ["direct_dispatcher",      "dispatchers/direct_dispatcher"],
];

function classifyError(msg) {
  if (/cannot find program/i.test(msg)) {
    const dep = msg.match(/cannot find program[:\s']+([a-z0-9_]+\.aleo)/i)?.[1]
             ?? msg.match(/cannot find program[:\s']+([a-z0-9_]+)/i)?.[1]
             ?? "unknown";
    return `network_error:missing_dep:${dep}`;
  }
  if (/already exists on the network/i.test(msg)) return `network_error:already_deployed`;
  if (/does not exist on the network/i.test(msg)) return `network_error:not_on_network`;
  if (/Error finding program imports/i.test(msg)) {
    // Extract the missing program name from the inner error
    const dep = msg.match(/Error fetching program ([a-z0-9_]+\.aleo)/i)?.[1] ?? "unknown";
    return `network_error:missing_dep:${dep}`;
  }
  if (/ECONNREFUSED|ETIMEDOUT|failed to fetch/i.test(msg)) return `network_error:connection`;
  if (/TIMEOUT/i.test(msg)) return `network_error:timeout`;
  // Anything else is a parse/compile error
  return `parse_fail:${msg.slice(0, 200)}`;
}

// First pass: test Program.fromString to detect parse failures early
function checkParseable(programSrc, name) {
  try {
    const p = Program.fromString(programSrc);
    if (!p || typeof p.id !== "function") {
      return `parse_fail:Program.fromString returned invalid object`;
    }
    return null; // ok
  } catch (e) {
    return `parse_fail:${String(e.message ?? e).slice(0, 200)}`;
  }
}

const results = [];

for (const [name, relPath] of programs) {
  process.stdout.write(`Testing ${name}... `);

  let programSrc;
  try {
    programSrc = readProg(relPath);
  } catch (e) {
    const r = `parse_fail:file_read_error:${e.message}`;
    console.log(r);
    results.push([name, r]);
    continue;
  }

  // Step 1: quick parse check
  const parseErr = checkParseable(programSrc, name);
  if (parseErr) {
    console.log(parseErr);
    results.push([name, parseErr]);
    continue;
  }

  // Step 2: attempt to build a deployment transaction (requires network)
  const keyProvider = new AleoKeyProvider();
  keyProvider.useCache(true);

  const pm = new ProgramManager(DEVNODE, keyProvider, null);

  const buildFn = () => pm.buildDevnodeDeploymentTransaction({
    privateKey: PRIVATE_KEY,
    program: programSrc,
    priorityFee: 0,
    privateFee: false,
  });

  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error("TIMEOUT after " + TIMEOUT_MS + "ms")), TIMEOUT_MS)
  );

  try {
    const tx = await Promise.race([buildFn(), timeoutPromise]);
    const txStr = typeof tx === "string" ? tx : JSON.stringify(tx);
    console.log(`parse_ok (Transaction built, len=${txStr.length})`);
    results.push([name, "parse_ok"]);
  } catch (e) {
    const msg = String(e.message ?? e);
    const category = classifyError(msg);
    console.log(category);
    results.push([name, category]);
  }
}

// Summary table
console.log("\n=== RESULTS ===");
console.log("program name             | result");
console.log("-------------------------|-------------------------------------------------------------");
for (const [name, result] of results) {
  console.log(`${name.padEnd(25)}| ${result}`);
}
