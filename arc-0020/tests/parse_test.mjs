import { Program, initThreadPool, getOrInitConsensusVersionTestHeights } from "@provablehq/sdk";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

await initThreadPool();
getOrInitConsensusVersionTestHeights("0,1,2,3,4,5,6,7,8,9,10,10000000");

const __dir = dirname(fileURLToPath(import.meta.url));
const base = join(__dir, "..", "programs");

function readProg(rel) { return readFileSync(join(base, rel, "build/main.aleo"), "utf8"); }

const programs = {
  merkle_tree:            readProg("lib/merkle_tree"),
  multisig_core:          readProg("lib/multisig_core"),
  credits_clone:          readProg("tokens/credits_clone"),
  freezelist_program:     readProg("lib/freezelist_program"),
  token_registry:         readProg("tokens/token_registry"),
  stablecoin_program:     readProg("tokens/stablecoin_program"),
  token_interface:        readProg("wrappers/token_interface"),
  credits_wrapper:        readProg("wrappers/credits_wrapper"),
  registry_wrapper:       readProg("wrappers/registry_wrapper"),
  stablecoin_wrapper:     readProg("wrappers/stablecoin_wrapper"),
  fixed_registry_wrapper: readProg("wrappers/fixed_registry_wrapper"),
  direct_dispatcher:      readProg("dispatchers/direct_dispatcher"),
  wrapper_dispatcher:     readProg("dispatchers/wrapper_dispatcher"),
};

for (const [name, src] of Object.entries(programs)) {
  try {
    const p = Program.fromString(src);
    console.log(`OK: ${name}`);
  } catch (e) {
    const msg = String(e);
    // Show just first 120 chars of the error
    console.log(`FAIL: ${name} — ${msg.slice(0, 120)}...`);
  }
}
