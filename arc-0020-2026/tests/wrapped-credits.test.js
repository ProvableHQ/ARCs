import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as WrappedCredits from "./contracts/wrapped-credits.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("wrapped_credits.aleo", () => {
  const programPath = path.join(__dirname, "..", "wrapped_credits");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  function extractRecordPlaintexts(stdout) {
    const s = String(stdout || "");
    const blocks = [...s.matchAll(/•\s*\{\n[\s\S]*?\n\}/g)].map((m) =>
      String(m[0]).replace(/^\s*•\s*/m, "").trim(),
    );
    // Heuristic: record outputs include _nonce/_version fields.
    return blocks.filter((b) => b.includes("_nonce:") && b.includes("_version:"));
  }

  async function bal(addr) {
    return await WrappedCredits.getPublicBalance(addr);
  }

  async function expectRejected(p) {
    await expect(p).rejects.toThrow(/Transaction rejected|failed \(code/i);
  }

  beforeAll(async () => {
    try {
      await AleoUtils.startDevnode();

      await AleoUtils.deployProgramFromFile({
        programId: WrappedCredits.PROGRAM_ID,
        programPath,
      });
    } catch (e) {
      await AleoUtils.stopDevnode();
      throw e;
    }

    // Ensure addr0 has an initial wrapped balance for tests.
    const b0 = await bal(addr0);
    if (b0 < 2000n) {
      await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "5000u64");
      const b1 = await bal(addr0);
      expect(b1 - b0).toBe(5000n);
    }
  });

  afterAll(async () => {
    await AleoUtils.stopDevnode();
  });

  test("deposit_credits_public (positive): increases depositor balance", async () => {
    const before0 = await bal(addr0);
    const exec = await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "1000u64");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(after0 - before0).toBe(1000n);
  });

  test("deposit_credits_public (negative): does not change other user's balance", async () => {
    const before1 = await bal(addr1);
    await WrappedCredits.depositCreditsPublic(AleoUtils.accounts[0], "200u64");
    const after1 = await bal(addr1);
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
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "deposit_credits_private",
        [creditsRecords[0], "100u64"],
        { privateKey: pk0 },
      ),
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
    await expectRejected(
      WrappedCredits.withdrawCreditsPublic(AleoUtils.accounts[0], "999999999999u64"),
    );
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
    await expectRejected(
      WrappedCredits.withdrawCreditsPublicSigner(AleoUtils.accounts[0], "999999999999u64"),
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_public (positive): moves balances between users", async () => {
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const exec = await WrappedCredits.transferPublic(AleoUtils.accounts[0], addr1, "321u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(before0 - after0).toBe(321n);
    expect(after1 - before1).toBe(321n);
  });

  test("transfer_public (negative): insufficient balance rejects and does not credit receiver", async () => {
    const before1 = await bal(addr1);
    const amount = before1 + 1n;
    await expectRejected(
      WrappedCredits.transferPublic(AleoUtils.accounts[1], addr0, `${amount}u128`),
    );
    const after1 = await bal(addr1);
    expect(after1).toBe(before1);
  });

  test("transfer_public_to_private (positive): outputs a Token and debits caller", async () => {
    const before0 = await bal(addr0);
    const exec = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr0, "400u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(exec);
    const records = extractRecordPlaintexts(exec.stdout);
    expect(records.length).toBeGreaterThanOrEqual(1);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(400n);
  });

  test("transfer_public_to_private (negative): transferring too much rejects", async () => {
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "transfer_public_to_private",
        [addr0, "999999999999999999999999u128"],
        { privateKey: pk0 },
      ),
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_private (positive): signer-owned Token can be split into change + new token", async () => {
    // Create a Token owned by signer.
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr0, "200u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(mint);
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const split = await AleoUtils.leoExecute(
      programPath,
      "transfer_private",
      [tokenRecords[0], addr1, "50u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(split);
    const out = extractRecordPlaintexts(split.stdout);
    // change token + new token
    expect(out.length).toBeGreaterThanOrEqual(2);

    // Purely private transfer: must not change public balances mapping.
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_private (negative): rejects if Token owner != signer", async () => {
    // Create a Token owned by addr1 (not signer account0).
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr1, "100u128"],
      { privateKey: pk0 },
    );
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "transfer_private",
        [tokenRecords[0], addr0, "1u128"],
        { privateKey: pk0 },
      ),
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_private_to_public (positive): increases receiver public balance", async () => {
    // Token owned by signer.
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr0, "80u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(mint);
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before1 = await bal(addr1);
    const res = await AleoUtils.leoExecute(
      programPath,
      "transfer_private_to_public",
      [tokenRecords[0], addr1, "30u128"],
      { privateKey: pk0 },
    );
    await expectConfirmed(res);
    const out = extractRecordPlaintexts(res.stdout);
    // change token output
    expect(out.length).toBeGreaterThanOrEqual(1);
    const after1 = await bal(addr1);
    expect(after1 - before1).toBe(30n);
  });

  test("transfer_private_to_public (negative): rejects if Token owner != signer", async () => {
    // Mint token owned by addr1.
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr1, "60u128"],
      { privateKey: pk0 },
    );
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "transfer_private_to_public",
        [tokenRecords[0], addr0, "1u128"],
        { privateKey: pk0 },
      ),
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("withdraw_credits_private (positive): converts Token amount into private credits record", async () => {
    // Mint token owned by signer.
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr0, "70u128"],
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

  test("withdraw_credits_private (negative): rejects when amount exceeds Token amount", async () => {
    const mint = await AleoUtils.leoExecute(
      programPath,
      "transfer_public_to_private",
      [addr0, "10u128"],
      { privateKey: pk0 },
    );
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await expectRejected(
      AleoUtils.leoExecute(
        programPath,
        "withdraw_credits_private",
        [tokenRecords[0], "100u64"],
        { privateKey: pk0 },
      ),
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

  test("transfer_public_as_signer (negative): insufficient balance rejects", async () => {
    const before1 = await bal(addr1);
    const amount = before1 + 1n;
    const before0 = await bal(addr0);
    await expectRejected(
      WrappedCredits.transferPublicAsSigner(AleoUtils.accounts[1], addr0, `${amount}u128`),
    );
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });
});

