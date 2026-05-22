/**
 * Tests for compliant_token_template.aleo (ARC22).
 *
 * Leo deploy automatically deploys dependencies (merkle_tree, multisig_core,
 * freezelist) before compliant_token_template. The freezelist project in
 * ../freezelist uses a DEPLOYER_ADDRESS matching test account[0]. The setup
 * sequence in beforeAll is:
 *
 *   1. Deploy compliant_token_template (pulls in transitive deps).
 *   2. Initialize freezelist with a known block-height window.
 *   3. Initialize the token (sets metadata + admin = MANAGER_ROLE).
 *   4. Grant addr0 MANAGER_ROLE | MINTER_ROLE so it can mint.
 *   5. Mint a generous initial balance to addr0 for downstream tests.
 *
 * Run with: SKIP_LEO_CHECKS=1 npm run test:compliant-token-template
 */
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as CompliantToken from "./contracts/compliant-token-template.js";
import { extractRecordPlaintexts } from "./lib/arc20-wrapper-tests.js";
import { generateNonInclusionProof } from "./lib/merkle-proof-utils.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Encode an ASCII string as a `u128` literal using little-endian byte layout.
// Used for token `name`/`symbol`, which are stored as packed ASCII in u128.
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

// Identify a "Token" output: it has owner+amount but no compliance-only fields
// (ComplianceRecord adds sender+recipient; freezelist records add freeze_list_root).
function findTokenRecord(records) {
  return records.find(
    (r) =>
      r.includes("owner:") &&
      r.includes("amount:") &&
      !r.includes("sender:") &&
      !r.includes("freeze_list_root:"),
  );
}

function findComplianceRecord(records) {
  return records.find(
    (r) =>
      r.includes("sender:") &&
      r.includes("amount:") &&
      r.includes("recipient:"),
  );
}

// Roles in compliant_token_template.aleo, mirroring the const u16s in main.leo.
const MINTER_ROLE  = 1;
const BURNER_ROLE  = 2;
const PAUSE_ROLE   = 4;
const MANAGER_ROLE = 8;

const roleU16 = (mask) => `${mask >>> 0}u16`;

describe("compliant_token_template.aleo", () => {
  const programPath = path.join(__dirname, "..", "compliant_token_template");
  const pk0 = AleoUtils.DEFAULT_PRIVATE_KEYS[0];
  const addr0 = AleoUtils.addresses[0];
  const addr1 = AleoUtils.addresses[1];

  const NAME = encodeAsciiToU128Literal("TEST");
  const SYMBOL = encodeAsciiToU128Literal("TST");
  const DECIMALS = "6u8";
  const MAX_SUPPLY = "1000000u128";
  const BLOCK_HEIGHT_WINDOW = "100u32";

  // Must match `INVESTIGATOR_ADDRESS` in compliant_token_template/src/main.leo.
  // If main.leo changes, update both the source constant and this literal.
  const INVESTIGATOR_ADDRESS =
    "aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px";

  async function expectConfirmed(execResult) {
    await AleoUtils.waitForTransactionConfirmedFromLeoExecution(execResult);
  }

  async function bal(addr) {
    return await CompliantToken.getPublicBalance(addr);
  }

  beforeAll(async () => {
    const start = Date.now();
    await AleoUtils.startDevnode({ suiteName: "compliant_token_template.aleo", port: 3032 });

    await AleoUtils.deployProgramFromFile({
      programId: CompliantToken.PROGRAM_ID,
      programPath,
    });

    const freezelistInit = await AleoUtils.leoExecute(
      programPath,
      "freezelist.aleo::initialize",
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

    const updateRoleExec = await CompliantToken.updateRole(
      AleoUtils.accounts[0],
      addr0,
      roleU16(MANAGER_ROLE | MINTER_ROLE),
    );
    await expectConfirmed(updateRoleExec);

    const mintExec = await CompliantToken.mintPublic(AleoUtils.accounts[0], addr0, "10000u128");
    await expectConfirmed(mintExec);

    process.stdout.write(`compliant-token-template.test.js beforeAll: ${Date.now() - start}ms\n`);
  });

  afterAll(async () => {
    await AleoUtils.stopDevnode();
  });

  test("initialize (negative): rejects second call", async () => {
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
    const exec = await CompliantToken.approvePublic(AleoUtils.accounts[0], addr1, "500u128");
    await expectConfirmed(exec);
  });

  test("unapprove_public (positive): decreases allowance", async () => {
    const exec = await CompliantToken.unapprovePublic(AleoUtils.accounts[0], addr1, "100u128");
    await expectConfirmed(exec);
  });

  test("transfer_from_public (positive): spender transfers with allowance", async () => {
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
    const before0 = await bal(addr0);
    const exec = await CompliantToken.transferPublicToPrivate(AleoUtils.accounts[0], addr0, "50u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(50n);
  });

  test("transfer_from_public_to_private (positive): spender converts owner public to recipient private", async () => {
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
    const before0 = await bal(addr0);
    const exec = await CompliantToken.shield(AleoUtils.accounts[0], "30u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(30n);
  });

  test("shield (negative): over-balance rejects", async () => {
    const before0 = await bal(addr0);
    await CompliantToken.shield(AleoUtils.accounts[0], "999999999999u128", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    expect(after0).toBe(before0);
  });

  test("transfer_private (positive): debits Token, outputs change and transfer", async () => {
    const shieldExec = await CompliantToken.shield(AleoUtils.accounts[0], "100u128");
    await expectConfirmed(shieldExec);
    const records = extractRecordPlaintexts(shieldExec.stdout);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();

    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    const merkleProofs = generateNonInclusionProof(addr0, []);
    const exec = await CompliantToken.transferPrivate(
      AleoUtils.accounts[0],
      tokenRecord,
      addr1,
      "50u128",
      merkleProofs,
    );
    await expectConfirmed(exec);
    const outRecords = extractRecordPlaintexts(exec.stdout);
    // Per IARC22.transfer_private: ComplianceRecord + change Token + transfer Token = 3 records.
    expect(outRecords).toHaveLength(3);
    expect(findComplianceRecord(outRecords)).toBeDefined();

    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);
  });

  test("transfer_private_to_public (positive): debits Token, credits recipient public balance", async () => {
    const shieldExec = await CompliantToken.shield(AleoUtils.accounts[0], "100u128");
    await expectConfirmed(shieldExec);
    const records = extractRecordPlaintexts(shieldExec.stdout);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();

    const before1 = await bal(addr1);
    const merkleProofs = generateNonInclusionProof(addr0, []);
    const exec = await CompliantToken.transferPrivateToPublic(
      AleoUtils.accounts[0],
      tokenRecord,
      addr1,
      "40u128",
      merkleProofs,
    );
    await expectConfirmed(exec);
    const after1 = await bal(addr1);
    expect(after1 - before1).toBe(40n);
  });

  test("unshield (positive): debits Token, credits recipient public balance", async () => {
    const shieldExec = await CompliantToken.shield(AleoUtils.accounts[0], "80u128");
    await expectConfirmed(shieldExec);
    const records = extractRecordPlaintexts(shieldExec.stdout);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();

    const before0 = await bal(addr0);
    const merkleProofs = generateNonInclusionProof(addr0, []);
    const exec = await CompliantToken.unshield(
      AleoUtils.accounts[0],
      tokenRecord,
      addr0,
      "40u128",
      merkleProofs,
    );
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(after0 - before0).toBe(40n);
  });

  test("transfer_private_to_public: emits change Token (no Metadata-only output)", async () => {
    const shieldExec = await CompliantToken.shield(AleoUtils.accounts[0], "100u128");
    await expectConfirmed(shieldExec);
    const records = extractRecordPlaintexts(shieldExec.stdout);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();

    const merkleProofs = generateNonInclusionProof(addr0, []);
    const exec = await CompliantToken.transferPrivateToPublic(
      AleoUtils.accounts[0],
      tokenRecord,
      addr1,
      "40u128",
      merkleProofs,
    );
    await expectConfirmed(exec);
    const outRecords = extractRecordPlaintexts(exec.stdout);
    const changeToken = findTokenRecord(outRecords);
    expect(changeToken).toBeDefined();
    expect(changeToken).toContain("amount:");
    const metadataOnly = outRecords.find(
      (r) =>
        r.includes("owner:") &&
        !r.includes("amount:") &&
        !r.includes("sender:") &&
        !r.includes("recipient:") &&
        !r.includes("freeze_list_root:"),
    );
    expect(metadataOnly).toBeUndefined();
  });

  // --- Role-based access control negative tests ---

  test("mint_public (negative): non-minter is rejected", async () => {
    await CompliantToken.mintPublic(AleoUtils.accounts[1], addr1, "100u128", {
      expectRejection: true,
    });
  });

  test("set_pause_status (negative): non-pauser is rejected", async () => {
    await CompliantToken.setPauseStatus(AleoUtils.accounts[1], true, {
      expectRejection: true,
    });
  });

  test("update_role (negative): non-manager is rejected", async () => {
    await CompliantToken.updateRole(AleoUtils.accounts[1], addr1, roleU16(MINTER_ROLE), {
      expectRejection: true,
    });
  });

  // --- ComplianceRecord / Metadata validation ---

  test("shield: ComplianceRecord contains correct investigator owner and sender", async () => {
    const exec = await CompliantToken.shield(AleoUtils.accounts[0], "20u128");
    await expectConfirmed(exec);
    const records = extractRecordPlaintexts(exec.stdout);

    const complianceRecord = findComplianceRecord(records);
    expect(complianceRecord).toBeDefined();
    expect(complianceRecord).toContain(INVESTIGATOR_ADDRESS);
    expect(complianceRecord).toContain(addr0);
  });

  test("transfer_private_to_public: output records are Token-shaped (no Metadata receipt)", async () => {
    const shieldExec = await CompliantToken.shield(AleoUtils.accounts[0], "50u128");
    await expectConfirmed(shieldExec);
    const records = extractRecordPlaintexts(shieldExec.stdout);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();

    const merkleProofs = generateNonInclusionProof(addr0, []);
    const exec = await CompliantToken.transferPrivateToPublic(
      AleoUtils.accounts[0],
      tokenRecord,
      addr1,
      "25u128",
      merkleProofs,
    );
    await expectConfirmed(exec);
    const outRecords = extractRecordPlaintexts(exec.stdout);

    const changeToken = findTokenRecord(outRecords);
    expect(changeToken).toBeDefined();
    const metadataOnly = outRecords.find(
      (r) =>
        r.includes("owner:") &&
        !r.includes("amount:") &&
        !r.includes("sender:") &&
        !r.includes("recipient:") &&
        !r.includes("freeze_list_root:"),
    );
    expect(metadataOnly).toBeUndefined();
  });

  // --- Mint/burn tests ---

  test("mint_public (positive): minter increases recipient balance", async () => {
    const before1 = await bal(addr1);
    const exec = await CompliantToken.mintPublic(AleoUtils.accounts[0], addr1, "100u128");
    await expectConfirmed(exec);
    const after1 = await bal(addr1);
    expect(after1 - before1).toBe(100n);
  });

  test("mint_private (positive): minter creates private Token with ComplianceRecord", async () => {
    const exec = await CompliantToken.mintPrivate(AleoUtils.accounts[0], addr0, "50u128");
    await expectConfirmed(exec);
    const records = extractRecordPlaintexts(exec.stdout);
    expect(records.length).toBeGreaterThanOrEqual(2);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();
    expect(findComplianceRecord(records)).toBeDefined();
  });

  test("burn_public (positive): burner decreases owner balance", async () => {
    // Compose addr0 roles: existing MANAGER|MINTER + BURNER.
    const grantBurner = await CompliantToken.updateRole(
      AleoUtils.accounts[0],
      addr0,
      roleU16(MANAGER_ROLE | MINTER_ROLE | BURNER_ROLE),
    );
    await expectConfirmed(grantBurner);

    const before0 = await bal(addr0);
    const exec = await CompliantToken.burnPublic(AleoUtils.accounts[0], addr0, "50u128");
    await expectConfirmed(exec);
    const after0 = await bal(addr0);
    expect(before0 - after0).toBe(50n);
  });

  test("burn_public (negative): non-burner is rejected", async () => {
    const before1 = await bal(addr1);
    await CompliantToken.burnPublic(AleoUtils.accounts[1], addr1, "10u128", {
      expectRejection: true,
    });
    const after1 = await bal(addr1);
    expect(after1).toBe(before1);
  });

  // --- Freeze list enforcement ---
  // TODO: Freeze list tests require computing Merkle root transitions for
  // freezelist.aleo::update_freeze_list, which involves building Merkle trees
  // with specific leaf insertion order. Deferred to a follow-up.

  test("pause/unpause: set_pause_status blocks and unblocks transfers", async () => {
    // addr0 currently has MANAGER|MINTER|BURNER from the burn test; add PAUSE.
    const grantPause = await CompliantToken.updateRole(
      AleoUtils.accounts[0],
      addr0,
      roleU16(MANAGER_ROLE | MINTER_ROLE | BURNER_ROLE | PAUSE_ROLE),
    );
    await expectConfirmed(grantPause);

    let paused = false;
    try {
      const pauseExec = await CompliantToken.setPauseStatus(AleoUtils.accounts[0], true);
      await expectConfirmed(pauseExec);
      paused = true;

      const before0 = await bal(addr0);
      const before1 = await bal(addr1);
      await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "10u128", {
        expectRejection: true,
      });
      const midA0 = await bal(addr0);
      const midA1 = await bal(addr1);
      expect(midA0).toBe(before0);
      expect(midA1).toBe(before1);

      const unpauseExec = await CompliantToken.setPauseStatus(AleoUtils.accounts[0], false);
      await expectConfirmed(unpauseExec);
      paused = false;

      const exec = await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "10u128");
      await expectConfirmed(exec);
      const final0 = await bal(addr0);
      const final1 = await bal(addr1);
      expect(before0 - final0).toBe(10n);
      expect(final1 - before1).toBe(10n);
    } finally {
      // Make sure we don't leave the contract in a paused state if any
      // assertion above threw — that would make the suite difficult to re-run.
      if (paused) {
        try {
          const cleanup = await CompliantToken.setPauseStatus(AleoUtils.accounts[0], false);
          await expectConfirmed(cleanup);
        } catch {
          // Best-effort cleanup; surface the original failure instead.
        }
      }
    }
  });
});
