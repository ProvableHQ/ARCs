import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "wrapped_credits.aleo";
export const BALANCES_MAPPING = "balances";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.resolve(__dirname, "..", "..", "wrapped_credits");

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

export async function depositCreditsPublic(account, amountU64, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `deposit_credits_public`, [amountU64], {
    privateKey,
    ...opts,
  });
}

export async function withdrawCreditsPublic(account, amountU64, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `withdraw_credits_public`, [amountU64], {
    privateKey,
    ...opts,
  });
}

export async function withdrawCreditsPublicSigner(account, amountU64, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `withdraw_credits_public_signer`, [amountU64], {
    privateKey,
    ...opts,
  });
}

export async function transferPublic(account, to, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_public`, [to, amountU128], {
    privateKey,
    ...opts,
  });
}

// `wrapped_credits` no longer exposes `shield` / `unshield` transitions; mirror the old behavior
// using public→private and private→public wrapped-balance moves for the same account.
export async function shield(account, amountU128, opts = {}) {
  const recipient = account.address().to_string();
  return await transferPublicToPrivate(account, recipient, amountU128, opts);
}

export async function unshield(account, inputRecord, amountU128, opts = {}) {
  const recipient = account.address().to_string();
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_private_to_public",
    [inputRecord, recipient, amountU128],
    { privateKey, ...opts },
  );
}

export async function transferPrivate(account, inputRecord, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_private`, [inputRecord, recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferPrivateToPublic(account, inputRecord, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_private_to_public", [inputRecord, recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferPublicToPrivate(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_public_to_private`, [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferPublicAsSigner(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_public_as_signer`, [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function approvePublic(account, spender, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `approve_public`, [spender, amountU128], {
    privateKey,
  });
}

export async function unapprovePublic(account, spender, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `unapprove_public`, [spender, amountU128], {
    privateKey,
  });
}

export async function transferFromPublic(account, owner, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_from_public`, [owner, recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function transferFromPublicToPrivate(account, owner, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `transfer_from_public_to_private`, [owner, recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function mintPublic(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `mint_public`, [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function mintPrivate(account, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `mint_private`, [recipient, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function burnPublic(account, owner, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `burn_public`, [owner, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function burnPrivate(account, inputRecord, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `burn_private`, [inputRecord, amountU128], {
    privateKey,
    ...opts,
  });
}

export async function joinTokens(account, input1, input2, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `join`, [input1, input2], {
    privateKey,
    ...opts,
  });
}

export async function splitToken(account, inputRecord, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, `split`, [inputRecord, amountU128], {
    privateKey,
    ...opts,
  });
}

