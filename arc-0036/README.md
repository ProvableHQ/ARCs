---
arc: 36
title: Validator Registry
authors: apybara.io tech team
discussion: 
topic: Application
status: Draft
created: 11/13/2023
---

## Abstract
Validators play an integral role in securing Aleo. However, not all token holders will be well equipped to run their own validators. For such cases, Aleo allows delegations so that token holders can stake for another validator. Delegators can help increase the total value staked on the network, increasing the opportunity cost for malicious actors, and promote a strong validator set, enhancing the overall throughput and performance of the network.

In the current setup, delegators will not have any data other than validator addresses and their stake amounts when selecting validators. We propose creating a public validator registry to give delegators provably accurate validator information. This will empower delegators to perform proper due diligence on validators. Additionally, applications can rely on this registry to provide delegators with human readable validator information.
We emphasize that the validator registry is purely optional and should be used by validators who wish to receive external delegations. Validators who want to remain anonymous or private should have the right to do so.


## Specification

### Implementation Details

The implementation details include the high-level implementation of the Aleo `validator_registry.aleo` program, user flow/stories for both validators and developers, pseudocode for the Aleo program, and the REST API. The Aleo program includes functions for adding a validator to the committee list, registering or updating a validator's information, checking if a validator is active, and getting the signed message of the validator's information. The REST API includes endpoints for retrieving the current committee list and the validator registry information for a specific validator.

### High-Level Implementation of the Aleo `validator_registry.aleo` program

- Signing a Message with Validator's Key:
    - Input: Collect the following information for the message:
        - validator_name: The name of the validator.
        - validator_website: The URL of the validator's website.
        - validator_logo: A URL or a hash of the validator's logo.
        - validator_description: A brief description of the validator.
    - Process:
        - Construct a message object containing the above details.
        - Use the validator’s private key to sign the message object.
    - Output:
        - A signed message that encapsulates the validator’s details.
- Calling the Current Committee List:
    - Action:
        - Make an API call to the Aleo Mapping to get the list of committees on-chain
- Validating the Presence of Validator in Committee List:
    - Check: Determine if the validator's address is present in the retrieved committee list.
        - If yes: Continue to the next step.
        - If no: Raise an error with the message: “Must be an active validator to register.”
- Calling the Latest Validator Registry:
    - Action:
        - Fetch the latest state of the validator registry via an API or smart contract call.
- Checking Validator Existence in the Registry:
    - Check: Ascertain if the validator address is present in the validator registry.
        - If yes:
            - Overwriting Process:
                - Prepare an update transaction with the new validator details.
                - Sign and send the transaction to overwrite the existing entry in the registry.
        - If no:
            - Creation Process:
                - Create a new registry entry with the validator details.
                - Sign and send the transaction to add the new entry to the registry.
- Error Handling:
    - Include try-catch blocks or equivalent error handling to manage unexpected behavior or failed transactions.
    - Provide meaningful error messages for the end-user or calling service.
- Logging and Auditing:
    - Maintain logs of all actions, especially the signing and updating processes.
    - Implement an audit trail for tracking changes in the validator registry.
- Security Measures:
    - Ensure all transactions are securely signed and transmitted.
    - Implement checks to prevent replay attacks and ensure message integrity.
- Testing:
    - Write unit tests to cover all the new functionalities.
    - Perform integration tests to ensure the entire process works within the existing infrastructure.
- Documentation:
    - Update the system documentation to include the new changes.
    - Provide clear instructions and examples for interacting with the updated system.

### User Flow / Stories

There are two main actors or users of the validator registry, the validators and the developers or users of the registry itself.

#### User story: As a validator, I’d like to be able to register my validator on the registry.

In this flow, the validator would be able to either register via cli or by calling the program via js, ts or rust sdk.

[https://lh7-us.googleusercontent.com/OicXmvEmcdeK5KpGFcuxOI93RlW4O7oUzMjqhwgCMHYfjkPU8SfT00hQIkFWsx0bwqq5JC9qbnUWdzXxPl9gwbpTMHhSaunZlM7v24w4D6s4lHYtTWVlZ3KwNuzQ3OG7SGCLRwsV720JTvF-E6YEXg](https://lh7-us.googleusercontent.com/OicXmvEmcdeK5KpGFcuxOI93RlW4O7oUzMjqhwgCMHYfjkPU8SfT00hQIkFWsx0bwqq5JC9qbnUWdzXxPl9gwbpTMHhSaunZlM7v24w4D6s4lHYtTWVlZ3KwNuzQ3OG7SGCLRwsV720JTvF-E6YEXg)

#### User Story: As a developer, I’d like to check or integrate the list of validators that exist on the registry.

In this flow, the developer would be able to get the registry info by calling an REST api endpoint exposed by an aleo `client` node.

[https://lh7-us.googleusercontent.com/KDEDQGmMk7fJWjRFf1MtQKrH1_abK_5IQ-1yyYVMHgn0rGR9cw_4qeIx55_RLR4-0xY8iGYI_ntTcrLZfEcfq78wTCPOQiHTA5Ks7k4dntnEWOrI_eqHTtrRUNImTKeSp9hBiBq-4HpeLSVw0dAUcQ](https://lh7-us.googleusercontent.com/KDEDQGmMk7fJWjRFf1MtQKrH1_abK_5IQ-1yyYVMHgn0rGR9cw_4qeIx55_RLR4-0xY8iGYI_ntTcrLZfEcfq78wTCPOQiHTA5Ks7k4dntnEWOrI_eqHTtrRUNImTKeSp9hBiBq-4HpeLSVw0dAUcQ)

Explorer and wallet developers will primarily be the users of the validator registry. Integrating the validator registry on their products will be helpful for end users in the following ways.

- Retail stakers. Retail stakers can begin their due diligence on validators using verifiably credible onchain information.
- Institutional stakers. Validators have private clients. Clients need a third party source to verify validator addresses before they stake with their validators.
- Protocol team. The core team will need to troubleshoot consensus/network issues with the help of validators. Coordination becomes easier with validators who are verified onchain.

### Pseudocode

Pseudo implementation of the aleo code and rest api

### Aleo Program

```
// Define a struct for validator information
struct ValidatorInfo {
    name: String,
    website: String,
    logo: String, // Assuming the logo is a URL or a hash of an uploaded image
    description: String,
}

// Assume a stateful record for committee list and validator registry
let committeeList: State<HashMap<Address, bool>>;
let validatorRegistry: State<HashMap<Address, ValidatorInfo>>;

// Function to add a validator to the committee list
function addToCommitteeList(validator_address: Address) -> bool {
    // Check if already in the committee list to prevent duplicates
    if committeeList.contains_key(&validator_address) {
        return false; // Already in the list
    }
    committeeList.insert(validator_address, true);
    return true;
}

// Function to register or update a validator's information
function registerValidator(validator_address: Address, info: ValidatorInfo) -> Result<(), String> {
    // Check if the validator is part of the committee
    match committeeList.get(&validator_address) {
        Some(_) => {
            // Register or update the validator's info
            validatorRegistry.insert(validator_address, info);
            Ok(())
        },
        None => Err("Validator must be an active committee member to register.")
    }
}

// Function to check if a validator is active
function isValidatorActive(validator_address: Address) -> bool {
    committeeList.get(&validator_address).is_some()
}

// Function to get the signed message of the validator's information
// Note: Signing would typically be done off-chain
function getSignedValidatorMessage(info: ValidatorInfo) -> String {
    // Placeholder for signing logic
    // Actual signing would be done off-chain using the validator's private key
    let message = format!("{}{}{}{}", info.name, info.website, info.logo, info.description);
    let signature = "off_chain_signature_placeholder";
    signature
}
```

### Rest API

```
// Endpoint to retrieve the current committee list 
GET /committeeList 
Action: - Retrieve the current list of active validators
Response: - List of active validators or an error if retrieval fails 

// Endpoint to retrieve the validator registry information for a specific validator 
GET /validatorRegistry/{validator_address} 
Action: - Retrieve the registry information for the given validator address 
Response: - Validator details or error if the validator is not found
```

### Aleo Node Validator CLI

```bash
TBD
```

### Test Cases


## Dependencies

This will impact snarkVM and everything that has snarkVM as a dependency.

### Backwards Compatibility

As this is a new feature, no programs should be impacted by adding a new opcode.

## Security & Compliance

There should be no regulatory concerns. 

## References
