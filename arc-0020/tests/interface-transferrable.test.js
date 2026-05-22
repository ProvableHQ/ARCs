import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
      if (depth === 0) {
        return content.slice(start, i + 1).trim();
      }
    }
  }

  throw new Error(`Could not find end of interface ${name}`);
}

describe("ARC-style interface declarations", () => {
  const root = path.join(__dirname, "..");
  const wrappedCredits = path.join(root, "wrapped_credits", "src", "main.leo");
  const wrappedTokenRegistry = path.join(root, "wrapped_token_registry", "src", "main.leo");

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
});
