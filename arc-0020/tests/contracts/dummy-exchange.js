import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "../lib/aleo-test-utils.js";

export const PROGRAM_ID = "dummy_exchange.aleo";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PROGRAM_PATH = path.resolve(__dirname, "..", "..", "dummy_exchange");

// `transfer_from` uses `_dynamic_call` to invoke the supplied token program at
// runtime. The local Leo VM that builds the proof has to know about that
// external program, so callers can pass `opts.with: ["wrapped_credits.aleo"]`
// to load it (locally or, if missing, fetched from the network endpoint).
export async function transferFrom(account, tokenId, owner, recipient, amountU128, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "transfer_from",
    [tokenId, owner, recipient, amountU128],
    { privateKey, ...opts },
  );
}

export async function swap(account, tokenIn, tokenOut, amountIn, amountOut, opts = {}) {
  const privateKey = account.privateKey().to_string();
  return await AleoUtils.leoExecute(
    PROGRAM_PATH,
    "swap",
    [tokenIn, tokenOut, amountIn, amountOut],
    { privateKey, ...opts },
  );
}
