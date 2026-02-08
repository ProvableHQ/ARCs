import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

import { Account } from "@provablehq/sdk";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const NETWORK_URL = process.env.NETWORK_URL || "http://127.0.0.1:3030";

export const DEFAULT_PRIVATE_KEYS = [
  "APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH",
  "APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh",
  "APrivateKey1zkp2GUmKbVsuc1NSj28pa1WTQuZaK5f1DQJAT6vPcHyWokG",
  "APrivateKey1zkpBjpEgLo4arVUkQmcLdKQMiAKGaHAQVVwmF8HQby8vdYs",
];

export const accounts = DEFAULT_PRIVATE_KEYS.map(
  (privateKey) => new Account({ privateKey }),
);
export const addresses = accounts.map((a) => a.address().to_string());

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function resolveLocalLeoBin() {
  // Per repo conventions: build/deploy/execute/query must use this binary.
  const pinned = path.join(os.homedir(), "programs", "leo", "target", "release", "leo");
  if (fs.existsSync(pinned)) return pinned;
  if (process.env.LEO_BIN) return process.env.LEO_BIN;
  return pinned; // Let spawn error loudly if missing.
}

function resolveGlobalLeoBin() {
  // Per repo conventions: devnode must use globally-installed `leo`.
  if (process.env.LEO_DEVNODE_BIN) return process.env.LEO_DEVNODE_BIN;
  return "leo";
}

async function run(cmd, args, opts = {}) {
  return await new Promise((resolve, reject) => {
    const p = spawn(cmd, args, {
      cwd: opts.cwd,
      env: opts.env,
      stdio: [opts.stdin != null ? "pipe" : "ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    p.stdout?.on("data", (d) => (stdout += d.toString()));
    p.stderr?.on("data", (d) => (stderr += d.toString()));

    // Some Leo commands (notably `deploy`) prompt for confirmation.
    // Allow callers to provide stdin to make these commands non-interactive.
    if (opts.stdin != null) {
      try {
        p.stdin?.write(String(opts.stdin));
        p.stdin?.end();
      } catch {
        // ignore
      }
    }

    p.on("error", reject);
    p.on("exit", (code) => {
      if (code === 0) return resolve({ stdout, stderr });
      reject(
        new Error(
          `${opts.label || cmd} failed (code ${code}).\n\n--- stdout ---\n${stdout}\n\n--- stderr ---\n${stderr}`,
        ),
      );
    });
  });
}

async function killPids(pids) {
  for (const pid of pids) {
    if (!Number.isFinite(pid)) continue;
    if (pid <= 1) continue;
    try {
      process.kill(pid, "SIGTERM");
    } catch {
      // ignore
    }
  }
}

async function killExistingDevnodeProcesses(storageRoot) {
  // Defensive cleanup: if previous runs crashed, snarkOS validators can remain
  // alive and prevent `leo devnode start` from binding ports. Only target processes
  // whose command line includes our storage root.
  try {
    const { stdout } = await run("ps", ["-ax", "-o", "pid=,command="], {
      label: "ps",
    });
    const pids = [];
    for (const line of stdout.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (!trimmed.includes(storageRoot)) continue;
      if (!trimmed.includes("leo devnode")) continue;
      const m = trimmed.match(/^(\d+)\s+/);
      if (!m) continue;
      pids.push(Number(m[1]));
    }
    await killPids(pids);
  } catch {
    // ignore
  }
}

let devnetProc = null;
let devnetLogStream = null;

export async function startDevnode(opts = {}) {
  if (devnetProc) return devnetProc;

  const leoDevnodeBin = opts.leoDevnodeBin || resolveGlobalLeoBin();
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];

  const logPath = opts.logPath || path.join(__dirname, "..", "snarkos-devnet.log");
  const storageRoot =
    opts.storageRoot || path.join(__dirname, "..", ".snarkos-devnet");

  if (opts.clearStorage !== false) {
    try {
      fs.rmSync(storageRoot, { recursive: true, force: true });
    } catch {
      // ignore
    }
  }
  fs.mkdirSync(storageRoot, { recursive: true });

  await killExistingDevnodeProcesses(storageRoot);

  devnetLogStream = fs.createWriteStream(logPath, { flags: "a" });
  devnetLogStream.write(`\n=== devnet start ${new Date().toISOString()} ===\n`);

  devnetProc = spawn(
    leoDevnodeBin,
    [
      "devnode",
      "start",
      "--private-key",
      privateKey,
      "--network",
      "testnet",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );

  devnetProc.stdout?.pipe(devnetLogStream, { end: false });
  devnetProc.stderr?.pipe(devnetLogStream, { end: false });

  const maxWaitMs = opts.maxWaitMs ?? 120_000;
  const startedAt = Date.now();
  while (true) {
    try {
      // Some snarkOS REST endpoints are network-prefixed (e.g. /testnet),
      // while others are not. Try both for compatibility.
      const r1 = await fetch(`${NETWORK_URL}/block/height/latest`);
      if (r1.ok) break;
      const r2 = await fetch(`${NETWORK_URL}/testnet/block/height/latest`);
      if (r2.ok) break;
    } catch {
      // ignore
    }
    if (Date.now() - startedAt > maxWaitMs) {
      throw new Error(`Timed out waiting for local devnet at ${NETWORK_URL} to start`);
    }
    await sleep(1000);
  }

  return devnetProc;
}

export async function stopDevnode() {
  if (!devnetProc) return;
  const proc = devnetProc;
  devnetProc = null;

  try {
    proc.kill("SIGTERM");
  } catch {
    // ignore
  }

  // Avoid leaving a pending timer handle that keeps Jest alive.
  const exited = new Promise((r) => proc.once("exit", r));
  let timeoutId = null;
  const timedOut = new Promise((r) => {
    timeoutId = setTimeout(r, 10_000);
  });
  await Promise.race([exited, timedOut]);
  if (timeoutId) clearTimeout(timeoutId);

  try {
    devnetLogStream?.write(`\n=== devnet stop ${new Date().toISOString()} ===\n`);
    devnetLogStream?.end();
  } catch {
    // ignore
  } finally {
    devnetLogStream = null;
  }
}

process.on("exit", () => {
  try {
    devnetProc?.kill("SIGTERM");
  } catch {
    // ignore
  }
});

export async function waitForMinHeight(minHeight, timeoutMs = 120_000) {
  const startedAt = Date.now();
  while (true) {
    // Try both REST variants (prefixed and non-prefixed).
    let txt1 = "";
    try {
      const r1 = await fetch(`${NETWORK_URL}/block/height/latest`);
      txt1 = await r1.text();
      const h1 = Number(txt1);
      if (Number.isFinite(h1) && h1 >= minHeight) return h1;
    } catch {
      // ignore
    }

    let txt2 = "";
    try {
      const r2 = await fetch(`${NETWORK_URL}/testnet/block/height/latest`);
      txt2 = await r2.text();
      const h2 = Number(txt2);
      if (Number.isFinite(h2) && h2 >= minHeight) return h2;
    } catch {
      // ignore
    }

    const txt = txt2 || txt1;
    if (Date.now() - startedAt > timeoutMs) {
      throw new Error(`Timed out waiting for height >= ${minHeight} (last=${txt})`);
    }
    await sleep(1000);
  }
}

export async function leoBuild(programPath, opts = {}) {
  const leoBin = opts.leoBin || resolveLocalLeoBin();
  return await run(leoBin, ["build"], { cwd: programPath, label: "leo build" });
}

export async function leoDeploy(programPath, opts = {}) {
  const leoBin = opts.leoBin || resolveLocalLeoBin();
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];

  return await run(
    leoBin,
    [
      "deploy",
      "--network",
      "testnet",
      "--endpoint",
      NETWORK_URL,
      "--private-key",
      privateKey,
      "--broadcast",
      "--yes",
      "--devnet",
      "--max-wait",
      String(opts.maxWait ?? 15),
      "--blocks-to-check",
      String(opts.blocksToCheck ?? 15),
    ],
    { cwd: programPath, label: "leo deploy" },
  );
}

export async function leoExecute(programPath, fnName, inputs, opts = {}) {
  const leoBin = opts.leoBin || resolveLocalLeoBin();
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];

  const res = await run(
    leoBin,
    [
      "execute",
      fnName,
      ...(inputs || []),
      "--broadcast",
      "--network",
      "testnet",
      "--endpoint",
      NETWORK_URL,
      "--private-key",
      privateKey,
      "--yes",
      "--devnet",
      "--max-wait",
      String(opts.maxWait ?? 15),
      "--blocks-to-check",
      String(opts.blocksToCheck ?? 15),
    ],
    { cwd: programPath, label: `leo execute ${fnName}` },
  );
  if (res.stdout.includes("Transaction rejected")) {
    throw new Error(`Transaction rejected.\n\n${res.stdout}`);
  }
  return res;
}

export async function leoMappingValue(programName, mappingName, key, opts = {}) {
  const leoBin = opts.leoBin || resolveLocalLeoBin();
  return await run(
    leoBin,
    [
      "query",
      "program",
      programName,
      "--mapping-value",
      mappingName,
      key,
      "--network",
      "testnet",
      "--endpoint",
      NETWORK_URL,
    ],
    { label: "leo query program --mapping-value" },
  );
}

export async function leoProgramExists(programName, opts = {}) {
  const leoBin = opts.leoBin || resolveLocalLeoBin();
  try {
    await run(
      leoBin,
      [
        "query",
        "program",
        programName,
        "--network",
        "testnet",
        "--endpoint",
        NETWORK_URL,
      ],
      { label: "leo query program" },
    );
    return true;
  } catch {
    return false;
  }
}

export async function deployProgramFromFile(opts) {
  const { programId, programPath } = opts;
  if (!programId) throw new Error("deployProgramFromFile requires programId");
  if (!programPath) throw new Error("deployProgramFromFile requires programPath");

  await leoBuild(programPath, opts);
  try {
    await leoDeploy(programPath, { privateKey: DEFAULT_PRIVATE_KEYS[0] });
  } catch (e) {
    const msg = String(e?.message || e);
    if (!msg.includes("already exists on the network")) throw e;
  }

  // Ensure the program can be fetched from the node after deployment.
  const ok = await leoProgramExists(programId, opts);
  if (!ok) throw new Error(`Program ${programId} not found after deployment`);

  return { alreadyDeployed: false };
}

