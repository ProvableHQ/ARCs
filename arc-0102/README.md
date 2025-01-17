---
arc: 0102
title: zPass Model
authors: biplav.osti@venture23.io
discussion: ARC-0102 zPass Model
topic: Application
status: Draft
created: 01-16-2025
---

## Abstract

This proposal introduces a method to convert hierarchical data models into verifiable, issuable data structures leveraging Merkle trees. The approach ensures data integrity, privacy, and selective disclosure for both onchain and offchain usages. By assigning unique identifiers to data elements, hashing key-value pairs, and integrating salted values, this creates a robust data certification mechanism. Verification mechanisms enable efficient proofs for individual data points while maintaining privacy and security.

Blockchain applications often require verifiable data representations for use cases like identity verification, certificate issuance, or auditability. This proposal addresses challenges such as brute force attacks on exposed data, privacy in onchain sharing, and efficient verification by:

1. Storing certificates offchain and only the merkle root gets issued onchain.
2. Ensuring the integrity of hierarchical data structures using Merkle tree for issuance and verification.
3. Enabling selective data disclosure through Merkle proofs.


## Specification

Aleo record

```
record Certificate {
  private owner: address,
  private issuer: address,
  private hash: u64,
}
```

Functions

```
async transition issue(
  private subject: address,
  private issuer: address,
  private hash: u64,
  private sig: signature
) -> (Certificate, Future)
```
`sig` is the issuer signature on the `hash + issuer + subject` of the Certificate model illustrated below.

```
transition verify_ownership(
  private certificate : Certificate,
  private leaf: u64,
  private merkle_proof_subject: field[]
) -> bool
```

Certificate Model

```
key1: salt1 value1  
key2:  
  key21: salt21 value21
…
…
subject: saltX value
issuer: saltY value
…
…
type: saltN value	// certificate type: kyc/educational/membership, etc
private: [ ]  
metadata:
…
….
```

Certificate Hash Calculation

1. Key Normalization

  Flatten hierarchical data into normalized key-value pairs.

  Normalized key-value pairs:
  
  ```
  (key1) : salt1 value1
  (key2,key21) : salt2 value21
  (subject) : salt3 value3
  … so on
  ```

  The key having an array value is structured into a nested form with the item index as key and the respective item as the value and then normalized.
  ```
  key : [item1, item2,....]
  ```
  Nested Form :
  ```
  key[] : 
    0 : item1,
    1 : item2,
    … so on 
  ```
  
  Normalized key-value pairs :
  ```
  (key[],0) = salt item1
  (key[],1) = salt item2,
  … so on
  ```
  
  If the item itself is a nested structure, it follows the same hierarchical normalization pattern as shown above.
  
2. Assign Unique Key Identifiers
 
  Hash each normalized key to create unique identifiers for corresponding values. These identifiers are public data for a specific certificate model from an issuer.
  ```
  key_identifier = hash(type, issuer, normalized key)
  ```
  ```
  key1_identifier = hash(type, issuer, “key1”)
  key2_key21_identifier = hash(type, issuer, “key2,key21”)
  …
  key[]_0_identifier = hash(type, issuer, “key[],0”)
  … so on
  ```

3. Merkle Tree Leaves

  Salted Values
  
  To prevent brute force attacks, concatenate a salt with the value before hashing:
  ```
  key_leaf = hash(key_identifier, hash(salt, value))
  ```
  
  Key identifiers and values are combined and hashed to create leaf hashes:
  ```
  key1_leaf = hash(key1_identifier, hash(salt1,value1)) 
  key2_key21_leaf = hash(key2_key21_identifier, hash(salt2, value21)) 
  ```

4. Certificate Hash

  The leaves are sorted and hashed to compute the certificate hash:
  ```
  leaves[ ] = sort_asc([key1_leaf, key2_key21_leaf, …..])  
  certificate_hash = merkle_root(leaves[ ]) 
  ```

Verifier
  
  Verification involves proving the validity of a data point using the Merkle proof:
  ```
  transition verify(certificate: Certificate, salt, value, merkle_proof_of_leaf) { 
      key_identifier  //hardcoded_key_identifier
      leaf = hash(key_identifier, hash(salt, value)) 
      verify_merkle_root(certificate, leaf, merkle_proof_of_leaf) 
      // your logic here
  }
  ```

User Interaction
  
  Applications requiring value inclusion check request the user for the merkle proof on a value of a key identifier with a parameter: Key Identifier. 
  User responds with the salt, value and the merkle proof.
  The Verification logic looks as below:
  ```
  transition verify_value_inclusion(certificate: Certificate, salt, value, merkle_proof_of_leaf) { 
    key_identifier  //hardcoded_key_identifier
    leaf = hash(key_identifier, hash(salt, value)) 
    verify_merkle_root(certificate, leaf, merkle_proof_of_leaf) 
    // your logic here
  }
  ```

  Applications requiring key inclusion check request the user for merkle proof of a Key Identifier. 
  User responds with the hash of corresponding salt + value and merkle proof without exposing the salt nor the value.
  The verification logic looks as below:
  ```
  // data = hash(salt, value)
  transition verify_key_inclusion(certificate: Certificate, data, merkle_proof_of_leaf) { 
    key_identifier  //hardcoded_key_identifier
    leaf = hash(key_identifier, data) 
    verify_merkle_root(certificate, leaf, merkle_proof_of_leaf) 
    // your logic here
  }
  ```
Aleo Compatible Data Conversion

  If the data is a string, first apply [encodeToF(data)](https://developer.aleo.org/concepts/beginner/accounts/#encodetof) to convert it to a field type
  
  ```
  // normalized_key = "key1,key11,..."
  keyIdentifier = hashField(encodeToF(`type`+`issuer`+`normalized_key`))
  salt_hash = hashField(encodeToF(salt))
  value_hash = hashField(encodeToF(value) // if value is a String
  value_hash = hashField(value) // if value is a field
  leaf = hashMerge(keyIdentifier, hashMerge(salt_hash, value_hash))
  ```

Aleo compatible Operations
  
  ```
  hashField(data:field) -> u64 {
    return SHA3_256::hash_to_u64(data)
  }
  
  hashMerge(data1:u64, data2:u64) -> u64 {
    const BASE:u128 = 18446744073709551617u128; //BASE= 2^64+1
    return data1 < data2 ? 
      hash128(data1 as u128 * BASE + data2 as u128) : 
      hash128(data2 as u128 * BASE + data1 as u128)
  }
  
  hash128(data: u128) -> u64 {
    return SHA3_256::hash_to_u64(data)
  }
  ```

Verification
```
transition verify_proof(
  certificate: Certificate,
  leaf: u64,
  proof: [u64;32],  
) -> (bool) {
  let computed_hash:u64 = leaf;
  let zero_found:bool = false;
  for i:u8 in 0u8..31u8 {
    if(proof[i] != 0u64 && !zero_found) {
      computed_hash = computed_hash < proof[i] ? 
      hashMerge(computed_hash, proof[i]) : 
      hashMerge(proof[i], computed_hash);
    }else {
      zero_found = true;
    }
  }
  return computed_hash == certificate.hash;
} 
```

![211C46AB-3D43-4F76-9A5D-F461CB460AE4](https://github.com/user-attachments/assets/f555b97d-8390-42a6-bdb8-2aa3a05c2fd8)



Offchain Selective Disclosure

When revealing specific data points for offchain usages, use a private section to store hashes of shielded leaves.
```
key1: salt1 value1  
private: [
key2_key21_leaf_hash,
…,
…
]  
```

Certificate Hash

Combine hashes from the Private section with revealed data and compute the Merkle root
```
leaves[ ] = sort_asc([revealed_leaves + private_hashes])  

certificate_hash = merkle_root(leaves[ ])  
```

Metadata

Incorporate `metadata` for additional offchain data. 

Notes

1. `type`, `private` and `metadata` are reserved keywords and `[]` is a special symbol appended to the key containing an array value.  
2. `private` and `metadata` are not included in the certificate hash issued onchain and are for offchain uses only.
3. The delimiter between a salt and its corresponding value is an UTF-8 `space (0x20)`. So, the salt should not contain a space in itself.
4. `SHA-256` hashing algorithm is used for all purposes.





### Test Cases




## Reference Implementations




## Dependencies



### Backwards Compatibility
Not necessary.



## Security & Compliance




## References

