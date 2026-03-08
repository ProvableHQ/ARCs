import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "wrapped_token_registry.aleo";
export const WRAPPED_TOKEN_ID = "99999field";
export const BALANCES_MAPPING = "balances";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.join(__dirname, "..", "..", "wrapped_token_registry");

function parseNumericPlaintext(s) {
  const t = String(s);
  if (t.trim() === "" || t.includes("null")) return 0n;
  const matches = [...t.matchAll(/(^|[^0-9])([0-9]+)u[0-9]+([^0-9]|$)/g)];
  if (!matches.length) throw new Error(`Unexpected mapping value output: ${t}`);
  return BigInt(matches[matches.length - 1][2]);
}

export async function getPublicBalance(address) {
  try {
    const { stdout } = await AleoUtils.leoMappingValue(PROGRAM_ID, BALANCES_MAPPING, address);
    return parseNumericPlaintext(stdout);
  } catch {
    return 0n;
  }
}

export async function depositTokenPublic(account, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "deposit_token_public", [amountU128], {
    privateKey,
  });
}

export async function depositTokenPrivate(account, inputRecord, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "deposit_token_private", [inputRecord, amountU128], {
    privateKey,
  });
}

export async function withdrawTokenPublic(account, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "withdraw_token_public", [amountU128], {
    privateKey,
  });
}

export async function withdrawTokenPublicSigner(account, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "withdraw_token_public_signer", [amountU128], {
    privateKey,
  });
}

export async function withdrawTokenPrivate(account, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "withdraw_token_private", [amountU128], {
    privateKey,
  });
}

export async function transferPublic(account, recipient, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_public", [recipient, amountU128], {
    privateKey,
  });
}

export async function shield(account, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "shield", [amountU128], {
    privateKey,
  });
}

export async function unshield(account, inputRecord, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "unshield", [inputRecord, amountU128], {
    privateKey,
  });
}

export async function transferPrivate(account, inputRecord, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_private", [inputRecord, to, amountU128], {
    privateKey,
  });
}

export async function transferPrivateToPublic(account, inputRecord, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_private_to_public", [inputRecord, to, amountU128], {
    privateKey,
  });
}

export async function approvePublic(account, spender, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "approve_public", [spender, amountU128], {
    privateKey,
  });
}

export async function unapprovePublic(account, spender, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "unapprove_public", [spender, amountU128], {
    privateKey,
  });
}

export async function transferFromPublic(account, owner, recipient, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_from_public", [owner, recipient, amountU128], {
    privateKey,
  });
}
