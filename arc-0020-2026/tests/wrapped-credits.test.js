import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as WrappedCredits from "./contracts/wrapped-credits.js";
import * as DummyExchange from "./contracts/dummy-exchange.js";
import { registerArc20WrapperTests, extractRecordPlaintexts } from "./lib/arc20-wrapper-tests.js";
import { Address } from "@provablehq/sdk";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("wrapped_credits.aleo", () => {
  const programPath = path.join(__dirname, "..", "wrapped_credits");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  // TODO: awaiting confirmation is already natively supported in leo execute right?
  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  async function bal(addr) {
    return await WrappedCredits.getPublicBalance(addr);
  }

  const exchangeAddress = Address.fromProgramId(DummyExchange.PROGRAM_ID).to_string();
  let exchangeDeployed = false;

  beforeAll(async () => {
    const start = Date.now();
    await AleoUtils.startDevnode({ suiteName: "wrapped_credits.aleo", port: 3030 });

    await AleoUtils.deployProgramFromFile({
      programId: WrappedCredits.PROGRAM_ID,
      programPath,
    });

    const exchangePath = path.join(__dirname, "..", "dummy_exchange");
    await AleoUtils.deployProgramFromFile({
      programId: DummyExchange.PROGRAM_ID,
      programPath: exchangePath,
      skip: ["wrapped_credits"],
    });

    // Ensure addr0 has an initial wrapped balance for tests.
    const b0 = await bal(addr0);
    if (b0 < 2000n) {
      const dep = await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "5000u64");
      await expectConfirmed(dep);
      const b1 = await bal(addr0);
      expect(b1 - b0).toBe(5000n);
    }
    process.stdout.write(`wrapped-credits.test.js beforeAll: ${Date.now() - start}ms\n`);
  });

  afterAll(async () => {
    await AleoUtils.stopDevnode();
  });

  test("deposit_credits_public (positive and negative test): increases only depositor balance", async () => {
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const exec = await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "1000u64");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0 - before0).toBe(1000n);
    expect(after1 - before1).toBe(0n);
  });

  test("deposit_credits_private (positive): accepts a credits record and returns a Token", async () => {
    // Create a credits.aleo/credits record for addr0.
    const creditsExec = await AleoUtils.leoExecute(
      programPath,
      "credits.aleo/transfer_public_to_private",
      [addr0, "500u64"],
      { privateKey: pk0 },
    );
    await expectConfirmed(creditsExec);
    const creditsRecords = extractRecordPlaintexts(creditsExec.stdout);
    expect(creditsRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const dep = await AleoUtils.leoExecute(
      programPath,
      "deposit_credits_private",
      [creditsRecords[0], "200u64"],
      { privateKey: pk0 },
    );
    await expectConfirmed(dep);
    const outRecords = extractRecordPlaintexts(dep.stdout);
    // Expect at least change credits record + minted Token.
    expect(outRecords.length).toBeGreaterThanOrEqual(2);

    // This transition mints a private Token output and should not touch public balances mapping.
    const after0 = await bal(addr0);
    expect(after0 - before0).toBe(0n);
  });

  test("deposit_credits_private (negative): rejects when amount exceeds record value", async () => {
    const creditsExec = await AleoUtils.leoExecute(
      programPath,
      "credits.aleo/transfer_public_to_private",
      [addr0, "50u64"],
      { privateKey: pk0 },
    );
    const creditsRecords = extractRecordPlaintexts(creditsExec.stdout);
    expect(creditsRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await AleoUtils.leoExecute(
      programPath,
      "deposit_credits_private",
      [creditsRecords[0], "100u64"],
      { privateKey: pk0, expectRejection: true },
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("withdraw_credits_public (positive): decreases caller balance", async () => {
    const before0 = await bal(addr0);
    const exec = await WrappedCredits.withdrawCreditsPublic(AleoUtils.accounts[0], "250u64");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(250n);
  });

  test("withdraw_credits_public (negative): withdrawing too much rejects and balance unchanged", async () => {
    const before0 = await bal(addr0);
    await WrappedCredits.withdrawCreditsPublic(AleoUtils.accounts[0], "999999999999u64", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    expect(after0).toBe(before0);
  });

  test("withdraw_credits_public_signer (positive): decreases signer balance", async () => {
    const before0 = await bal(addr0);
    const exec = await WrappedCredits.withdrawCreditsPublicSigner(AleoUtils.accounts[0], "123u64");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(123n);
  });

  test("withdraw_credits_public_signer (negative): withdrawing too much rejects", async () => {
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await WrappedCredits.withdrawCreditsPublicSigner(AleoUtils.accounts[0], "999999999999u64", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("withdraw_credits_private (positive): converts Token amount into private credits record", async () => {
    // Shield to create token owned by signer.
    const mint = await AleoUtils.leoExecute(
      programPath,
      "shield",
      ["70u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(mint);
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const res = await AleoUtils.leoExecute(
      programPath,
      "withdraw_credits_private",
      [tokenRecords[0], "20u64"],
      { privateKey: pk0 },
    );
    await expectConfirmed(res);
    const out = extractRecordPlaintexts(res.stdout);
    // credits record + change token
    expect(out.length).toBeGreaterThanOrEqual(2);

    // Private withdraw does not touch public balances mapping.
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("unshield (positive): converts Token amount into private credits record", async () => {
    const mint = await AleoUtils.leoExecute(programPath, "shield", ["50u128"], { privateKey: pk0 });
    await expectConfirmed(mint);
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const res = await WrappedCredits.unshield(AleoUtils.accounts[0], tokenRecords[0], "20u128");
    await expectConfirmed(res);
    const out = extractRecordPlaintexts(res.stdout);
    expect(out.length).toBeGreaterThanOrEqual(2);
    const after0 = await bal(addr0);
    expect(after0).toBe(before0);
  });

  test("withdraw_credits_private (negative): rejects when amount exceeds Token amount", async () => {
    const mint = await AleoUtils.leoExecute(
      programPath,
      "shield",
      ["10u128"],
      { privateKey: pk0 },
    );
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await AleoUtils.leoExecute(
      programPath,
      "withdraw_credits_private",
      [tokenRecords[0], "100u64"],
      { privateKey: pk0, expectRejection: true },
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_public_as_signer (positive): debits signer and credits receiver", async () => {
    // Ensure signer has enough.
    const b0 = await bal(addr0);
    if (b0 < 100n) {
      const topup = await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "500u64");
      await expectConfirmed(topup);
    }

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const exec = await WrappedCredits.transferPublicAsSigner(AleoUtils.accounts[0], addr1, "40u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(before0 - after0).toBe(40n);
    expect(after1 - before1).toBe(40n);
  });

  test("dummy_exchange: spendable allowance via transfer_from", async () => {
    if (!exchangeDeployed) {
      console.warn("Skipping dummy_exchange test: program not deployed");
      return;
    }
    const amount = "75u128";
    const execApprovePublic = await WrappedCredits.approvePublic(AleoUtils.accounts[0], exchangeAddress, amount);
    await expectConfirmed(execApprovePublic);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const execTransferFrom = await DummyExchange.transferFrom(AleoUtils.accounts[0], addr0, addr1, amount);
    await expectConfirmed(execTransferFrom);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(before0 - after0).toBe(75n);
    expect(after1 - before1).toBe(75n);
  });

  test("transfer_public_as_signer (negative): insufficient balance rejects", async () => {
    const before1 = await bal(addr1);
    if (before1 === 0n) {
      await expectConfirmed(await WrappedCredits.transferPublic(AleoUtils.accounts[0], addr1, "1u128"));
    }
    const amount = (await bal(addr1)) + 1n;
    const before0 = await bal(addr0);
    await WrappedCredits.transferPublicAsSigner(AleoUtils.accounts[1], addr0, `${amount}u128`, {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  registerArc20WrapperTests({
    Wrapper: WrappedCredits,
    accounts: AleoUtils.accounts,
    addresses: AleoUtils.addresses,
    expectConfirmed,
    ensureBalance: async () => {
      const b = await bal(addr0);
      if (b < 500n) {
        throw new Error("Insufficient balance");
        //   NOTE: don't deposit more by default because this creates a lot of overhead.
        //   const dep = await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "500u64");
        //   await expectConfirmed(dep);
      }
    },
  });
});

