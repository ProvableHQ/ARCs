import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "dummy_exchange.aleo";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.resolve(__dirname, "..", "..", "dummy_exchange");

export async function transferFrom(account, owner, recipient, amountU128) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(PROGRAM_PATH, "transfer_from", [owner, recipient, amountU128], {
    privateKey,
  });
}
