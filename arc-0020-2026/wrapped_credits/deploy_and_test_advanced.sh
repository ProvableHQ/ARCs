#!/bin/bash

# Advanced script to test ALL wrapped_credits.aleo functions including private records
# This script demonstrates parsing Leo execution outputs to chain function calls

set -e

LEO=~/programs/leo/target/release/leo
PRIVATE_KEY="APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH"
ADDRESS1="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px"
ADDRESS2="aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t"

echo "================================"
echo "Advanced Testing with Record Parsing"
echo "================================"
echo ""

# Function to extract record from Leo output
# Usage: extract_record <output_file> <record_name>
extract_record() {
    local output_file=$1
    local record_name=$2
    # This is a simplified parser - Leo output format may vary
    grep -A 20 "$record_name" "$output_file" | grep -E "record\{.*\}" | head -1 || echo ""
}

echo "Starting devnode..."
$LEO devnode start --private-key $PRIVATE_KEY > devnode.log 2>&1 &
DEVNODE_PID=$!
echo "DevNode PID: $DEVNODE_PID"
sleep 5

cleanup() {
    echo ""
    echo "Stopping devnode..."
    kill $DEVNODE_PID 2>/dev/null || true
    wait $DEVNODE_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Deploying program..."
$LEO deploy --private-key $PRIVATE_KEY
echo ""

# =============================================================================
# Phase 1: Public Functions (No record dependencies)
# =============================================================================

echo "==================================="
echo "Phase 1: Public Functions"
echo "==================================="
echo ""

echo "1. deposit_credits_public (1000u64)"
$LEO execute deposit_credits_public 1000u64 \
    --private-key $PRIVATE_KEY | tee output_deposit_public.txt
echo ""

echo "2. transfer_public (to: $ADDRESS2, amount: 100u128)"
$LEO execute transfer_public $ADDRESS2 100u128 \
    --private-key $PRIVATE_KEY | tee output_transfer_public.txt
echo ""

echo "3. transfer_public_as_signer (to: $ADDRESS2, amount: 50u128)"
$LEO execute transfer_public_as_signer $ADDRESS2 50u128 \
    --private-key $PRIVATE_KEY | tee output_transfer_public_signer.txt
echo ""

echo "4. transfer_public_to_private (to: $ADDRESS1, amount: 200u128)"
$LEO execute transfer_public_to_private $ADDRESS1 200u128 \
    --private-key $PRIVATE_KEY | tee output_transfer_pub_to_priv.txt
echo ""

# Extract Token record from transfer_public_to_private output
TOKEN_RECORD=$(extract_record "output_transfer_pub_to_priv.txt" "Token")
echo "Extracted Token Record: $TOKEN_RECORD"
echo ""

# =============================================================================
# Phase 2: Private Functions (Require records from Phase 1 or credits)
# =============================================================================

echo "==================================="
echo "Phase 2: Private Record Functions"
echo "==================================="
echo ""

# Test transfer_private with the Token we just created
if [ ! -z "$TOKEN_RECORD" ]; then
    echo "5. transfer_private (using extracted Token record)"
    echo "   Transferring 50u128 to $ADDRESS2"
    $LEO execute transfer_private "$TOKEN_RECORD" $ADDRESS2 50u128 \
        --private-key $PRIVATE_KEY | tee output_transfer_private.txt || echo "❌ Failed"
    echo ""
    
    # Extract change token for next test
    CHANGE_TOKEN=$(extract_record "output_transfer_private.txt" "Token")
    echo "Extracted Change Token: $CHANGE_TOKEN"
    echo ""
fi

# Test transfer_private_to_public
if [ ! -z "$CHANGE_TOKEN" ]; then
    echo "6. transfer_private_to_public (using change token)"
    echo "   Converting 30u128 to public for $ADDRESS2"
    $LEO execute transfer_private_to_public "$CHANGE_TOKEN" $ADDRESS2 30u128 \
        --private-key $PRIVATE_KEY | tee output_transfer_priv_to_pub.txt || echo "❌ Failed"
    echo ""
fi

# =============================================================================
# Phase 3: Credits.aleo Integration Functions
# =============================================================================

echo "==================================="
echo "Phase 3: Credits Integration"
echo "==================================="
echo ""

# To test deposit_credits_private and withdraw_credits_private, we need credits.aleo records
# These typically come from the genesis or previous credits transactions

echo "7. Attempting deposit_credits_private"
echo "   Note: This requires a credits.aleo/credits record"
echo "   In production, you would extract this from credits.aleo transactions"
echo ""
# Example (would need actual record):
# CREDITS_RECORD="{ owner: $ADDRESS1, microcredits: 5000u64 }"
# $LEO execute deposit_credits_private "$CREDITS_RECORD" 500u64 \
#     --private-key $PRIVATE_KEY --priority-fee 0

echo "8. Attempting withdraw_credits_private"
echo "   Note: This requires a Token record with sufficient balance"
echo ""
# Example (would need actual record):
# $LEO execute withdraw_credits_private "$TOKEN_RECORD" 100u64 \
#     --private-key $PRIVATE_KEY --priority-fee 0

echo "9. withdraw_credits_public (100u64)"
$LEO execute withdraw_credits_public 100u64 \
    --private-key $PRIVATE_KEY | tee output_withdraw_public.txt
echo ""

echo "10. withdraw_credits_public_signer (50u64)"
$LEO execute withdraw_credits_public_signer 50u64 \
    --private-key $PRIVATE_KEY | tee output_withdraw_public_signer.txt
echo ""

# =============================================================================
# Summary
# =============================================================================

echo "==================================="
echo "Testing Summary"
echo "==================================="
echo ""
echo "✅ Public functions tested:"
echo "   - deposit_credits_public"
echo "   - transfer_public"
echo "   - transfer_public_as_signer"
echo "   - transfer_public_to_private"
echo "   - withdraw_credits_public"
echo "   - withdraw_credits_public_signer"
echo ""
echo "⚠️  Private functions (record-dependent):"
echo "   - transfer_private (attempted with parsed record)"
echo "   - transfer_private_to_public (attempted with parsed record)"
echo ""
echo "ℹ️  Not fully tested (requires credits.aleo records):"
echo "   - deposit_credits_private"
echo "   - withdraw_credits_private"
echo ""
echo "Output files saved as output_*.txt"
echo "DevNode log: devnode.log"
echo ""
echo "Press Ctrl+C to stop devnode and exit"
echo ""

wait $DEVNODE_PID
