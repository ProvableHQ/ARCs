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
`sig` is the issuer signature on the `hash` of the Certificate model illustrated below.

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

2. Assign Unique Key Identifiers
 
  Hash each normalized key to create unique identifiers for corresponding values. These identifiers are public data for a specific certificate model from an issuer.
  ```
  key_identifier = hash(type, issuer, normalized key)
  ```
  ```
  key1_identifier = hash(type, issuer, “key1”)
  key2_key21_identifier = hash(type, issuer, “key2,key21”)
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

[encodeToF](https://developer.aleo.org/concepts/beginner/accounts/#encodetof) Implementation
```
function encodeToF(input) {
    // Define Fp as the modulo base
    const Fp = BigInt("8444461749428370424248824938781546531375899335154063827935233455917409239041");

    // Convert string to UTF-8 byte sequence
    const utf8Encoder = new TextEncoder();
    const utf8Bytes = utf8Encoder.encode(input);

    // Convert UTF-8 bytes to little-endian unsigned integer
    let result = BigInt(0);
    for (let i = 0; i < utf8Bytes.length; i++) {
        result += BigInt(utf8Bytes[i]) << BigInt(8 * i); // Little-endian shift
    }

    // Take modulo Fp
    result %= Fp;

    return result;
}
```

Certificate Sample
```
type:KYC
issuer:aleo123456
name:Alice Wonderland
dob:1737213145
```

Normalized Certificate
```
type:2fc55f97-a9a3-4ed7-8815-634441580111 KYC
issuer:d64266d2-b9cd-46c2-8ed1-284f96916353 aleo123456
name:1b13c461-8ed4-420a-b1f4-9d6b1f84decc Alice Wonderland
dob:03dff77c-f450-43ac-a8a6-54fdfe8fd58c 1737213145
```

Calculate Key Identifier
```
encodeToF("type") = encodeToF("KYC"+"aleo123456"+"type") = 34518023219516878712502898596091663702347field
encodeToF("issuer") = encodeToF("KYC"+"aleo123456"+"issuer") = 2551123260008996174638407298389558793613826379field
encodeToF("name") = encodeToF("KYC"+"aleo123456"+"name") = 34513910798710461507111079899315413670219field
encodeToF("dob") = encodeToF("KYC"+"aleo123456"+"dob") = 130842721073966073778397858519836744011field


type_identifier = hashField(34518023219516878712502898596091663702347field) = 10446307579264726606u64
issuer_identifier = hashField(2551123260008996174638407298389558793613826379field) = 2814991933338693718u64
name_identifier = hashField(34513910798710461507111079899315413670219field) = 9542943440922567689u64
dob_identifier = hashField(130842721073966073778397858519836744011field) = 7553963441159233578u64
```

Calculate Leaves
```
Encode the salt and value

encodeToF(type_salt) = encodeToF("2fc55f97-a9a3-4ed7-8815-634441580111") = 4627873708036106866105690824943210139526495281608421305002800650924139945535field
encodeToF(type_value) = encodeToF("KYC") = 4413771field

encodeToF(issuer_salt) = encodeToF("d64266d2-b9cd-46c2-8ed1-284f96916353") = 5007416004099739579900811505314075173701371646709136087321901192545139447002field
encodeToF(type_value) = encodeToF("aleo123456") = 255989228916169135975521field

encodeToF(name_salt) = encodeToF("1b13c461-8ed4-420a-b1f4-9d6b1f84decc") = 5542136064011455447732190366687764001002631315870503937113503002855558914138field
encodeToF(name_value) = encodeToF("Alice Wonderland") = 133495928218707390983326110945227926593field

encodeToF(dob_salt) = encodeToF("03dff77c-f450-43ac-a8a6-54fdfe8fd58c") = 7304753691959740694777277560332690949244175568276288257230442595215705351000field
dob_value = 1737213145field
```
```
Hash the salt and value

type_salt_hash = hashField(4627873708036106866105690824943210139526495281608421305002800650924139945535field) = 11398935134570363188u64
type_value_hash = hashField(4413771field) = 11957017686122452459u64

issuer_salt_hash = hashField(5007416004099739579900811505314075173701371646709136087321901192545139447002field) = 11725745787159980657u64
issuer_value_hash = hashField(255989228916169135975521field) = 3389449752597723648u64

name_salt_hash = hashField(5542136064011455447732190366687764001002631315870503937113503002855558914138field) = 7618075299001000677u64
name_value_hash = hashField(133495928218707390983326110945227926593field) = 15677524595047486542u64

dob_salt_hash = hashField(7304753691959740694777277560332690949244175568276288257230442595215705351000field) = 8111974644445170344u64
dob_value_hash = hashField(1737213145field) = 905007618703667086u64
```
```
Calculate Leaves

type_leaf = hashMerge(type_identifier, hashMerge(type_salt_hash, type_value_hash) = hashMerge(10446307579264726606u64, hashMerge(11398935134570363188u64, 11957017686122452459u64) = 3493762364786270799u64
issuer_leaf = 2885257838413858146u64
name_leaf = 1977705045598954156u64
dob_leaf = 3824841577554724530u64
```

Merkle tree and Root Calculation
```
leaves = [3493762364786270799u64, 2885257838413858146u64, 1977705045598954156u64, 3824841577554724530u64]

sorted_leaves = level 0 = [1977705045598954156u64, 2885257838413858146u64, 3493762364786270799u64, 3824841577554724530u64]

level 1 = [hashMerge(1977705045598954156u64, 2885257838413858146u64), hashMerge(3493762364786270799u64, 3824841577554724530u64)] = [16628724507032849692u64, 9662023429270085602u64]

root = hashMerge(16628724507032849692u64, 9662023429270085602u64) = 7849773981907115583u64
```

Verify dob
```
dob verifier 

transition verify_dob(
        encoded_salt: field,
        value: field,
        proof: [u64;32],  
        ) -> bool {
        const ROOT:u64 = 7849773981907115583u64;
        const DOB_IDENTIFIER:u64 = 7553963441159233578u64;
        let computed_hash:u64 = hashMerge(DOB_IDENTIFIER, hashMerge(hashField(encoded_salt), hashField(value)));
        let zero_found:bool = false;
        for i:u64 in 0u64..32u64 {
            if(proof[i] != 0u64 && !zero_found) {
                computed_hash = hashMerge(computed_hash, proof[i]);
            }else {
                zero_found = true;
            }
        }
        return computed_hash == ROOT;
    } 
```

```
Test

leo run verify_dob 7304753691959740694777277560332690949244175568276288257230442595215705351000field 1737213145field [34937623647862
70799u64,16628724507032849692u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0
u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64,0u64]
       Leo ✅ Compiled 'issuer.aleo' into Aleo instructions

⛓  Constraints

 •  'issuer.aleo/verify_dob' - 1,508,343 constraints (called 1 time)

➡️  Output

 • true
```


## Reference Implementations




## Dependencies



### Backwards Compatibility
Not necessary.



## Security & Compliance




## References

