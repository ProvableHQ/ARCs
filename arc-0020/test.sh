set -e

# Read the approver private key from the user
read -p "Enter the private key with positive public account balance: " approver_private_key
# Read the approver addresss from the user
read -p "Enter the associated address with positive public account balance: " approver_address

# throwaway keys
spender_tester_private_key="APrivateKey1zkpB6TurrGgShJ7dsJ21HniMTF5WQc2eRy7d5o5QyBZFMFf"
spender_tester_address="aleo1ew25qvyvd33gk9w4m8ehyhjamsm74r7n3ze9npnpux0rntzajgpqcm26pz"


mkdir -p build_token
cp token.aleo build_token/main.aleo
cp token_program.json build_token/program.json

echo """

/* This is only used for testing the spec */
function mint_public:
    input r0 as address.public;
    input r1 as u64.public;
    async mint_public r0 r1 into r2;
    output r2 as token.aleo/mint_public.future;

finalize mint_public:
    input r0 as address.public;
    input r1 as u64.public;
    get.or_use account[r0] 0u64 into r2;
    add r2 r1 into r3;
    set r3 into account[r0];
""" >> build_token/main.aleo

mkdir -p build_spender_tester
cp spender_tester.aleo build_spender_tester/main.aleo
cp spender_tester_program.json build_spender_tester/program.json
mkdir -p build_spender_tester/imports
cp build_token/main.aleo build_spender_tester/imports/token.aleo

# deploy
snarkos developer deploy token.aleo --private-key ${approver_private_key} --query "http://localhost:3030" --path "build_token" --broadcast "http://localhost:3030/testnet3/transaction/broadcast" --priority-fee 0

snarkos developer deploy spender_tester.aleo --private-key ${approver_private_key} --query "http://localhost:3030" --path "build_spender_tester" --broadcast "http://localhost:3030/testnet3/transaction/broadcast" --priority-fee 0

echo letting deployments settle for a few seconds...
sleep 10

# mint tokens
snarkos developer execute token.aleo mint_public ${approver_address} 10u64 --private-key ${approver_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"

# Transfer to spender so they have enough to cover the fee
snarkos developer execute credits.aleo transfer_public ${spender_tester_address} 100000u64 --private-key ${approver_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"

snarkos developer execute token.aleo approve_public ${spender_tester_address} 1u64 --private-key ${approver_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"

snarkos developer execute token.aleo transfer_from_public ${approver_address} ${spender_tester_address} 1u64 --private-key ${spender_tester_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"

snarkos developer execute token.aleo approve_public big_spender.aleo 1u64 --private-key ${approver_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"

snarkos developer execute token.aleo transfer_from_public big_spender.aleo ${spender_tester_address} 1u64 --private-key ${spender_tester_private_key} --query "http://localhost:3030" --broadcast "http://localhost:3030/testnet3/transaction/broadcast"
