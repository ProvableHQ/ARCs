/**
 * Static checks on the ARC20 / ARC22 interface declarations:
 *
 *   1. Both ARC20 wrappers declare the `IARC20` interface.
 *   2. Both ARC20 wrappers declare *exactly the same* `IARC20` body.
 *   3. The ARC22 `IARC22` interface is the same as `IARC20` modulo the parts
 *      that are intentionally specific to ARC22 (private-only flows and the
 *      `ComplianceRecord`).
 *
 * These tests intentionally operate on the source text — we don't need a Leo
 * parser; we just need to extract a balanced `interface { ... }` block and
 * compare canonicalized entries.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Slice out an `interface NAME { ... }` block by tracking brace depth.
function extractInterface(content, name) {
  const startMatch = content.match(new RegExp(`interface\\s+${name}\\s*\\{`));
  expect(startMatch).not.toBeNull();

  const start = startMatch.index;
  const openBrace = content.indexOf("{", start);
  let depth = 0;

  for (let i = openBrace; i < content.length; i += 1) {
    if (content[i] === "{") {
      depth += 1;
    } else if (content[i] === "}") {
      depth -= 1;
      if (depth === 0) return content.slice(start, i + 1).trim();
    }
  }

  throw new Error(`Could not find end of interface ${name}`);
}

// Slice out a single interface entry starting at `startIndex`. An entry is
// either a `record … { … }` block (brace-terminated) or an `fn / view fn`
// declaration ending in a semicolon.
function extractInterfaceDeclaration(content, startIndex) {
  const openBrace = content.indexOf("{", startIndex);
  const semicolon = content.indexOf(";", startIndex);
  let depth = 0;

  if (openBrace !== -1 && openBrace < semicolon) {
    for (let i = openBrace; i < content.length; i += 1) {
      if (content[i] === "{") {
        depth += 1;
      } else if (content[i] === "}") {
        depth -= 1;
        if (depth === 0) return content.slice(startIndex, i + 1).trim();
      }
    }
  }

  return content.slice(startIndex, semicolon + 1).trim();
}

// Canonicalize an interface body to the entries that the public ARC20 surface
// shares with ARC22: skip private-only functions and the ARC22-specific
// `ComplianceRecord`.
function comparableInterfaceEntries(content, name) {
  const body = extractInterface(content, name);
  const entries = [];
  const entryPattern = /(?:record|(?:view\s+)?fn)\s+\w+/g;

  for (const match of body.matchAll(entryPattern)) {
    const entry = extractInterfaceDeclaration(body, match.index);
    const functionName = entry.match(/(?:view\s+)?fn\s+(\w+)/)?.[1];

    // Private-only functions are intentionally excluded from the cross-spec
    // comparison; ARC22 has additional Merkle-proof inputs there.
    if (functionName?.includes("private")) continue;

    // ARC22-specific record (the investigator-facing receipt).
    if (entry.startsWith("record ComplianceRecord")) continue;

    entries.push(entry);
  }

  return entries.join("\n");
}

describe("ARC-style interface declarations", () => {
  const root = path.join(__dirname, "..");
  const wrappedCredits = path.join(root, "wrapped_credits", "src", "main.leo");
  const wrappedTokenRegistry = path.join(root, "wrapped_token_registry", "src", "main.leo");
  const compliantTokenTemplate = path.join(
    root,
    "..",
    "arc-0022",
    "compliant_token_template",
    "src",
    "main.leo",
  );

  test("wrapped_token_registry declares IARC20", () => {
    const content = fs.readFileSync(wrappedTokenRegistry, "utf-8");
    expect(content).toMatch(/interface IARC20\s*\{/);
    expect(content).toMatch(/program wrapped_token_registry\.aleo:\s*IARC20/);
  });

  test("wrapped_credits declares IARC20", () => {
    const content = fs.readFileSync(wrappedCredits, "utf-8");
    expect(content).toMatch(/interface IARC20\s*\{/);
    expect(content).toMatch(/program wrapped_credits\.aleo:\s*IARC20/);
  });

  test("wrapper contracts declare the exact same IARC20 interface", () => {
    const wrappedCreditsInterface = extractInterface(
      fs.readFileSync(wrappedCredits, "utf-8"),
      "IARC20",
    );
    const wrappedTokenRegistryInterface = extractInterface(
      fs.readFileSync(wrappedTokenRegistry, "utf-8"),
      "IARC20",
    );

    expect(wrappedTokenRegistryInterface).toBe(wrappedCreditsInterface);
  });

  test("IARC20 matches IARC22 except for private functions", () => {
    const wrappedCreditsInterface = comparableInterfaceEntries(
      fs.readFileSync(wrappedCredits, "utf-8"),
      "IARC20",
    );
    const compliantTokenTemplateInterface = comparableInterfaceEntries(
      fs.readFileSync(compliantTokenTemplate, "utf-8"),
      "IARC22",
    );

    expect(compliantTokenTemplateInterface).toBe(wrappedCreditsInterface);
  });
});
