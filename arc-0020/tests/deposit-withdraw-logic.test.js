import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function extractDepositWithdrawBlock(content) {
  const m = content.match(/fn deposit_.*?(?=\n\n    fn transfer_public)/s);
  return m ? m[0].trim() : null;
}

function extractFunctionWithBalancedBraces(str, fnName) {
  const re = new RegExp(`fn ${fnName}\\s*\\(`);
  const m = str.match(re);
  if (!m) return null;
  const start = m.index;
  // Find the first { (function body start) and track brace depth from there
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

function normalizeDepositWithdraw(s) {
  if (!s) return "";
  // Strip comments first (before collapsing newlines, else //[^\n]* eats rest of string)
  s = s.replace(/\/\/[^\n]*/g, "");
  return s
    .replace(/deposit_credits_public/g, "deposit_public")
    .replace(/deposit_token_public/g, "deposit_public")
    .replace(/deposit_credits_private/g, "deposit_private")
    .replace(/deposit_token_private/g, "deposit_private")
    .replace(/withdraw_credits_public_signer/g, "withdraw_public_signer")
    .replace(/withdraw_token_public_signer/g, "withdraw_public_signer")
    .replace(/withdraw_credits_public/g, "withdraw_public")
    .replace(/withdraw_token_public/g, "withdraw_public")
    .replace(/withdraw_credits_private/g, "withdraw_private")
    .replace(/withdraw_token_private/g, "withdraw_private")
    .replace(/credits\.aleo\/credits/g, "ExternalRecord")
    .replace(/token_registry\.aleo\/Token/g, "Token")
    .replace(/credits\.aleo::/g, "external::")
    .replace(/token_registry\.aleo::/g, "external::")
    .replace(/credits\.aleo\//g, "external::")
    .replace(/token_registry\.aleo\//g, "external::")
    .replace(/WRAPPED_TOKEN_ID/g, "TOKEN_ID")
    .replace(/amount as u128/g, "amount")
    .replace(/\bu64\b/g, "u128")
    .replace(/previous_balance/g, "prev")
    .replace(/credits_finalization/g, "tr_final")
    .replace(/mint_output/g, "token_out")
    .replace(/input_record/g, "input")
    .replace(/input_token/g, "input")
    .replace(/external::transfer_public_as_signer\(self\.address,/g, "external::transfer_public_as_signer(TOKEN_ID, self.address,")
    .replace(/external::transfer_public\(self\.caller,/g, "external::transfer_public(TOKEN_ID, self.caller,")
    .replace(/external::transfer_public\(self\.signer,/g, "external::transfer_public(TOKEN_ID, self.signer,")
    .replace(
      /let tr_final = external::transfer_public\s*\(\s*TOKEN_ID,\s*self\.caller,\s*amount\s*\)\s*;\s*let withdrawer = self\.caller/g,
      "let withdrawer = self.caller; let tr_final = external::transfer_public(TOKEN_ID, withdrawer, amount)",
    )
    .replace(
      /let tr_final = external::transfer_public\s*\(\s*TOKEN_ID,\s*self\.signer,\s*amount\s*\)\s*;\s*let withdrawer = self\.signer/g,
      "let withdrawer = self.signer; let tr_final = external::transfer_public(TOKEN_ID, withdrawer, amount)",
    )
    .replace(/\s*\(\s*/g, " (")
    .replace(/\s*\)/g, ")")
    .replace(/,\s*\)/g, ")")
    .replace(/\s+/g, " ")
    .trim();
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
