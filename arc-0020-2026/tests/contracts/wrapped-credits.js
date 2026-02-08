import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "wrapped_credits.aleo";
export const BALANCES_MAPPING = "balances";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.join(__dirname, "..", "..", "wrapped_credits");

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

export async function depositCreditsPublic(account, amountU64) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `deposit_credits_public`, [amountU64], {
    privateKey,
  });
}

export async function withdrawCreditsPublic(account, amountU64) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `withdraw_credits_public`, [amountU64], {
    privateKey,
  });
}

export async function withdrawCreditsPublicSigner(account, amountU64) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `withdraw_credits_public_signer`, [amountU64], {
    privateKey,
  });
}

export async function transferPublic(account, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_public`, [to, amountU128], {
    privateKey,
  });
}

export async function transferPublicAsSigner(account, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_public_as_signer`, [to, amountU128], {
    privateKey,
  });
}

