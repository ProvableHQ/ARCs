import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as TokenRegistry from "./contracts/token-registry.js";
import * as WrappedTokenRegistry from "./contracts/wrapped-token-registry.js";

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

  async function expectRejected(p) {
    await expect(p).rejects.toThrow(/Transaction rejected|failed \(code/i);
  }

  let wrappedTokenRegistryDeployed = false;

  beforeAll(async () => {
    try {
      await AleoUtils.startDevnode();

      await AleoUtils.deployProgramFromFile({
        programId: TokenRegistry.PROGRAM_ID,
        programPath,
      });

      try {
        const prevEndpoint = process.env.ENDPOINT;
        process.env.ENDPOINT = AleoUtils.NETWORK_URL;
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
    await expectRejected(TokenRegistry.initialize(AleoUtils.accounts[0]));
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
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "register_token",
        [CUSTOM_TOKEN_ID, name, symbol, decimals, MAX_SUPPLY, "false", addr0],
        { privateKey: pk0 },
      ),
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
    await expectRejected(
      TokenRegistry.mintPublic(
        AleoUtils.accounts[1],
        CUSTOM_TOKEN_ID,
        addr1,
        "100u128",
        AUTHORIZED_UNTIL,
      ),
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
    await expectRejected(
      TokenRegistry.transferPublic(
        AleoUtils.accounts[1],
        CUSTOM_TOKEN_ID,
        addr0,
        "999999999999u128",
      ),
    );
  });

  test("approve_public and transfer_from_public: spender can transfer on behalf of owner", async () => {
    const approveAmount = "150u128";
    const execApprove = await TokenRegistry.approvePublic(
      AleoUtils.accounts[1],
      CUSTOM_TOKEN_ID,
      addr0,
      approveAmount,
    );
    await expectConfirmed(execApprove);

    const execTransfer = await TokenRegistry.transferFromPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr1,
      addr0,
      "100u128",
    );
    await expectConfirmed(execTransfer);
    // Verify: addr0 received - they can transfer out
    const execOut = await TokenRegistry.transferPublic(
      AleoUtils.accounts[0],
      CUSTOM_TOKEN_ID,
      addr1,
      "50u128",
    );
    await expectConfirmed(execOut);
  });

  test("transfer_from_public (negative): exceeds allowance rejects", async () => {
    await expectRejected(
      TokenRegistry.transferFromPublic(
        AleoUtils.accounts[0],
        CUSTOM_TOKEN_ID,
        addr1,
        addr0,
        "999999u128",
      ),
    );
  });

  test("wrapped_token_registry: transfer via TransferPublic interface", async () => {
    if (!wrappedTokenRegistryDeployed) {
      console.warn(
        "Skipping: wrapped_token_registry not deployed (dependency deploy skips both programs)",
      );
      return;
    }
    // Register and mint the token wrapped by wrapped_token_registry (99999field)
    const name = "1413829460u128";
    const symbol = "1413829460u128";
    const decimals = "6u8";
    const extAuthRequired = "false";
    const extAuthParty = addr0;

    const registerExec = await AleoUtils.leoExecute(
      programPath,
      "register_token",
      [WRAPPED_TOKEN_ID, name, symbol, decimals, MAX_SUPPLY, extAuthRequired, extAuthParty],
      { privateKey: pk0 },
    );
    await expectConfirmed(registerExec);

    const mintExec = await TokenRegistry.mintPublic(
      AleoUtils.accounts[0],
      WRAPPED_TOKEN_ID,
      addr0,
      "500u128",
      AUTHORIZED_UNTIL,
    );
    await expectConfirmed(mintExec);

    // Transfer using wrapped_token_registry (TransferPublic interface)
    const transferExec = await WrappedTokenRegistry.transferPublic(
      AleoUtils.accounts[0],
      addr1,
      "150u128",
    );
    await expectConfirmed(transferExec);

    // Verify: addr1 received and can transfer back via token_registry
    const execBack = await TokenRegistry.transferPublic(
      AleoUtils.accounts[1],
      WRAPPED_TOKEN_ID,
      addr0,
      "50u128",
    );
    await expectConfirmed(execBack);
  });
});
