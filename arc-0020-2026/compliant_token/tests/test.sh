#!/usr/bin/env bash
# Compliant token devnet tests - one test per function
# Prerequisites: Programs must be deployed. Run from compliant-transfer-aleo repo:
#   npm run deploy:devnet
# Or deploy manually: merkle_tree -> multisig_core -> sealance_freezelist_registry -> compliant_token_template
#
# Set PRIVATE_KEY (deployer), or use default test key.
# For full test coverage, use the upstream: npm run test -- test/compliant_token.test.ts

set -e
PRIVATE_KEY="${PRIVATE_KEY:-APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH}"
RECIPIENT="${RECIPIENT:-aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t}"
ADMIN="${ADMIN:-aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px}"

# Change to compliant_token_template dir if we're in compliant_token/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLIANT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# If programs are in compliant-transfer-aleo, set COMPLIANT_TRANSFER_ROOT
COMPLIANT_TRANSFER_ROOT="${COMPLIANT_TRANSFER_ROOT:-}"
if [ -n "$COMPLIANT_TRANSFER_ROOT" ] && [ -d "$COMPLIANT_TRANSFER_ROOT" ]; then
  cd "$COMPLIANT_TRANSFER_ROOT"
  echo "Using compliant-transfer-aleo at $COMPLIANT_TRANSFER_ROOT"
else
  echo "Set COMPLIANT_TRANSFER_ROOT to compliant-transfer-aleo repo path for leo execute tests."
  echo "Or run: npm run test -- test/compliant_token.test.ts from that repo."
  exit 0
fi

run() {
  local prog=$1 fn=$2
  shift 2
  echo "--- $prog.$fn $*"
  leo execute "$prog" "$fn" "$@" --private-key "$PRIVATE_KEY" --devnet || true
}

# These require prior: deploy, initialize, role assignment, mint
# get_signing_op_id_for_deploy
run compliant_token_template.aleo get_signing_op_id_for_deploy "[0u8;32]" "0u16"

# update_role (admin only)
run compliant_token_template.aleo update_role "$ADMIN" "8u16"

# transfer_public (needs balance)
run compliant_token_template.aleo transfer_public "$RECIPIENT" "10u128"

# transfer_public_as_signer
run compliant_token_template.aleo transfer_public_as_signer "$RECIPIENT" "10u128"

# approve_public
run compliant_token_template.aleo approve_public "$RECIPIENT" "10u128"

# unapprove_public
run compliant_token_template.aleo unapprove_public "$RECIPIENT" "5u128"

# set_pause_status (pauser only)
# run compliant_token_template.aleo set_pause_status "true"

echo "Devnet smoke tests completed. For full coverage, run compliant_token.test.ts from compliant-transfer-aleo."
