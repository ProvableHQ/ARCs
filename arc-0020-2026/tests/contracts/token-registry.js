import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "token_registry.aleo";
export const AUTHORIZED_BALANCES_MAPPING = "authorized_balances";
export const REGISTERED_TOKENS_MAPPING = "registered_tokens";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.join(__dirname, "..", "..", "token_registry");

// CREDITS_RESERVED_TOKEN_ID from token_registry.aleo
export const CREDITS_RESERVED_TOKEN_ID =
  "3443843282313283355522573239085696902919850365217539366784739393210722344986field";

function parseNumericPlaintext(s) {
  const t = String(s);
  if (t.trim() === "" || t.includes("null")) return 0n;
  const matches = [...t.matchAll(/(^|[^0-9])([0-9]+)u[0-9]+([^0-9]|$)/g)];
  if (!matches.length) throw new Error(`Unexpected mapping value output: ${t}`);
  return BigInt(matches[matches.length - 1][2]);
}

/**
 * Get public balance for a token/account. Key is hash(TokenOwner{account, token_id}).
 * Leo expects the key - for authorized_balances the key is a field (BHP256 hash).
 * We pass TokenOwner struct: "{ account: <addr>, token_id: <field> }"
 */
export async function getPublicBalance(tokenId, address) {
  try {
    const key = `{ account: ${address}, token_id: ${tokenId} }`;
    const { stdout } = await AleoUtils.leoMappingValue(
      PROGRAM_ID,
      AUTHORIZED_BALANCES_MAPPING,
      key,
    );
    // Balance struct: { token_id, account, balance, authorized_until }
    const balanceMatch = stdout.match(/balance:\s*([0-9]+)u128/);
    return balanceMatch ? BigInt(balanceMatch[1]) : 0n;
  } catch {
    return 0n;
  }
}

export async function initialize(account) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "initialize", [], {
    privateKey,
  });
}

export async function registerToken(account, tokenId, name, symbol, decimals, maxSupply, extAuthRequired, extAuthParty) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "register_token",
    [tokenId, name, symbol, decimals, maxSupply, extAuthRequired, extAuthParty],
    { privateKey },
  );
}

export async function mintPublic(account, tokenId, recipient, amount, authorizedUntil) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "mint_public",
    [tokenId, recipient, amount, authorizedUntil],
    { privateKey },
  );
}

export async function transferPublic(account, tokenId, recipient, amount) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_public",
    [tokenId, recipient, amount],
    { privateKey },
  );
}

export async function approvePublic(account, tokenId, spender, amount) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "approve_public",
    [tokenId, spender, amount],
    { privateKey },
  );
}

export async function unapprovePublic(account, tokenId, spender, amount) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "unapprove_public",
    [tokenId, spender, amount],
    { privateKey },
  );
}

export async function transferFromPublic(account, tokenId, owner, recipient, amount) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_from_public",
    [tokenId, owner, recipient, amount],
    { privateKey },
  );
}

export async function setRole(account, tokenId, targetAccount, role) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "set_role",
    [tokenId, targetAccount, role],
    { privateKey },
  );
}
