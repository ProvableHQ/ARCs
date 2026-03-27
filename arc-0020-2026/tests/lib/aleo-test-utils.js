import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

import { Account } from "@provablehq/sdk";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let _networkUrl = process.env.NETWORK_URL || "http://127.0.0.1:3030";

export function getNetworkUrl() {
  return _networkUrl;
}

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

export function extractTransactionId(output) {
  const s = String(output || "");
  // Leo/snarkOS transaction IDs are bech32-like and typically start with "at1".
  // Match various formats: "at1...", "transaction ID: 'at1...'", etc.
  const m = s.match(/(?:transaction\s+id|transaction_id|txId)[:\s]*['"]?(at1[0-9a-z]{20,})['"]?/i)
    || s.match(/\b(at1[0-9a-z]{20,})\b/i);
  return m?.[1] || null;
}

async function fetchTransactionConfirmedOnce(txId) {
  const suffix = `/transaction/confirmed/${txId}`;
  const base = getNetworkUrl();
  const urls = [`${base}${suffix}`, `${base}/testnet${suffix}`];

  let last = null;
  for (const url of urls) {
    try {
      const r = await fetch(url);
      const text = await r.text().catch(() => "");
      last = { ok: r.ok, status: r.status, text, url };
      // Endpoint contract: HTTP 200 means confirmed.
      if (r.status === 200) return last;
    } catch (e) {
      last = { ok: false, status: 0, text: String(e?.message || e), url };
    }
  }
  return last;
}

export async function waitForTransactionConfirmed(txId, opts = {}) {
  if (!txId) throw new Error("waitForTransactionConfirmed requires txId");

  const timeoutMs = opts.timeoutMs ?? 10_000;
  const pollMs = opts.pollMs ?? 1_000;
  const startedAt = Date.now();

  let last = null;
  while (true) {
    last = await fetchTransactionConfirmedOnce(txId);
    if (last?.status === 200) return { txId, confirmed: true, last };

    if (Date.now() - startedAt > timeoutMs) {
      const details = last
        ? `last=${JSON.stringify(
            { ok: last.ok, status: last.status, url: last.url, text: String(last.text).slice(0, 500) },
            null,
            2,
          )}`
        : "last=null";
      throw new Error(`Timed out waiting for transaction confirmation for ${txId}. ${details}`);
    }

    await sleep(pollMs);
  }
}

export async function waitForTransactionConfirmedFromLeoExecution(execResult, opts = {}) {
  if (execResult?.rejected) {
    throw new Error(
      "Expected successful execution but got rejection. Do not pass expectRejection results to expectConfirmed.",
    );
  }
  const stdout = execResult?.stdout || "";
  const stderr = execResult?.stderr || "";
  const txId = execResult?.txId || extractTransactionId(`${stdout}\n${stderr}`);
  if (!txId) {
    throw new Error(
      "Could not extract transaction id from leo output.\n\n--- stdout ---\n" +
        stdout +
        "\n\n--- stderr ---\n" +
        stderr,
    );
  }
  return await waitForTransactionConfirmed(txId, opts);
}

const LEO_BIN = "leo";

/** When false, Leo subprocess output is still captured for return values but not echoed to the terminal. */
function leoEchoEnabled() {
  return process.env.LEO_TEST_SILENT !== "1";
}

/**
 * Mirror subprocess streams to the terminal (stdout/stderr) so Leo output is visible during tests.
 * Only `leo` is echoed by default; set opts.echo true to force, false to suppress.
 */
function shouldEchoRun(cmd, opts) {
  if (!leoEchoEnabled()) return false;
  if (opts.echo === false) return false;
  if (opts.echo === true) return true;
  return cmd === LEO_BIN;
}

async function run(cmd, args, opts = {}) {
  const echo = shouldEchoRun(cmd, opts);
  return await new Promise((resolve, reject) => {
    const p = spawn(cmd, args, {
      cwd: opts.cwd,
      env: opts.env,
    });

    let stdout = "";
    let stderr = "";
    // Leo stdout output is piped to the terminal.
    p.stdout?.on("data", (d) => {
      const chunk = d.toString();
      stdout += chunk;
      if (echo) process.stdout.write(chunk);
    });
    // Leo stderr output is piped to the terminal.
    p.stderr?.on("data", (d) => {
      const chunk = d.toString();
      stderr += chunk;
      if (echo) process.stderr.write(chunk);
    });

    p.on("error", reject);
    p.on("exit", (code) => {
      if (code === 0) {
        return resolve({ stdout, stderr });
      }
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

  const leoDevnodeBin = opts.leoDevnodeBin || LEO_BIN;
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];

  const logsDir = path.join(__dirname, "..", "logs");
  fs.mkdirSync(logsDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const suiteSuffix = opts.suiteName
    ? `-${String(opts.suiteName).replace(/[^a-zA-Z0-9_-]/g, "_")}`
    : "";
  const logPath =
    opts.logPath || path.join(logsDir, `snarkos-devnet-${timestamp}${suiteSuffix}.log`);
  const port = opts.port ?? 3030;
  const socketAddr = opts.socketAddr ?? `127.0.0.1:${port}`;
  const storageSuffix = opts.suiteName
    ? `-${String(opts.suiteName).replace(/[^a-zA-Z0-9_-]/g, "_")}`
    : `-${port}`;
  const storageRoot =
    opts.storageRoot || path.join(__dirname, "..", `.snarkos-devnet${storageSuffix}`);

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

  _networkUrl = `http://${socketAddr}`;

  devnetProc = spawn(
    leoDevnodeBin,
    [
      "devnode",
      "start",
      "--private-key",
      privateKey,
      "--network",
      "testnet",
      "--socket-addr",
      socketAddr,
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );

  // Devnode output goes only to the log file (not stdout/stderr) to keep test runs readable.
  devnetProc.stdout?.pipe(devnetLogStream, { end: false });
  devnetProc.stderr?.pipe(devnetLogStream, { end: false });

  const maxWaitMs = opts.maxWaitMs ?? 120_000;
  const startedAt = Date.now();
  while (true) {
    try {
      // Some snarkOS REST endpoints are network-prefixed (e.g. /testnet),
      // while others are not. Try both for compatibility.
      const r1 = await fetch(`${_networkUrl}/block/height/latest`);
      if (r1.ok) break;
      const r2 = await fetch(`${_networkUrl}/testnet/block/height/latest`);
      if (r2.ok) break;
    } catch {
      // ignore
    }
    if (Date.now() - startedAt > maxWaitMs) {
      throw new Error(`Timed out waiting for local devnet at ${_networkUrl} to start`);
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
      const r1 = await fetch(`${getNetworkUrl()}/block/height/latest`);
      txt1 = await r1.text();
      const h1 = Number(txt1);
      if (Number.isFinite(h1) && h1 >= minHeight) return h1;
    } catch {
      // ignore
    }

    let txt2 = "";
    try {
      const r2 = await fetch(`${getNetworkUrl()}/testnet/block/height/latest`);
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
  return await run(LEO_BIN, ["build"], { cwd: programPath, label: "leo build" });
}

export async function leoDeploy(programPath, opts = {}) {
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];

  const args = [
    "deploy",
    "--network",
    "testnet",
    "--endpoint",
    getNetworkUrl(),
    "--private-key",
    privateKey,
    "--broadcast",
    "--yes",
    "--devnet",
    "--max-wait",
    String(opts.maxWait ?? 15),
    "--blocks-to-check",
    String(opts.blocksToCheck ?? 15),
  ];
  if (opts.skip?.length) {
    for (const s of opts.skip) {
      args.push("--skip", s);
    }
  }
  if (process.env.SKIP_LEO_CHECKS === "1") {
    args.push("--skip-deploy-certificate");
  }

  return await run(LEO_BIN, args, { cwd: programPath, label: "leo deploy" });
}

export async function leoExecute(programPath, fnName, inputs, opts = {}) {
  const privateKey = opts.privateKey || DEFAULT_PRIVATE_KEYS[0];
  const expectRejection = opts.expectRejection === true;

  try {
    const executeArgs = [
      "execute",
      fnName,
      ...(inputs || []),
      "--broadcast",
      "--network",
      "testnet",
      "--endpoint",
      getNetworkUrl(),
      "--private-key",
      privateKey,
      "--yes",
      "--devnet",
      "--max-wait",
      String(opts.maxWait ?? 15),
      "--blocks-to-check",
      String(opts.blocksToCheck ?? 15),
    ];
    if (process.env.SKIP_LEO_CHECKS === "1") {
      executeArgs.push("--skip-execute-proof");
    }
    const res = await run(LEO_BIN, executeArgs, {
      cwd: programPath,
      label: `leo execute ${fnName}`,
    });
    if (res.stdout.includes("Transaction rejected")) {
      if (expectRejection) {
        return { rejected: true, stdout: res.stdout, stderr: res.stderr };
      }
      throw new Error(`Transaction rejected.\n\n${res.stdout}`);
    }
    if (expectRejection) {
      throw new Error(
        `Expected execution to reject but it succeeded.\n\n--- stdout ---\n${res.stdout}\n\n--- stderr ---\n${res.stderr}`,
      );
    }

    const txId = extractTransactionId(`${res.stdout}\n${res.stderr}`);
    return { ...res, txId };
  } catch (err) {
    if (expectRejection) {
      return { rejected: true, error: err };
    }
    throw err;
  }
}

export async function leoMappingValue(programName, mappingName, key, opts = {}) {
  return await run(
    LEO_BIN,
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
      getNetworkUrl(),
    ],
    { label: "leo query program --mapping-value" },
  );
}

export async function leoProgramExists(programName, opts = {}) {
  try {
    const args = [
      "query",
      "program",
      programName,
      "--network",
      "testnet",
      "--endpoint",
      getNetworkUrl(),
    ];
    const url = getNetworkUrl();
    const isLocalEndpoint =
      url.includes("127.0.0.1") || url.includes("localhost");
    if (opts.devnet !== false && isLocalEndpoint) {
      args.push("--devnet");
    }
    await run(LEO_BIN, args, { label: "leo query program" });
    return true;
  } catch {
    return false;
  }
}

export async function deployProgramFromFile(opts) {
  const { programId, programPath, skip } = opts;
  if (!programId) throw new Error("deployProgramFromFile requires programId");
  if (!programPath) throw new Error("deployProgramFromFile requires programPath");

  await leoBuild(programPath, opts);
  try {
    await leoDeploy(programPath, {
      privateKey: DEFAULT_PRIVATE_KEYS[0],
      skip,
    });
  } catch (e) {
    const msg = String(e?.message || e);
    if (!msg.includes("already exists on the network")) throw e;
  }

  // Ensure the program can be fetched from the node after deployment.
  const ok = await leoProgramExists(programId, opts);
  if (!ok) throw new Error(`Program ${programId} not found after deployment`);

  return { alreadyDeployed: false };
}

