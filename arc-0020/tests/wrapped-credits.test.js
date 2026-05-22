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
  const exchangePath = path.join(__dirname, "..", "dummy_exchange");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  async function bal(addr) {
    return await WrappedCredits.getPublicBalance(addr);
  }

  const exchangeAddress = Address.fromProgramId(DummyExchange.PROGRAM_ID).to_string();
  const wrappedCreditsTokenId = DummyExchange.programNameToTokenIdField("wrapped_credits");

  beforeAll(async () => {
    const start = Date.now();
    await AleoUtils.startDevnode({ suiteName: "wrapped_credits.aleo", port: 3030 });

    await AleoUtils.deployProgramFromFile({
      programId: WrappedCredits.PROGRAM_ID,
      programPath,
    });

    await AleoUtils.deployProgramFromFile({
      programId: DummyExchange.PROGRAM_ID,
      programPath: exchangePath,
      skip: ["wrapped_credits"],
    });

    // Ensure addr0 has enough wrapped balance for the rest of the suite.
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

  test("deposit_credits_public_signer (positive): increases only depositor balance", async () => {
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
    const creditsExec = await AleoUtils.leoExecute(
      programPath,
      "credits.aleo::transfer_public_to_private",
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

    // Private deposit mints a Token output and must not touch the public balances mapping.
    const after0 = await bal(addr0);
    expect(after0 - before0).toBe(0n);
  });

  test("deposit_credits_private (negative): rejects when amount exceeds record value", async () => {
    const creditsExec = await AleoUtils.leoExecute(
      programPath,
      "credits.aleo::transfer_public_to_private",
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
    const mint = await WrappedCredits.shield(AleoUtils.accounts[0], "70u128");
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

    // Private withdraw does not touch the public balances mapping.
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("unshield (positive): converts a private Token back to the owner's public balance", async () => {
    const mint = await WrappedCredits.shield(AleoUtils.accounts[0], "50u128");
    await expectConfirmed(mint);
    const tokenRecords = extractRecordPlaintexts(mint.stdout);
    expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

    const before0 = await bal(addr0);
    const res = await WrappedCredits.unshield(AleoUtils.accounts[0], tokenRecords[0], "20u128");
    await expectConfirmed(res);
    const out = extractRecordPlaintexts(res.stdout);
    // Single change Token record; the legacy "zero token" was removed.
    expect(out.length).toBe(1);
    const after0 = await bal(addr0);
    expect(after0 - before0).toBe(20n);
  });

  test("withdraw_credits_private (negative): rejects when amount exceeds Token amount", async () => {
    const mint = await WrappedCredits.shield(AleoUtils.accounts[0], "10u128");
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

  // KNOWN-FAILING: dummy_exchange.aleo uses `_dynamic_call` to invoke the
  // wrapped_credits ARC20 surface (`transfer_from_public` / `transfer_public`).
  // With Leo 4.0.2, dynamic calls coerce every argument to `*.private`, but
  // those wrapped_credits transitions expect `address.public` for owner /
  // recipient. The on-chain execution verifier rejects the broadcast with:
  //   "Input 0 in dynamic call to transfer_from_public should be of type
  //    address.private, found: public"
  //
  // Both tests in this block are kept (skipped) so the dynamic-dispatch flows
  // are exercised in code, and so the test bodies are ready to re-enable once
  // Leo supports public-mode arguments through `_dynamic_call` (or once the
  // dummy_exchange Leo source is reworked accordingly).
  describe.skip("dummy_exchange (dynamic dispatch into wrapped_credits)", () => {
    test("transfer_from: spender pulls from owner via allowance", async () => {
      const amount = "75u128";
      const execApprovePublic = await WrappedCredits.approvePublic(
        AleoUtils.accounts[0],
        exchangeAddress,
        amount,
      );
      await expectConfirmed(execApprovePublic);

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      const execTransferFrom = await DummyExchange.transferFrom(
        AleoUtils.accounts[0],
        wrappedCreditsTokenId,
        addr0,
        addr1,
        amount,
        { with: ["wrapped_credits.aleo"] },
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
      const amountIn = "75u128";
      const amountOut = "50u128";

      // Pre-fund the exchange so it can pay out `amount_out` on the push leg.
      await expectConfirmed(
        await WrappedCredits.transferPublic(
          AleoUtils.accounts[0],
          exchangeAddress,
          amountOut,
        ),
      );
      // Approve the exchange to pull `amount_in` from the signer.
      await expectConfirmed(
        await WrappedCredits.approvePublic(
          AleoUtils.accounts[0],
          exchangeAddress,
          amountIn,
        ),
      );

      const before0 = await bal(addr0);
      const beforeExchange = await bal(exchangeAddress);
      const execSwap = await DummyExchange.swap(
        AleoUtils.accounts[0],
        wrappedCreditsTokenId,
        wrappedCreditsTokenId,
        amountIn,
        amountOut,
        { with: ["wrapped_credits.aleo"] },
      );
      await expectConfirmed(execSwap);
      const after0 = await bal(addr0);
      const afterExchange = await bal(exchangeAddress);

      // Net effect on the signer: -amountIn (paid in) + amountOut (received).
      expect(before0 - after0).toBe(75n - 50n);
      // Net effect on the exchange: mirror image.
      expect(afterExchange - beforeExchange).toBe(75n - 50n);
    });
  });

  test("transfer_public_as_signer (negative): insufficient balance rejects", async () => {
    // Make sure addr1 has at least one token so we can compute "balance + 1".
    const before1 = await bal(addr1);
    if (before1 === 0n) {
      await expectConfirmed(await WrappedCredits.transferPublic(AleoUtils.accounts[0], addr1, "1u128"));
    }

    const balance1 = await bal(addr1);
    const amount = balance1 + 1n;
    const before0 = await bal(addr0);

    await WrappedCredits.transferPublicAsSigner(AleoUtils.accounts[1], addr0, `${amount}u128`, {
      expectRejection: true,
    });

    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(balance1);
  });

  registerArc20WrapperTests({
    Wrapper: WrappedCredits,
    accounts: AleoUtils.accounts,
    addresses: AleoUtils.addresses,
    expectConfirmed,
    ensureBalance: async () => {
      const b = await bal(addr0);
      if (b < 500n) {
        // Avoid silently topping up: each deposit takes ~1 block and adds noise to balance assertions.
        // Tests are ordered so previous successful tests should keep addr0 funded.
        throw new Error(
          `wrapped_credits: addr0 balance is ${b} (< 500). A previous test likely failed and drained the balance.`,
        );
      }
    },
  });
});
