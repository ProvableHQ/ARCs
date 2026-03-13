import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "compliant_token_template.aleo";
export const BALANCES_MAPPING = "balances";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.join(__dirname, "..", "..", "compliant_token_template");

function parseNumericPlaintext(s) {
  const t = String(s);
  if (t.trim() === "" || t.includes("null")) return 0n;
  const matches = [...t.matchAll(/(^|[^0-9])([0-9]+)u[0-9]+([^0-9]|$)/g)];
  if (!matches.length) throw new Error(`Unexpected mapping value output: ${t}`);
  return BigInt(matches[matches.length - 1][2]);
}

export async function getPublicBalance(address) {
  try {
    const { stdout } = await AleoUtils.leoMappingValue(
      PROGRAM_ID,
      BALANCES_MAPPING,
      address,
    );
    return parseNumericPlaintext(stdout);
  } catch {
    return 0n;
  }
}

export async function initialize(account, name, symbol, decimals, maxSupply, admin, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "initialize",
    [name, symbol, decimals, maxSupply, admin],
    { privateKey, ...opts },
  );
}

export async function mintPublic(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "mint_public", [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function updateRole(account, newAddress, role, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "update_role", [newAddress, role], {
    privateKey,
    ...opts,
  });
}

export async function transferPublic(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_public", [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function approvePublic(account, spender, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "approve_public", [spender, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function unapprovePublic(account, spender, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "unapprove_public", [spender, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferFromPublic(account, owner, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_from_public",
    [owner, recipient, amountU128],
    { privateKey, ...opts },
  );
}

export async function transferPublicToPrivate(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_public_to_private",
    [recipient, amountU128],
    { privateKey, ...opts },
  );
}

export async function transferFromPublicToPrivate(
  account,
  owner,
  recipient,
  amountU128,
  opts = {},
) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_from_public_to_private",
    [owner, recipient, amountU128],
    { privateKey, ...opts },
  );
}

export async function shield(account, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "shield", [amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferPrivate(
  account,
  inputRecord,
  recipient,
  amountU128,
  merkleProofs,
  opts = {},
) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_private",
    [recipient, amountU128, inputRecord, merkleProofs],
    { privateKey, ...opts },
  );
}

export async function transferPrivateToPublic(
  account,
  inputRecord,
  recipient,
  amountU128,
  merkleProofs,
  opts = {},
) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_private_to_public",
    [recipient, amountU128, inputRecord, merkleProofs],
    { privateKey, ...opts },
  );
}

export async function unshield(
  account,
  inputRecord,
  recipient,
  amountU128,
  merkleProofs,
  opts = {},
) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "unshield",
    [recipient, amountU128, inputRecord, merkleProofs],
    { privateKey, ...opts },
  );
}

export async function getCredentials(account, merkleProofs, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "get_credentials",
    [merkleProofs],
    { privateKey, ...opts },
  );
}

export async function transferPrivateWithCreds(
  account,
  inputRecord,
  recipient,
  amountU128,
  credentials,
  opts = {},
) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_private_with_creds",
    [recipient, amountU128, inputRecord, credentials],
    { privateKey, ...opts },
  );
}
