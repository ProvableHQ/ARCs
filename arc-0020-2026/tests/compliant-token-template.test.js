/**
 * Tests for compliant_token_template.aleo (ARC20Compliant).
 *
 * Leo deploy automatically deploys dependencies (merkle_tree, multisig_core, freezelist)
 * before compliant_token_template. The freezelist project in ../freezelist uses
 * DEPLOYER_ADDRESS matching the test account. beforeAll initializes freezelist,
 * then compliant_token_template, grants MINTER_ROLE to admin, and mints to addr0.
 *
 * Skipped (require MerkleProof or Credentials): transfer_private, transfer_private_to_public,
 * unshield, transfer_private_with_creds, get_credentials
 *
 * Run with: SKIP_LEO_CHECKS=1 npm run test:compliant-token-template
 */
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as CompliantToken from "./contracts/compliant-token-template.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("compliant_token_template.aleo", () => {
  const programPath = path.join(__dirname, "..", "compliant_token_template");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  const NAME = "1413829460u128"; // "TEST" in ASCII bits
  const SYMBOL = "1413829460u128"; // "TST"
  const DECIMALS = "6u8";
  const MAX_SUPPLY = "1000000u128";
  const BLOCK_HEIGHT_WINDOW = "100u32";

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  async function bal(addr) {
    return await CompliantToken.getPublicBalance(addr);
  }

  let compliantTokenDeployed = false;

  beforeAll(async () => {
    const start = Date.now();
    try {
      await AleoUtils.startDevnode({ suiteName: "compliant_token_template.aleo", port: 3032 });

      try {
        const prevEndpoint = process.env.ENDPOINT;
        process.env.ENDPOINT = AleoUtils.getNetworkUrl();
        await AleoUtils.deployProgramFromFile({
          programId: CompliantToken.PROGRAM_ID,
          programPath,
        });
        process.env.ENDPOINT = prevEndpoint;
        compliantTokenDeployed = true;
      } catch (e) {
        process.env.ENDPOINT = undefined;
        compliantTokenDeployed = false;
        throw e;
      }

      if (compliantTokenDeployed) {
        // Initialize freezelist first (compliant_token_template reads from it).
        const freezelistInit = await AleoUtils.leoExecute(
          programPath,
          "freezelist.aleo/initialize",
          [addr0, BLOCK_HEIGHT_WINDOW],
          { privateKey: pk0 },
        );
        await expectConfirmed(freezelistInit);

        const initExec = await CompliantToken.initialize(
          AleoUtils.accounts[0],
          NAME,
          SYMBOL,
          DECIMALS,
          MAX_SUPPLY,
          addr0,
        );
        await expectConfirmed(initExec);

        // Grant admin both MANAGER_ROLE (8) and MINTER_ROLE (1) = 9
        const updateRoleExec = await CompliantToken.updateRole(AleoUtils.accounts[0], addr0, "9u16");
        await expectConfirmed(updateRoleExec);

        const mintExec = await CompliantToken.mintPublic(AleoUtils.accounts[0], addr0, "10000u128");
        await expectConfirmed(mintExec);
      }
    } catch (e) {
      await AleoUtils.stopDevnode();
      throw e;
    }
    process.stdout.write(`compliant-token-template.test.js beforeAll: ${Date.now() - start}ms\n`);
  });

  afterAll(async () => {
    await AleoUtils.stopDevnode();
  });

  test("initialize (negative): rejects second call", async () => {
    if (!compliantTokenDeployed) return;
    await CompliantToken.initialize(
      AleoUtils.accounts[0],
      NAME,
      SYMBOL,
      DECIMALS,
      MAX_SUPPLY,
      addr0,
      { expectRejection: true },
    );
  });

  test("transfer_public (positive): moves balance between users", async () => {
    if (!compliantTokenDeployed) return;
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const exec = await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "200u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(before0 - after0).toBe(200n);
    expect(after1 - before1).toBe(200n);
  });

  test("transfer_public (negative): insufficient balance rejects", async () => {
    if (!compliantTokenDeployed) return;
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "999999999999u128", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("approve_public (positive): sets allowance", async () => {
    if (!compliantTokenDeployed) return;
    const exec = await CompliantToken.approvePublic(AleoUtils.accounts[0], addr1, "500u128");
    await expectConfirmed(exec);
  });

  test("unapprove_public (positive): decreases allowance", async () => {
    if (!compliantTokenDeployed) return;
    const exec = await CompliantToken.unapprovePublic(AleoUtils.accounts[0], addr1, "100u128");
    await expectConfirmed(exec);
  });

  test("transfer_from_public (positive): spender transfers with allowance", async () => {
    if (!compliantTokenDeployed) return;
    await expectConfirmed(
      await CompliantToken.approvePublic(AleoUtils.accounts[0], addr1, "300u128"),
    );

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const exec = await CompliantToken.transferFromPublic(
      AleoUtils.accounts[1],
      addr0,
      addr1,
      "150u128",
    );
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(before0 - after0).toBe(150n);
    expect(after1 - before1).toBe(150n);
  });

  test("transfer_public_to_private (positive): debits sender, outputs Token", async () => {
    if (!compliantTokenDeployed) return;
    const before0 = await bal(addr0);
    const exec = await CompliantToken.transferPublicToPrivate(AleoUtils.accounts[0], addr0, "50u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(50n);
  });

  test("transfer_from_public_to_private (positive): spender converts owner public to recipient private", async () => {
    if (!compliantTokenDeployed) return;
    await expectConfirmed(
      await CompliantToken.approvePublic(AleoUtils.accounts[0], addr1, "100u128"),
    );

    const before0 = await bal(addr0);
    const exec = await CompliantToken.transferFromPublicToPrivate(
      AleoUtils.accounts[1],
      addr0,
      addr1,
      "25u128",
    );
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(25n);
  });

  test("shield (positive): debits caller, outputs Token", async () => {
    if (!compliantTokenDeployed) return;
    const before0 = await bal(addr0);
    const exec = await CompliantToken.shield(AleoUtils.accounts[0], "30u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(30n);
  });

  test("shield (negative): over-balance rejects", async () => {
    if (!compliantTokenDeployed) return;
    const before0 = await bal(addr0);
    await CompliantToken.shield(AleoUtils.accounts[0], "999999999999u128", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    expect(after0).toBe(before0);
  });
});
