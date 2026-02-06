# Deployment and Testing Scripts

This directory contains shell scripts to deploy and test the `wrapped_credits.aleo` program.

## Scripts

### 1. `deploy_and_test.sh` (Basic)
A straightforward script that:
- Starts a local Leo devnode with mock ledger and REST API
- Deploys the wrapped_credits program
- Executes all public functions with test parameters
- Tests basic deposit, transfer, and withdraw operations

**Usage:**
```bash
./deploy_and_test.sh
```

**What it tests:**
- ✅ `deposit_credits_public` - Deposit native credits
- ✅ `transfer_public` - Transfer wrapped credits between addresses
- ✅ `transfer_public_as_signer` - Transfer using signer context
- ✅ `transfer_public_to_private` - Convert public to private tokens
- ✅ `withdraw_credits_public` - Withdraw to native credits (caller)
- ✅ `withdraw_credits_public_signer` - Withdraw to native credits (signer)

**Not tested** (require record inputs):
- `deposit_credits_private`
- `withdraw_credits_private`
- `transfer_private`
- `transfer_private_to_public`

### 2. `deploy_and_test_advanced.sh` (Advanced)
A more sophisticated script that:
- Parses Leo execution outputs to extract records
- Chains executions by using outputs as inputs
- Attempts to test private record functions
- Saves all outputs to files for inspection

**Usage:**
```bash
./deploy_and_test_advanced.sh
```

**Additional features:**
- Extracts Token records from outputs
- Uses extracted records as inputs for subsequent calls
- Saves execution outputs to `output_*.txt` files
- More detailed logging and error handling

## Requirements

- Leo binary at `~/programs/leo/target/release/leo`
- Bash shell (macOS/Linux)
- Network connectivity (for devnode API)

## Default Test Configuration

**Private Key:** `APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH`  
**Address 1:** `aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px`  
**Address 2:** `aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t`

## Manual Testing

You can also interact with the deployed program manually:

### Start devnode
```bash
~/programs/leo/target/release/leo devnode start \
  --private-key APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH
```

### Deploy
```bash
~/programs/leo/target/release/leo deploy \
  --private-key APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH \
  --priority-fee 0
```

### Execute function
```bash
~/programs/leo/target/release/leo execute deposit_credits_public 1000u64 \
  --private-key APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH \
  --priority-fee 0
```

## Cleanup

The scripts automatically clean up the devnode process on exit (Ctrl+C or script completion).

If a devnode process is left running:
```bash
# Find the process
ps aux | grep "leo devnode"

# Kill it
kill <PID>
```

## Output Files

When running `deploy_and_test_advanced.sh`, execution outputs are saved to:
- `output_deposit_public.txt`
- `output_transfer_public.txt`
- `output_transfer_public_signer.txt`
- `output_transfer_pub_to_priv.txt`
- `output_transfer_private.txt`
- `output_transfer_priv_to_pub.txt`
- `output_withdraw_public.txt`
- `output_withdraw_public_signer.txt`
- `devnode.log` (devnode console output)

## Troubleshooting

**Script fails to execute:**
- Ensure scripts have execute permissions: `chmod +x *.sh`

**Leo binary not found:**
- Update the `LEO` variable in scripts to point to your Leo installation

**Devnode won't start:**
- Check if port is already in use
- Kill any existing devnode processes
- Check `devnode.log` for error messages

**Execution fails with "insufficient balance":**
- Ensure previous deposit/setup steps completed successfully
- Check if devnode state persists or resets between runs
