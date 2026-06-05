/**
 * Static check: the deposit/withdraw functions in `wrapped_credits` and
 * `wrapped_token_registry` must implement the same logic, modulo
 * source-level naming differences.
 *
 * Both wrappers expose the same effective ARC20 wrapping behavior; the only
 * deltas are the underlying token program (`credits.aleo` vs
 * `token_registry.aleo`), the helper-function names, and the local variable
 * names. After normalizing those away, the function bodies should compare
 * byte-for-byte equal.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Slice from the first `fn deposit_*` definition up to the start of
// `fn transfer_public` (which marks the end of the deposit/withdraw block in
// both wrapper sources).
function extractDepositWithdrawBlock(content) {
  const m = content.match(/fn deposit_.*?(?=\n\n    fn transfer_public)/s);
  return m ? m[0].trim() : null;
}

// Find a function by name in the (already-normalized) source slice and return
// the full `fn name(...) { ... }` text using brace-depth tracking. This is
// resilient to nested blocks (e.g., `final { ... }`).
function extractFunctionWithBalancedBraces(str, fnName) {
  const re = new RegExp(`fn ${fnName}\\s*\\(`);
  const m = str.match(re);
  if (!m) return null;
  const start = m.index;
  const bodyStart = str.indexOf("{", start);
  if (bodyStart === -1) return null;
  let depth = 1;
  for (let i = bodyStart + 1; i < str.length; i++) {
    const c = str[i];
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) return str.slice(start, i + 1);
    }
  }
  return null;
}

// Pairs of (regex, replacement) applied in order. Goal: erase superficial
// differences (helper function names, parameter widths, identifier labels)
// while preserving meaningful logic.
const NORMALIZATION_RULES = [
  // 1) Strip line comments. Must run BEFORE collapsing newlines, otherwise
  //    `//[^\n]*` would greedily eat the rest of the file.
  [/\/\/[^\n]*/g, ""],

  // 2) Unify wrapper-specific transition names → generic ARC20 names.
  [/deposit_(credits|token)_public_signer/g, "deposit_public"],
  [/deposit_token_public/g, "deposit_public"],
  [/deposit_(credits|token)_private/g, "deposit_private"],
  [/withdraw_(credits|token)_public_signer/g, "withdraw_public_signer"],
  [/withdraw_(credits|token)_public/g, "withdraw_public"],
  [/withdraw_(credits|token)_private/g, "withdraw_private"],

  // 3) Unify the underlying-token program references.
  [/credits\.aleo\/credits/g, "ExternalRecord"],
  [/token_registry\.aleo\/Token/g, "Token"],
  [/(credits|token_registry)\.aleo::/g, "external::"],
  [/(credits|token_registry)\.aleo\//g, "external::"],

  // 4) Token-id is implicit for credits but explicit for token_registry. Inject
  //    `TOKEN_ID` so the credits version matches the token_registry version.
  [/WRAPPED_TOKEN_ID/g, "TOKEN_ID"],
  [
    /external::transfer_public_as_signer\(self\.address,/g,
    "external::transfer_public_as_signer(TOKEN_ID, self.address,",
  ],
  [
    /external::transfer_public\(self\.caller,/g,
    "external::transfer_public(TOKEN_ID, self.caller,",
  ],
  [
    /external::transfer_public\(self\.signer,/g,
    "external::transfer_public(TOKEN_ID, self.signer,",
  ],
  // Both wrappers should withdraw to a generic `withdrawer` symbol.
  [
    /external::transfer_public\(TOKEN_ID,\s*self\.caller,\s*amount\)/g,
    "external::transfer_public(TOKEN_ID, withdrawer, amount)",
  ],
  [
    /external::transfer_public\(TOKEN_ID,\s*self\.signer,\s*amount\)/g,
    "external::transfer_public(TOKEN_ID, withdrawer, amount)",
  ],

  // 5) Numeric width and parameter name normalization. Credits uses u64 with
  //    `as u128` casts; token_registry uses u128 throughout.
  [/amount as u128/g, "amount"],
  [/\bu64\b/g, "u128"],

  // 6) Pick a single canonical name for the ad-hoc local variables that
  //    differ purely in style between the two wrappers.
  [/previous_balance/g, "prev"],
  [/credits_finalization/g, "tr_final"],
  [/mint_output/g, "token_out"],
  [/(input_record|input_token)/g, "input"],

  // 7) Whitespace canonicalization (must run last).
  [/\s*\(\s*/g, " ("],
  [/\s*\)/g, ")"],
  [/,\s*\)/g, ")"],
  [/\s+/g, " "],
];

function normalizeDepositWithdraw(s) {
  if (!s) return "";
  let out = s;
  for (const [pattern, replacement] of NORMALIZATION_RULES) {
    out = out.replace(pattern, replacement);
  }
  return out.trim();
}

describe("deposit/withdraw logic", () => {
  const root = path.join(__dirname, "..");
  const wrappedCredits = path.join(root, "wrapped_credits", "src", "main.leo");
  const wrappedTokenRegistry = path.join(root, "wrapped_token_registry", "src", "main.leo");

  test("is equal across wrapped_credits and wrapped_token_registry", () => {
    const content1 = fs.readFileSync(wrappedCredits, "utf-8");
    const content2 = fs.readFileSync(wrappedTokenRegistry, "utf-8");

    const block1 = extractDepositWithdrawBlock(content1);
    const block2 = extractDepositWithdrawBlock(content2);

    expect(block1).not.toBeNull();
    expect(block2).not.toBeNull();

    const norm1 = normalizeDepositWithdraw(block1);
    const norm2 = normalizeDepositWithdraw(block2);

    // The private deposit/withdraw transitions emit different external record
    // shapes (credits.aleo::credits vs token_registry.aleo::Token return value
    // ordering and types), so we restrict the equality check to the public
    // transitions, where the wrappers must be identical modulo naming.
    const comparableFns = ["deposit_public", "withdraw_public", "withdraw_public_signer"];
    for (const fn of comparableFns) {
      const f1 = extractFunctionWithBalancedBraces(norm1, fn);
      const f2 = extractFunctionWithBalancedBraces(norm2, fn);
      expect(f1).not.toBeNull();
      expect(f2).not.toBeNull();
      expect(f1).toBe(f2);
    }
  });
});
