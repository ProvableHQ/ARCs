import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function extractInterfaceARC20(content) {
  const m = content.match(/interface ARC20 \{\s*([\s\S]*?)\n\}/);
  return m ? m[1].trim() : null;
}

function normalizeForComparison(s) {
  return s
    .replace(/Token record:\s*\{\s*owner:\s*address,\s*amount:\s*u128,\s*\.\.\.\s*\}/g, "")
    .replace(/token_registry\.aleo\/Token/g, "Token")
    .replace(/\s*,\s*\)/g, ")")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .replace(/\s+/g, " ")
    .trim();
}

describe("interface ARC20", () => {
  const root = path.join(__dirname, "..");
  const wrappedCredits = path.join(root, "wrapped_credits", "src", "main.leo");
  const wrappedTokenRegistry = path.join(root, "wrapped_token_registry", "src", "main.leo");

  test("is equal across wrapped_credits and wrapped_token_registry", () => {
    const content1 = fs.readFileSync(wrappedCredits, "utf-8");
    const content2 = fs.readFileSync(wrappedTokenRegistry, "utf-8");

    const iface1 = extractInterfaceARC20(content1);
    const iface2 = extractInterfaceARC20(content2);

    expect(iface1).not.toBeNull();
    expect(iface2).not.toBeNull();

    const norm1 = normalizeForComparison(iface1);
    const norm2 = normalizeForComparison(iface2);

    expect(norm1).toBe(norm2);
  });
});
