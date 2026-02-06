#!/bin/bash

# Script to deploy and test wrapped_credits.aleo
# Usage: ./deploy_and_test.sh

set -e  # Exit on error

LEO=~/programs/leo/target/release/leo
PRIVATE_KEY="APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH"
PROGRAM="wrapped_credits.aleo"

# Matches the private key above
ADDRESS1="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px" 
# Alternative test address
ADDRESS2="aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t" 

echo "================================"
echo "Starting Leo DevNode..."
echo "================================"

# Start devnode in background
leo devnode start --private-key $PRIVATE_KEY > devnode.log 2>&1 &
DEVNODE_PID=$!

echo "DevNode PID: $DEVNODE_PID"
echo "Waiting for devnode to initialize..."
sleep 5

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "================================"
    echo "Cleaning up..."
    echo "================================"
    if [ ! -z "$DEVNODE_PID" ]; then
        echo "Stopping devnode (PID: $DEVNODE_PID)..."
        kill $DEVNODE_PID 2>/dev/null || true
        wait $DEVNODE_PID 2>/dev/null || true
    fi
    echo "Cleanup complete"
}

trap cleanup EXIT INT TERM

echo ""
echo "================================"
echo "Deploying $PROGRAM..."
echo "================================"
$LEO deploy --private-key $PRIVATE_KEY --devnet

echo ""
echo "================================"
echo "Deployment complete!"
echo "================================"
echo ""
echo "Starting function executions..."
echo ""

# Test 1: transfer_public - Transfer tokens between public balances
echo "--------------------------------------------------------------------------------"
echo "Test 1: transfer_public"
echo "Description: Transfer 100 wrapped credits from caller to ADDRESS2"
echo "--------------------------------------------------------------------------------"
$LEO execute transfer_public $ADDRESS2 100u128 \
    --private-key $PRIVATE_KEY || echo "❌ Test 1 failed (expected - no balance)"
echo ""

# Test 2: deposit_credits_public - Deposit credits into wrapped credits
echo "--------------------------------------------------------------------------------"
echo "Test 2: deposit_credits_public"
echo "Description: Deposit 1000 credits to get wrapped credits"
echo "--------------------------------------------------------------------------------"
$LEO execute deposit_credits_public 1000u64 \
    --private-key $PRIVATE_KEY || echo "❌ Test 2 failed"
echo ""

# Test 3: transfer_public (retry after deposit)
echo "--------------------------------------------------------------------------------"
echo "Test 3: transfer_public (after deposit)"
echo "Description: Transfer 100 wrapped credits from caller to ADDRESS2"
echo "--------------------------------------------------------------------------------"
$LEO execute transfer_public $ADDRESS2 100u128 \
    --private-key $PRIVATE_KEY || echo "❌ Test 3 failed"
echo ""

# Test 4: transfer_public_as_signer
echo "--------------------------------------------------------------------------------"
echo "Test 4: transfer_public_as_signer"
echo "Description: Transfer 50 wrapped credits from signer to ADDRESS2"
echo "--------------------------------------------------------------------------------"
$LEO execute transfer_public_as_signer $ADDRESS2 50u128 \
    --private-key $PRIVATE_KEY || echo "❌ Test 4 failed"
echo ""

# Test 5: withdraw_credits_public
echo "--------------------------------------------------------------------------------"
echo "Test 5: withdraw_credits_public"
echo "Description: Withdraw 200 wrapped credits back to native credits (caller)"
echo "--------------------------------------------------------------------------------"
$LEO execute withdraw_credits_public 200u64 \
    --private-key $PRIVATE_KEY || echo "❌ Test 5 failed"
echo ""

# Test 6: withdraw_credits_public_signer
echo "--------------------------------------------------------------------------------"
echo "Test 6: withdraw_credits_public_signer"
echo "Description: Withdraw 100 wrapped credits back to native credits (signer)"
echo "--------------------------------------------------------------------------------"
$LEO execute withdraw_credits_public_signer 100u64 \
    --private-key $PRIVATE_KEY || echo "❌ Test 6 failed"
echo ""

# Test 7: transfer_public_to_private
echo "--------------------------------------------------------------------------------"
echo "Test 7: transfer_public_to_private"
echo "Description: Convert 150 public wrapped credits to private token"
echo "--------------------------------------------------------------------------------"
$LEO execute transfer_public_to_private $ADDRESS1 150u128 \
    --private-key $PRIVATE_KEY || echo "❌ Test 7 failed"
echo ""

# Note: The following functions require record inputs which are harder to test in a simple script:
# - deposit_credits_private: requires credits.aleo/credits record
# - withdraw_credits_private: requires Token record
# - transfer_private: requires Token record
# - transfer_private_to_public: requires Token record

echo ""
echo "================================"
echo "Note: Private record functions not tested in this script"
echo "================================"
echo "The following functions require record inputs from previous executions:"
echo "  - deposit_credits_private (needs credits.aleo/credits record)"
echo "  - withdraw_credits_private (needs Token record)"
echo "  - transfer_private (needs Token record)"
echo "  - transfer_private_to_public (needs Token record)"
echo ""
echo "To test these, you would need to:"
echo "  1. Parse outputs from previous executions"
echo "  2. Extract record strings"
echo "  3. Pass them as inputs to subsequent calls"
echo ""

echo "================================"
echo "Testing complete!"
echo "================================"
echo "Check devnode.log for detailed node output"
echo ""
echo "Press Ctrl+C to stop the devnode and exit"
echo ""

# Keep script running so devnode stays alive
wait $DEVNODE_PID
