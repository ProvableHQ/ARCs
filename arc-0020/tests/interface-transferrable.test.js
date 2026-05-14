import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("ARC-style interface declarations", () => {
  const root = path.join(__dirname, "..");
  const wrappedCredits = path.join(root, "wrapped_credits", "src", "main.leo");
  const wrappedTokenRegistry = path.join(root, "wrapped_token_registry", "src", "main.leo");

  test("wrapped_token_registry declares IARC20 plus IARC20Mintable", () => {
    const content = fs.readFileSync(wrappedTokenRegistry, "utf-8");
    expect(content).toMatch(/interface IARC20\s*\{/);
    expect(content).toMatch(/interface IARC20Mintable\s*:\s*IARC20/);
    expect(content).toMatch(/program wrapped_token_registry\.aleo:\s*IARC20Mintable/);
  });

  test("wrapped_credits declares IARC20 plus IARC20Mintable", () => {
    const content = fs.readFileSync(wrappedCredits, "utf-8");
    expect(content).toMatch(/interface IARC20\s*\{/);
    expect(content).toMatch(/interface IARC20Mintable\s*:\s*IARC20/);
    expect(content).toMatch(/program wrapped_credits\.aleo:\s*IARC20Mintable/);
  });
});
