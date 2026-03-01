import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "wrapped_token_registry.aleo";
export const WRAPPED_TOKEN_ID = "99999field";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.join(__dirname, "..", "..", "wrapped_token_registry");

export async function transferPublic(account, recipient, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_public", [recipient, amountU128], {
    privateKey,
  });
}

export async function transferPublicToPrivate(account, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_public_to_private", [to, amountU128], {
    privateKey,
  });
}

export async function transferPrivate(account, inputRecord, to, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_private", [inputRecord, to, amountU128], {
    privateKey,
  });
}
