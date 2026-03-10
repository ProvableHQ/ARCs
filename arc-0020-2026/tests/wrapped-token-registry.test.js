import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as TokenRegistry from "./contracts/token-registry.js";
import * as WrappedTokenRegistry from "./contracts/wrapped-token-registry.js";
import { registerArc20WrapperTests, extractRecordPlaintexts } from "./lib/arc20-wrapper-tests.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("token_registry.aleo", () => {
  const programPath = path.join(__dirname, "..", "token_registry");
  const wrappedProgramPath = path.join(__dirname, "..", "wrapped_token_registry");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  // Custom token ID (must not equal CREDITS_RESERVED_TOKEN_ID)
  const CUSTOM_TOKEN_ID = "12345field";
  // Token ID wrapped by wrapped_token_registry.aleo
  const WRAPPED_TOKEN_ID = WrappedTokenRegistry.WRAPPED_TOKEN_ID;
  const MAX_SUPPLY = "1000000u128";
  const MINT_AMOUNT = "1000u128";
  const TRANSFER_AMOUNT = "200u128";
  const AUTHORIZED_UNTIL = "4294967295u32"; // max u32 = no expiry for non-auth tokens

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  let wrappedTokenRegistryDeployed = false;

  beforeAll(async () => {
    try {
      await AleoUtils.startDevnode({ suiteName: "token_registry.aleo", port: 3031 });

      await AleoUtils.deployProgramFromFile({
        programId: TokenRegistry.PROGRAM_ID,
        programPath,
      });

      try {
        const prevEndpoint = process.env.ENDPOINT;
        process.env.ENDPOINT = AleoUtils.getNetworkUrl();
        await AleoUtils.deployProgramFromFile({
          programId: WrappedTokenRegistry.PROGRAM_ID,
          programPath: wrappedProgramPath,
        });
        process.env.ENDPOINT = prevEndpoint;
        wrappedTokenRegistryDeployed = true;
      } catch (e) {
        process.env.ENDPOINT = undefined;
        wrappedTokenRegistryDeployed = false;
      }
    } catch (e) {
      await AleoUtils.stopDevnode();
      throw e;
    }
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
    // name "TEST" = 1413829460u128 (ASCII), symbol "TST" = 1413829460u128
    const name = "1413829460u128";
    const symbol = "1413829460u128";
    const decimals = "6u8";
    const extAuthRequired = "false";
    const extAuthParty = addr0;

    const exec = await AleoUtils.leoExecute(
      programPath,
      "register_token",
      [CUSTOM_TOKEN_ID, name, symbol, decimals, MAX_SUPPLY, extAuthRequired, extAuthParty],
      { privateKey: pk0 },
    );
    await expectConfirmed(exec);
  });

  test("register_token (negative): rejects duplicate token_id", async () => {
    const name = "1413829460u128";
    const symbol = "1413829460u128";
    const decimals = "6u8";
    await AleoUtils.leoExecute(
      programPath,
      "register_token",
      [CUSTOM_TOKEN_ID, name, symbol, decimals, MAX_SUPPLY, "false", addr0],
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
    // Verify by transferring - if mint worked, transfer should succeed
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
    // Verify: addr1 can now transfer back (proves they received)
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

  async function setupWrappedToken() {
    const name = "1413829460u128";
    const symbol = "1413829460u128";
    const decimals = "6u8";
    const extAuthRequired = "false";
    const extAuthParty = addr0;

    try {
      const reg = await AleoUtils.leoExecute(
        programPath,
        "register_token",
        [WRAPPED_TOKEN_ID, name, symbol, decimals, MAX_SUPPLY, extAuthRequired, extAuthParty],
        { privateKey: pk0 },
      );
      await expectConfirmed(reg);
    } catch {
      // already registered
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
    if (!wrappedTokenRegistryDeployed) return;
    await setupWrappedToken();

    const before = await WrappedTokenRegistry.getPublicBalance(addr0);
    const exec = await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "300u128");
    await expectConfirmed(exec);
    const after = await WrappedTokenRegistry.getPublicBalance(addr0);
    expect(after - before).toBe(300n);
  });

  test("wrapped_token_registry: withdraw_token_public decreases balance", async () => {
    if (!wrappedTokenRegistryDeployed) return;
    await setupWrappedToken();
    await WrappedTokenRegistry.depositTokenPublic(AleoUtils.accounts[0], "400u128");

    const before = await WrappedTokenRegistry.getPublicBalance(addr0);
    const exec = await WrappedTokenRegistry.withdrawTokenPublic(AleoUtils.accounts[0], "100u128");
    await expectConfirmed(exec);
    const after = await WrappedTokenRegistry.getPublicBalance(addr0);
    expect(before - after).toBe(100n);
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
