import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as TokenRegistry from "./contracts/token-registry.js";
import * as WrappedTokenRegistry from "./contracts/wrapped-token-registry.js";
import * as DummyExchange from "./contracts/dummy-exchange.js";
import { registerArc20WrapperTests } from "./lib/arc20-wrapper-tests.js";
import { Address } from "@provablehq/sdk";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Encode an ASCII string into a Leo `u128` literal (little-endian byte layout).
// Used for token `name` / `symbol`, which are stored as packed ASCII in u128.
function encodeAsciiToU128Literal(s) {
  if (Buffer.byteLength(s, "utf8") > 16) {
    throw new Error(`encodeAsciiToU128Literal: "${s}" is longer than 16 bytes`);
  }
  const value = [...Buffer.from(s)].reduce(
    (acc, byte, i) => acc + BigInt(byte) * 256n ** BigInt(i),
    0n,
  );
  return `${value}u128`;
}

describe("token_registry.aleo", () => {
  const programPath = path.join(__dirname, "..", "token_registry");
  const wrappedProgramPath = path.join(__dirname, "..", "wrapped_token_registry");
  const exchangePath = path.join(__dirname, "..", "dummy_exchange");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  // Custom token ID (must not collide with CREDITS_RESERVED_TOKEN_ID).
  const CUSTOM_TOKEN_ID = "12345field";
  // Token ID wrapped by wrapped_token_registry.aleo (matches WRAPPED_TOKEN_ID const in the wrapper).
  const WRAPPED_TOKEN_ID = WrappedTokenRegistry.WRAPPED_TOKEN_ID;

  // Used by the dummy_exchange dynamic-dispatch tests below: the exchange
  // routes a call to whatever program the field encodes.
  const exchangeAddress = Address.fromProgramId(DummyExchange.PROGRAM_ID).to_string();
  const wrappedTokenRegistryTokenId = DummyExchange.programNameToTokenIdField(
    "wrapped_token_registry",
  );

  const TOKEN_NAME = encodeAsciiToU128Literal("TEST");
  const TOKEN_SYMBOL = encodeAsciiToU128Literal("TST");
  const DECIMALS = "6u8";
  const MAX_SUPPLY = "1000000u128";
  const MINT_AMOUNT = "1000u128";
  const TRANSFER_AMOUNT = "200u128";
  // Max u32 sentinel: token_registry.aleo treats this as "no expiry" for non-auth tokens.
  const AUTHORIZED_UNTIL = "4294967295u32";

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  beforeAll(async () => {
    const start = Date.now();
    await AleoUtils.startDevnode({ suiteName: "token_registry.aleo", port: 3031 });

    await AleoUtils.deployProgramFromFile({
      programId: TokenRegistry.PROGRAM_ID,
      programPath,
    });

    await AleoUtils.deployProgramFromFile({
      programId: WrappedTokenRegistry.PROGRAM_ID,
      programPath: wrappedProgramPath,
    });

    // Deploy dummy_exchange so the (currently skipped) dynamic-dispatch tests
    // below can be re-enabled without changing setup. `skip` avoids
    // re-deploying wrapped_token_registry, which is already on-chain.
    await AleoUtils.deployProgramFromFile({
      programId: DummyExchange.PROGRAM_ID,
      programPath: exchangePath,
      skip: ["wrapped_token_registry"],
    });

    process.stdout.write(`wrapped-token-registry.test.js beforeAll: ${Date.now() - start}ms\n`);
  });

  afterAll(async () => {
    await AleoUtils.stopDevnode();
  });

  test("initialize: sets up credits reserved token", async () => {
    const exec = await TokenRegistry.initialize(AleoUtils.accounts[0]);
    await expectConfirmed(exec);
  });

  test("initialize (negative): rejects second call", async () => {
    await TokenRegistry.initialize(AleoUtils.accounts[0], { expectRejection: true });
  });

  test("register_token: admin can register a custom token", async () => {
    const exec = await AleoUtils.leoExecute(
      programPath,
      "register_token",
      [CUSTOM_TOKEN_ID, TOKEN_NAME, TOKEN_SYMBOL, DECIMALS, MAX_SUPPLY, "false", addr0],
      { privateKey: pk0 },
    );
    await expectConfirmed(exec);
  });

  test("register_token (negative): rejects duplicate token_id", async () => {
    await AleoUtils.leoExecute(
      programPath,
      "register_token",
      [CUSTOM_TOKEN_ID, TOKEN_NAME, TOKEN_SYMBOL, DECIMALS, MAX_SUPPLY, "false", addr0],
      { privateKey: pk0, expectRejection: true },
    );
  });

  test("mint_public: admin mints to recipient", async () => {
    const exec = await TokenRegistry.mintPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr0,
      MINT_AMOUNT,
      AUTHORIZED_UNTIL,
    );
    await expectConfirmed(exec);
    // Verify the mint took effect by transferring out a portion.
    const transferExec = await TokenRegistry.transferPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr1,
      "100u128",
    );
    await expectConfirmed(transferExec);
  });

  test("mint_public (negative): non-admin cannot mint", async () => {
    await TokenRegistry.mintPublic(
      AleoUtils.accounts[1],
      CUSTOM_TOKEN_ID,
      addr1,
      "100u128",
      AUTHORIZED_UNTIL,
      { expectRejection: true },
    );
  });

  test("transfer_public: moves balance between users", async () => {
    const exec = await TokenRegistry.transferPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr1,
      TRANSFER_AMOUNT,
    );
    await expectConfirmed(exec);
    // Verify reachability of the new balance: addr1 sends a small portion back.
    const execBack = await TokenRegistry.transferPublic(
      AleoUtils.accounts[1],
      CUSTOM_TOKEN_ID,
      addr0,
      "50u128",
    );
    await expectConfirmed(execBack);
  });

  test("transfer_public (negative): insufficient balance rejects", async () => {
    await TokenRegistry.transferPublic(
      AleoUtils.accounts[1],
      CUSTOM_TOKEN_ID,
      addr0,
      "999999999999u128",
      { expectRejection: true },
    );
  });

  test("transfer_from_public (negative): exceeds allowance rejects", async () => {
    await TokenRegistry.transferFromPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr1,
      addr0,
      "999999u128",
      { expectRejection: true },
    );
  });

  // Register the wrapper-backed token in token_registry, then mint enough of it
  // to addr0 so subsequent deposit_token_public_signer calls succeed. Idempotent
  // wrt registration: a duplicate-register rejection is treated as "already done"
  // and any other error is re-thrown.
  async function setupWrappedToken() {
    try {
      const reg = await AleoUtils.leoExecute(
        programPath,
        "register_token",
        [WRAPPED_TOKEN_ID, TOKEN_NAME, TOKEN_SYMBOL, DECIMALS, MAX_SUPPLY, "false", addr0],
        { privateKey: pk0 },
      );
      await expectConfirmed(reg);
    } catch (err) {
      const msg = String(err?.message || err);
      // The first call of the suite registers the token; subsequent calls hit
      // the duplicate-token assertion in token_registry.aleo. Any other failure
      // (deploy issue, network, etc.) should still surface.
      if (!msg.includes("Transaction rejected")) throw err;
    }

    const mintExec = await TokenRegistry.mintPublic(
      AleoUtils.accounts[0],
      WRAPPED_TOKEN_ID,
      addr0,
      "1000u128",
      AUTHORIZED_UNTIL,
    );
    await expectConfirmed(mintExec);
  }

  test("wrapped_token_registry: deposit_token_public increases balance", async () => {
    await setupWrappedToken();

    const before = await WrappedTokenRegistry.getPublicBalance(addr0);
    const exec = await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "300u128");
    await expectConfirmed(exec);
    const after = await WrappedTokenRegistry.getPublicBalance(addr0);
    expect(after - before).toBe(300n);
  });

  test("wrapped_token_registry: withdraw_token_public decreases balance", async () => {
    await setupWrappedToken();
    await expectConfirmed(
      await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "400u128"),
    );

    const before = await WrappedTokenRegistry.getPublicBalance(addr0);
    const exec = await WrappedTokenRegistry.withdrawTokenPublic(AleoUtils.accounts[0], "100u128");
    await expectConfirmed(exec);
    const after = await WrappedTokenRegistry.getPublicBalance(addr0);
    expect(before - after).toBe(100n);
  });

  // KNOWN-FAILING: dummy_exchange.aleo uses `_dynamic_call` to invoke
  // wrapped_token_registry's ARC20 surface (`transfer_from_public` /
  // `transfer_public`). With Leo 4.0.2, dynamic calls coerce every argument to
  // `*.private`, but those wrapped_token_registry transitions expect
  // `address.public` for owner / recipient. The on-chain execution verifier
  // rejects the broadcast with:
  //   "Input 0 in dynamic call to transfer_from_public should be of type
  //    address.private, found: public"
  //
  // Both tests in this block are kept (skipped) so the dynamic-dispatch flows
  // are exercised in code, and so the test bodies are ready to re-enable once
  // Leo supports public-mode arguments through `_dynamic_call` (or once the
  // dummy_exchange Leo source is reworked accordingly). dummy_exchange is
  // deployed in `beforeAll` so that re-enabling these tests does not require
  // any further setup changes.
  describe.skip("dummy_exchange (dynamic dispatch into wrapped_token_registry)", () => {
    async function bal(addr) {
      return await WrappedTokenRegistry.getPublicBalance(addr);
    }

    test("transfer_from: spender pulls from owner via allowance", async () => {
      await setupWrappedToken();
      await expectConfirmed(
        await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "500u128"),
      );

      const amount = "75u128";
      await expectConfirmed(
        await WrappedTokenRegistry.approvePublic(AleoUtils.accounts[0], exchangeAddress, amount),
      );

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      const execTransferFrom = await DummyExchange.transferFrom(
        AleoUtils.accounts[0],
        wrappedTokenRegistryTokenId,
        addr0,
        addr1,
        amount,
        { with: ["wrapped_token_registry.aleo"] },
      );
      await expectConfirmed(execTransferFrom);
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(before0 - after0).toBe(75n);
      expect(after1 - before1).toBe(75n);
    });

    test("swap: signer trades amount_in for amount_out (same token)", async () => {
      // dummy_exchange.aleo::swap performs two dynamic calls:
      //   1. transfer_from_public(token_in, signer, exchange, amount_in)  – pull
      //   2. transfer_public(token_out, signer, amount_out)               – push
      //
      // For the push to succeed, the exchange's own balance of `token_out`
      // must already cover `amount_out`. We pre-fund it here, then approve
      // `amount_in` so the pull side can spend on the signer's behalf.
      await setupWrappedToken();
      await expectConfirmed(
        await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "500u128"),
      );

      const amountIn = "75u128";
      const amountOut = "50u128";

      await expectConfirmed(
        await WrappedTokenRegistry.transferPublic(
          AleoUtils.accounts[0],
          exchangeAddress,
          amountOut,
        ),
      );
      await expectConfirmed(
        await WrappedTokenRegistry.approvePublic(
          AleoUtils.accounts[0],
          exchangeAddress,
          amountIn,
        ),
      );

      const before0 = await bal(addr0);
      const beforeExchange = await bal(exchangeAddress);
      const execSwap = await DummyExchange.swap(
        AleoUtils.accounts[0],
        wrappedTokenRegistryTokenId,
        wrappedTokenRegistryTokenId,
        amountIn,
        amountOut,
        { with: ["wrapped_token_registry.aleo"] },
      );
      await expectConfirmed(execSwap);
      const after0 = await bal(addr0);
      const afterExchange = await bal(exchangeAddress);

      expect(before0 - after0).toBe(75n - 50n);
      expect(afterExchange - beforeExchange).toBe(75n - 50n);
    });
  });

  registerArc20WrapperTests({
    Wrapper: WrappedTokenRegistry,
    accounts: AleoUtils.accounts,
    addresses: AleoUtils.addresses,
    expectConfirmed,
    ensureBalance: async () => {
      await setupWrappedToken();
      const b = await WrappedTokenRegistry.getPublicBalance(addr0);
      if (b < 500n) {
        const r = await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "500u128");
        await expectConfirmed(r);
      }
    },
  });
});
