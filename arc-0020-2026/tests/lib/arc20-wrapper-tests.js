/**
 * Shared ARC20 wrapper test logic. Both wrapped_credits and wrapped_token_registry
 * implement the same ARC20 interface; only deposit/withdraw differ.
 *
 * @param {Object} config
 * @param {Object} config.Wrapper - Contract module (WrappedCredits or WrappedTokenRegistry)
 * @param {Object[]} config.accounts - AleoUtils.accounts
 * @param {string[]} config.addresses - AleoUtils.addresses
 * @param {Function} config.expectConfirmed - (execResult) => Promise
 * @param {Function} config.expectRejected - (promise) => Promise
 * @param {Function} [config.ensureBalance] - async () => ensure addr0 has enough balance before tests
 */
export function registerArc20WrapperTests(config) {
  const { Wrapper, accounts, addresses, expectConfirmed, expectRejected, ensureBalance } = config;
  const addr0 = addresses[0];
  const addr1 = addresses[1];
  const addr2 = addresses[2];
  const addr3 = addresses[3];

  function extractRecordPlaintexts(stdout) {
    const s = String(stdout || "");
    const blocks = [...s.matchAll(/•\s*\{\n[\s\S]*?\n\}/g)].map((m) =>
      String(m[0]).replace(/^\s*•\s*/m, "").trim(),
    );
    return blocks.filter((b) => b.includes("_nonce:") && b.includes("_version:"));
  }

  async function bal(addr) {
    return await Wrapper.getPublicBalance(addr);
  }

  describe("ARC20 interface (shared)", () => {
    beforeEach(async () => {
      if (ensureBalance) await ensureBalance();
    });

    test("transfer_public (positive): moves balances between users", async () => {
      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      const exec = await Wrapper.transferPublic(accounts[0], addr1, "321u128");
      await expectConfirmed(exec);
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(before0 - after0).toBe(321n);
      expect(after1 - before1).toBe(321n);
    });

    test("transfer_public (negative): insufficient balance rejects", async () => {
      const before1 = await bal(addr1);
      const amount = before1 + 1n;
      await expectRejected(Wrapper.transferPublic(accounts[1], addr0, `${amount}u128`));
      const after1 = await bal(addr1);
      expect(after1).toBe(before1);
    });

    test("shield (positive): outputs a Token and debits caller", async () => {
      const before0 = await bal(addr0);
      const exec = await Wrapper.shield(accounts[0], "400u128");
      await expectConfirmed(exec);
      const records = extractRecordPlaintexts(exec.stdout);
      expect(records.length).toBeGreaterThanOrEqual(1);
      const after0 = await bal(addr0);
      expect(before0 - after0).toBe(400n);
    });

    test("shield (negative): shielding too much rejects", async () => {
      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      await expectRejected(Wrapper.shield(accounts[0], "999999999999999999999999u128"));
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(after0).toBe(before0);
      expect(after1).toBe(before1);
    });

    test("transfer_private (positive): signer-owned Token can be split", async () => {
      const mint = await Wrapper.shield(accounts[0], "200u128");
      await expectConfirmed(mint);
      const tokenRecords = extractRecordPlaintexts(mint.stdout);
      expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      const split = await Wrapper.transferPrivate(accounts[0], tokenRecords[0], addr1, "50u128");
      await expectConfirmed(split);
      const out = extractRecordPlaintexts(split.stdout);
      expect(out.length).toBeGreaterThanOrEqual(2);

      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(after0).toBe(before0);
      expect(after1).toBe(before1);
    });

    test("transfer_private (negative): rejects if Token owner != signer", async () => {
      await expectConfirmed(await Wrapper.transferPublic(accounts[0], addr1, "100u128"));
      const shieldExec = await Wrapper.shield(accounts[1], "100u128");
      await expectConfirmed(shieldExec);
      const tokenRecords = extractRecordPlaintexts(shieldExec.stdout);
      expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      await expectRejected(
        Wrapper.transferPrivate(accounts[0], tokenRecords[0], addr0, "1u128"),
      );
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(after0).toBe(before0);
      expect(after1).toBe(before1);
    });

    test("transfer_private_to_public (positive): increases receiver public balance", async () => {
      const mint = await Wrapper.shield(accounts[0], "80u128");
      await expectConfirmed(mint);
      const tokenRecords = extractRecordPlaintexts(mint.stdout);
      expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

      const before1 = await bal(addr1);
      const res = await Wrapper.transferPrivateToPublic(accounts[0], tokenRecords[0], addr1, "30u128");
      await expectConfirmed(res);
      const out = extractRecordPlaintexts(res.stdout);
      expect(out.length).toBeGreaterThanOrEqual(1);
      const after1 = await bal(addr1);
      expect(after1 - before1).toBe(30n);
    });

    test("transfer_private_to_public (negative): rejects if Token owner != signer", async () => {
      await expectConfirmed(await Wrapper.transferPublic(accounts[0], addr1, "60u128"));
      const mint = await Wrapper.shield(accounts[1], "60u128");
      await expectConfirmed(mint);
      const tokenRecords = extractRecordPlaintexts(mint.stdout);
      expect(tokenRecords.length).toBeGreaterThanOrEqual(1);

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      await expectRejected(
        Wrapper.transferPrivateToPublic(accounts[0], tokenRecords[0], addr0, "1u128"),
      );
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(after0).toBe(before0);
      expect(after1).toBe(before1);
    });

    test("approve_public and transfer_from_public: spender can transfer on behalf of owner", async () => {
      await expectConfirmed(await Wrapper.approvePublic(accounts[0], addr1, "150u128"));

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      const execTransferFromPublic = await Wrapper.transferFromPublic(accounts[1], addr0, addr1, "100u128");
      await expectConfirmed(execTransferFromPublic);
      const after0 = await bal(addr0);
      const after1 = await bal(addr1);
      expect(before0 - after0).toBe(100n);
      expect(after1 - before1).toBe(100n);

      await expectConfirmed(await Wrapper.unapprovePublic(accounts[0], addr1, "50u128"));
    });

    test("transfer_from (negative): exceeds allowance rejects", async () => {
      await expectConfirmed(await Wrapper.approvePublic(accounts[0], addr3, "25u128"));

      const before0 = await bal(addr0);
      const before3 = await bal(addr3);
      const execTransferFromPublic = await Wrapper.transferFromPublic(accounts[3], addr0, addr3, "50u128");
      await expectRejected(execTransferFromPublic);
      const after0 = await bal(addr0);
      const after3 = await bal(addr3);
      expect(after0).toBe(before0);
      expect(after3).toBe(before3);
    });

    test("unapprove_public: decreases allowance", async () => {
      await expectConfirmed(await Wrapper.approvePublic(accounts[0], addr2, "200u128"));
      await expectConfirmed(await Wrapper.unapprovePublic(accounts[0], addr2, "100u128"));

      const before0 = await bal(addr0);
      const before2 = await bal(addr2);
      const execTransferFromPublic = await Wrapper.transferFromPublic(accounts[2], addr0, addr2, "100u128");
      await expectConfirmed(execTransferFromPublic);
      const after0 = await bal(addr0);
      const after2 = await bal(addr2);
      expect(before0 - after0).toBe(100n);
      expect(after2 - before2).toBe(100n);

      await expectRejected(
        Wrapper.transferFromPublic(accounts[2], addr0, addr2, "1u128"),
      );

      await expectConfirmed(await Wrapper.unapprovePublic(accounts[0], addr2, "100u128"));
    });
  });
}

export function extractRecordPlaintexts(stdout) {
  const s = String(stdout || "");
  const blocks = [...s.matchAll(/•\s*\{\n[\s\S]*?\n\}/g)].map((m) =>
    String(m[0]).replace(/^\s*•\s*/m, "").trim(),
  );
  return blocks.filter((b) => b.includes("_nonce:") && b.includes("_version:"));
}
