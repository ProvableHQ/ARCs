// Test: does the mainnet WASM support V9 AVM syntax?
// If yes, we could use it to build transactions for V9-only programs.
import { Program as TestnetProgram, initThreadPool } from "@provablehq/sdk";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

await initThreadPool();

const __dir = dirname(fileURLToPath(import.meta.url));
const base = join(__dir, "..", "programs");
function readProg(rel) { return readFileSync(join(base, rel, "build/main.aleo"), "utf8"); }

const programs = [
  ["credits_clone", readProg("tokens/credits_clone")],
  ["wrapper_dispatcher", readProg("dispatchers/wrapper_dispatcher")],
  ["freezelist_program", readProg("lib/freezelist_program")],
];

console.log("=== Testnet WASM ===");
for (const [name, src] of programs) {
  try {
    const p = TestnetProgram.fromString(src);
    console.log(`OK: ${name}`);
  } catch(e) {
    console.log(`FAIL: ${name} — ${String(e).slice(0, 80)}...`);
  }
}
