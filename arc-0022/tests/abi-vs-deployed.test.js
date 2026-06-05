/**
 * Regression test: ensures the local ARC22 reference ABI exposes the same
 * IARC22 function signatures as the deployed `usdcx_stablecoin.aleo` program
 * on mainnet.
 *
 * Requires network access to the Explorer API
 * (`https://api.explorer.provable.com/v2`); override with `EXPLORER_API_BASE`,
 * `DEPLOYED_NETWORK`, or `DEPLOYED_PROGRAM_ID` env vars.
 *
 * Local ABI side:
 *   - We run `leo build` in `compliant_token_template/` and read
 *     `build/abi.json`.
 *
 * Deployed ABI side:
 *   - We fetch the deployed program and its imports from the Explorer API.
 *   - We write the imports to `deployed-imports`.
 *   - We run:
 *       leo abi <program>.aleo --output all_abis --imports-dir deployed-imports
 *
 * The comparison is restricted to the non-view function signatures declared by
 * the local `IARC22` interface. We normalize bytecode-derived ABI artifacts
 * such as `arg1` input names, default-private mode spelling, and program-name
 * qualifiers so the test checks the callable shape rather than source labels.
 *
 * Run with: npm run test:abi-vs-deployed
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const LOCAL_PROGRAM_PATH = path.join(__dirname, "..", "compliant_token_template");
const LOCAL_PROGRAM_ID = "compliant_token_template.aleo";
const LOCAL_ABI_PATH = path.join(LOCAL_PROGRAM_PATH, "build", "abi.json");
const LOCAL_INTERFACE_SOURCE = path.join(LOCAL_PROGRAM_PATH, "src", "main.leo");

const EXPLORER_API_BASE =
  process.env.EXPLORER_API_BASE || "https://api.explorer.provable.com/v2";
const DEPLOYED_NETWORK = process.env.DEPLOYED_NETWORK || "mainnet";
const DEPLOYED_PROGRAM_ID =
  process.env.DEPLOYED_PROGRAM_ID || "usdcx_stablecoin.aleo";

const FETCH_TIMEOUT_MS = 30_000;

/**
 * Fetch the deployed program bytecode from the Explorer API.
 *
 * The endpoint returns either a JSON-encoded string (the raw bytecode) or a
 * JSON object with a `program` field; we handle both shapes defensively.
 */
async function fetchDeployedBytecode(programId) {
  const url = `${EXPLORER_API_BASE}/${DEPLOYED_NETWORK}/program/${programId}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const r = await fetch(url, { signal: controller.signal });
    if (!r.ok) {
      throw new Error(
        `Failed to fetch ${programId} from ${url}: HTTP ${r.status} ${r.statusText}`,
      );
    }
    const text = await r.text();
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      // Some networks return raw bytecode without JSON-encoding.
      return text;
    }
    if (typeof parsed === "string") return parsed;
    if (parsed && typeof parsed.program === "string") return parsed.program;
    throw new Error(
      `Unexpected response shape for ${programId} from ${url}: ${typeof parsed}`,
    );
  } finally {
    clearTimeout(timer);
  }
}

function readLocalAbi() {
  const raw = fs.readFileSync(LOCAL_ABI_PATH, "utf8");
  return JSON.parse(raw);
}

function parseImports(bytecode) {
  return [...String(bytecode).matchAll(/^import\s+([\w.]+);\s*$/gm)].map((m) => m[1]);
}

function extractInterfaceBlock(source, interfaceName) {
  const marker = `interface ${interfaceName}`;
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) throw new Error(`Could not find ${interfaceName} in local source`);

  const openIndex = source.indexOf("{", markerIndex);
  if (openIndex < 0) throw new Error(`Could not find opening brace for ${interfaceName}`);

  let depth = 0;
  for (let i = openIndex; i < source.length; i++) {
    if (source[i] === "{") depth++;
    if (source[i] === "}") depth--;
    if (depth === 0) return source.slice(openIndex + 1, i);
  }
  throw new Error(`Could not find closing brace for ${interfaceName}`);
}

function readIarc22FunctionNames() {
  const source = fs.readFileSync(LOCAL_INTERFACE_SOURCE, "utf8");
  const block = extractInterfaceBlock(source, "IARC22");
  return sorted(
    [...block.matchAll(/^\s*fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm)].map((m) => m[1]),
  );
}

async function writeDeployedProgramAndImports(programId, rootDir) {
  const programDir = path.join(rootDir, "program");
  const importsDir = path.join(rootDir, "deployed-imports");
  fs.mkdirSync(programDir, { recursive: true });
  fs.mkdirSync(importsDir, { recursive: true });

  const visited = new Set();
  let rootProgramFile = null;

  async function writeProgram(currentProgramId, isRoot = false) {
    if (visited.has(currentProgramId)) return;
    visited.add(currentProgramId);

    const bytecode = await fetchDeployedBytecode(currentProgramId);
    const outputDir = isRoot ? programDir : importsDir;
    const outputPath = path.join(outputDir, currentProgramId);
    fs.writeFileSync(outputPath, bytecode);
    if (isRoot) rootProgramFile = outputPath;

    for (const importId of parseImports(bytecode)) {
      await writeProgram(importId, false);
    }
  }

  await writeProgram(programId, true);
  return { programFile: rootProgramFile, importsDir };
}

async function runLeoAbi(programFile, importsDir, outputDir) {
  await runCommand("leo", [
    "abi",
    programFile,
    "--network",
    DEPLOYED_NETWORK,
    "--output",
    outputDir,
    "--imports-dir",
    importsDir,
    "-q",
  ]);
}

async function runCommand(cmd, args, opts = {}) {
  return await new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd: opts.cwd,
      env: opts.env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (d) => {
      stdout += d.toString();
    });
    child.stderr?.on("data", (d) => {
      stderr += d.toString();
    });

    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) return resolve({ stdout, stderr });
      reject(
        new Error(
          `${cmd} ${args.join(" ")} failed (code ${code}).\n\n--- stdout ---\n${stdout}\n\n--- stderr ---\n${stderr}`,
        ),
      );
    });
  });
}

function readAbiByProgram(outputDir, programId) {
  const candidates = fs
    .readdirSync(outputDir)
    .filter((name) => name.endsWith(".abi.json"))
    .map((name) => path.join(outputDir, name));

  for (const file of candidates) {
    const abi = JSON.parse(fs.readFileSync(file, "utf8"));
    if (abi.program === programId) return abi;
  }

  throw new Error(
    `Could not find ABI for ${programId} in ${outputDir}. Found: ${candidates
      .map((f) => path.basename(f))
      .join(", ")}`,
  );
}

function functionSignatureMap(abi, names) {
  const callables = [
    ...(abi.functions ?? []).map((fn) => ["function", fn]),
    ...(abi.views ?? []).map((fn) => ["view", fn]),
  ];
  const byName = new Map();

  for (const [kind, fn] of callables) {
    if (!names.includes(fn.name)) continue;
    if (byName.has(fn.name)) throw new Error(`Duplicate ABI callable named ${fn.name}`);
    byName.set(fn.name, normalizeCallableSignature(abi, kind, fn));
  }

  return Object.fromEntries([...byName.entries()].sort(([a], [b]) => a.localeCompare(b)));
}

function normalizeCallableSignature(abi, kind, fn) {
  return {
    kind,
    name: fn.name,
    is_final: kind === "function" ? fn.is_final : undefined,
    const_parameters: normalizeType(fn.const_parameters ?? []),
    inputs: (fn.inputs ?? []).map((input) => ({
      mode: normalizeInputMode(input.mode),
      ty: normalizeType(input.ty),
    })),
    outputs: (fn.outputs ?? []).map((output) => ({
      mode: output.mode,
      ty: normalizeType(output.ty),
    })),
  };
}

function normalizeInputMode(mode) {
  return mode === "Public" ? "Public" : "Private";
}

function normalizeType(value) {
  if (Array.isArray(value)) return value.map((v) => normalizeType(v));
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([key]) => key !== "program")
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, nested]) => [key, normalizeType(nested)]),
    );
  }
  return value;
}

describe("leo abi: local IARC22 signatures vs deployed usdcx_stablecoin.aleo", () => {
  let localAbi;
  let deployedAbi;
  let iarc22FunctionNames;
  let workDir;

  beforeAll(async () => {
    await AleoUtils.leoBuild(LOCAL_PROGRAM_PATH);
    localAbi = readLocalAbi();
    expect(localAbi.program).toBe(LOCAL_PROGRAM_ID);

    iarc22FunctionNames = readIarc22FunctionNames();

    workDir = fs.mkdtempSync(path.join(os.tmpdir(), "arc22-abi-vs-deployed-"));
    const { programFile, importsDir } = await writeDeployedProgramAndImports(
      DEPLOYED_PROGRAM_ID,
      workDir,
    );
    const outputDir = path.join(workDir, "all_abis");
    await runLeoAbi(programFile, importsDir, outputDir);
    deployedAbi = readAbiByProgram(outputDir, DEPLOYED_PROGRAM_ID);
  }, 120_000);

  afterAll(() => {
    if (workDir) fs.rmSync(workDir, { recursive: true, force: true });
  });

  test("IARC22 non-view function signatures match the deployed ABI", () => {
    const localSignatures = functionSignatureMap(localAbi, iarc22FunctionNames);
    const deployedSignatures = functionSignatureMap(deployedAbi, iarc22FunctionNames);

    expect(Object.keys(localSignatures)).toEqual(iarc22FunctionNames);
    expect(Object.keys(deployedSignatures)).toEqual(iarc22FunctionNames);
    expect(deployedSignatures).toEqual(localSignatures);
  });
});

function sorted(arr) {
  return [...arr].sort();
}
