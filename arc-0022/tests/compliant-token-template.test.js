/**
 * Tests for compliant_token_template.aleo (ARC20Compliant).
 *
 * Leo deploy automatically deploys dependencies (merkle_tree, multisig_core, freezelist)
 * before compliant_token_template. The freezelist project in ../freezelist uses
 * DEPLOYER_ADDRESS matching the test account. beforeAll initializes freezelist,
 * then compliant_token_template, grants MINTER_ROLE to admin, and mints to addr0.
 *
 * Run with: SKIP_LEO_CHECKS=1 npm run test:compliant-token-template
 */
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as AleoUtils from "./lib/aleo-test-utils.js";
import * as CompliantToken from "./contracts/compliant-token-template.js";
import { extractRecordPlaintexts } from "./lib/arc20-wrapper-tests.js";
import { generateNonInclusionProof } from "./lib/merkle-proof-utils.js";

/** Token has owner, amount; ComplianceRecord has sender, recipient; Metadata has owner only. */
function findTokenRecord(records) {
  return records.find(
    (r) => r.includes("owner:") && r.includes("amount:") && !r.includes("sender:") && !r.includes("freeze_list_root:"),
  );
}

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

  beforeAll(async () => {
    const start = Date.now();
    await AleoUtils.startDevnode({ suiteName: "compliant_token_template.aleo", port: 3032 });

      // const prevEndpoint = process.env.ENDPOINT;
      // process.env.ENDPOINT = AleoUtils.getNetworkUrl();
      await AleoUtils.deployProgramFromFile({
        programId: CompliantToken.PROGRAM_ID,
        programPath,
      });
      // process.env.ENDPOINT = prevEndpoint;

    // Initialize freezelist first (compliant_token_template reads from it).
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

    // Grant admin both MANAGER_ROLE (8) and MINTER_ROLE (1) = 9
    const updateRoleExec = await CompliantToken.updateRole(AleoUtils.accounts[0], addr0, "9u16");
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
    expect(outRecords.length).toBeGreaterThanOrEqual(2);
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

  test("transfer_private_to_public: returns Metadata record with investigator as owner", async () => {
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
    // Metadata record has owner but no amount, sender, or recipient fields
    const metadataRecord = outRecords.find(
      (r) => r.includes("owner:") && !r.includes("amount:") && !r.includes("sender:") && !r.includes("recipient:") && !r.includes("freeze_list_root:"),
    );
    expect(metadataRecord).toBeDefined();
    // Metadata owner should be the investigator address
    expect(metadataRecord).toContain("aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px");
  });

  // --- Step 6a: Role-based access control negative tests ---

  test("mint_public (negative): non-minter is rejected", async () => {
    // accounts[1] has no role — should be rejected
    await CompliantToken.mintPublic(AleoUtils.accounts[1], addr1, "100u128", {
      expectRejection: true,
    });
  });

  test("set_pause_status (negative): non-pauser is rejected", async () => {
    // accounts[1] has no role — should be rejected
    await CompliantToken.setPauseStatus(AleoUtils.accounts[1], true, {
      expectRejection: true,
    });
  });

  test("update_role (negative): non-manager is rejected", async () => {
    // accounts[1] has no role — should be rejected
    await CompliantToken.updateRole(AleoUtils.accounts[1], addr1, "1u16", {
      expectRejection: true,
    });
  });

  // --- Step 6b: ComplianceRecord / Metadata validation ---

  test("shield: ComplianceRecord contains correct investigator owner and sender", async () => {
    const exec = await CompliantToken.shield(AleoUtils.accounts[0], "20u128");
    await expectConfirmed(exec);
    const records = extractRecordPlaintexts(exec.stdout);

    // ComplianceRecord has owner (investigator), amount, sender, recipient
    const complianceRecord = records.find(
      (r) => r.includes("sender:") && r.includes("amount:") && r.includes("recipient:"),
    );
    expect(complianceRecord).toBeDefined();
    // Owner should be the investigator address
    expect(complianceRecord).toContain("aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px");
    // Sender should be addr0
    expect(complianceRecord).toContain(addr0);
  });

  test("transfer_private_to_public: Metadata record has no sender field", async () => {
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

    // Metadata record has owner only -- no sender, amount, or recipient
    const metadataRecord = outRecords.find(
      (r) => r.includes("owner:") && !r.includes("amount:") && !r.includes("sender:") && !r.includes("recipient:") && !r.includes("freeze_list_root:"),
    );
    expect(metadataRecord).toBeDefined();
    expect(metadataRecord).toContain("aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px");
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
    // Should output a ComplianceRecord and a Token
    expect(records.length).toBeGreaterThanOrEqual(2);
    const tokenRecord = findTokenRecord(records);
    expect(tokenRecord).toBeDefined();
  });

  test("burn_public (positive): burner decreases owner balance", async () => {
    // Grant BURNER_ROLE (2) to addr0 — addr0 has MANAGER(8)+MINTER(1)=9, add BURNER: 9|2=11
    const grantBurner = await CompliantToken.updateRole(AleoUtils.accounts[0], addr0, "11u16");
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
    // Grant PAUSE_ROLE (4) to addr0 — addr0 already has MANAGER_ROLE (8) + MINTER_ROLE (1) = 9
    // Need to add PAUSE_ROLE: 9 | 4 = 13
    const grantPause = await CompliantToken.updateRole(AleoUtils.accounts[0], addr0, "13u16");
    await expectConfirmed(grantPause);

    // Pause the token
    const pauseExec = await CompliantToken.setPauseStatus(AleoUtils.accounts[0], true);
    await expectConfirmed(pauseExec);

    // Transfer should be rejected while paused
    const before0 = await bal(addr0);
    const before1 = await bal(addr1);
    await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "10u128", {
      expectRejection: true,
    });
    const after0 = await bal(addr0);
    const after1 = await bal(addr1);
    expect(after0).toBe(before0);
    expect(after1).toBe(before1);

    // Unpause
    const unpauseExec = await CompliantToken.setPauseStatus(AleoUtils.accounts[0], false);
    await expectConfirmed(unpauseExec);

    // Transfer should succeed after unpause
    const exec = await CompliantToken.transferPublic(AleoUtils.accounts[0], addr1, "10u128");
    await expectConfirmed(exec);
    const final0 = await bal(addr0);
    const final1 = await bal(addr1);
    expect(before0 - final0).toBe(10n);
    expect(final1 - before1).toBe(10n);
  });
});
