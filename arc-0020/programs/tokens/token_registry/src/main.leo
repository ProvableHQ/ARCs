import credits_clone.aleo;

// The 'token_registry' program.
program token_registry.aleo {
  record Token {
    owner: address,
    amount: u128,
    token_id: field,
    external_authorization_required: bool,
    authorized_until: u32
  }

  struct TokenMetadata {
    token_id: field,
    name: u128, // ASCII text encoded as bits packed into a u128 value.
    symbol: u128, // ASCII text encoded as bits packed into a u128 value.
    decimals: u8,
    supply: u128,
    max_supply: u128,
    admin: address,
    external_authorization_required: bool, // Whether this token requires external authorization before transferring.
    external_authorization_party: address
  }

  struct TokenOwner {
    account: address,
    token_id: field
  }

  struct Balance {
    token_id: field,
    account: address,
    balance: u128,
    authorized_until: u32
  }

  struct Allowance {
    account: address,
    spender: address,
    token_id: field
  }

  const CREDITS_RESERVED_TOKEN_ID: field = 3443843282313283355522573239085696902919850365217539366784739393210722344986field;
  mapping registered_tokens: field => TokenMetadata;
  mapping balances: field => Balance; // Keyed by hash(token_id, account).
  mapping authorized_balances: field => Balance; // Keyed by hash(token_id, account).
  mapping allowances: field => u128; // Keyed by hash(token_id, account, spender).

  const MINTER_ROLE: u8 = 1u8;
  const BURNER_ROLE: u8 = 2u8;
  const SUPPLY_MANAGER_ROLE: u8 = 3u8;
  mapping roles: field => u8; // Keyed by hash(token_id, account).

  @noupgrade
  constructor() {}

  // -------------------------
  // Called by token admins
  // -------------------------

  fn initialize() -> Final {
    return final {
      // Check if the CREDITS_RESERVED_TOKEN_ID token has already been initialized
      let already_initialized: bool = registered_tokens.contains(CREDITS_RESERVED_TOKEN_ID);
      assert_eq(already_initialized, false);

      // Initialize the CREDITS_RESERVED_TOKEN_ID token
      let credits_reserved_token: TokenMetadata = TokenMetadata {
        token_id: CREDITS_RESERVED_TOKEN_ID,
        name: 1095517519u128,
        symbol: 1095517519u128,
        decimals: 6u8,
        supply: 0u128, // placeholder value; not used
        max_supply: 10_000_000_000_000_000u128,
        admin: wrapped_credits.aleo, // On-chain, wrapped_credits.aleo manages the reserved credits token.
        external_authorization_required: false,
        external_authorization_party: self.address // token_registry.aleo itself
      };

      registered_tokens.set(CREDITS_RESERVED_TOKEN_ID, credits_reserved_token);
    };
  }

  fn register_token(
    public token_id: field,
    public name: u128,
    public symbol: u128,
    public decimals: u8,
    public max_supply: u128,
    public external_authorization_required: bool,
    public external_authorization_party: address
    ) -> Final {
    assert(token_id != CREDITS_RESERVED_TOKEN_ID);
    let caller: address = self.caller;
    let token: TokenMetadata = TokenMetadata {
      token_id: token_id,
      name: name,
      symbol: symbol,
      decimals: decimals,
      supply: 0u128,
      max_supply: max_supply,
      admin: caller,
      external_authorization_required: external_authorization_required,
      external_authorization_party: external_authorization_party
    };

    return final {
      // Make sure token doesn't already exist.
      let token_exists: bool = registered_tokens.contains(token.token_id);
      assert_eq(token_exists, false);
      // Store the new token.
      registered_tokens.set(token.token_id, token);
    };
  }

  fn update_token_management(
    public token_id: field,
    public admin: address,
    public external_authorization_party: address
  ) -> Final {
    assert(token_id != CREDITS_RESERVED_TOKEN_ID);
    let caller: address = self.caller;
    return final {
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert_eq(caller, token.admin);

      let new_metadata: TokenMetadata = TokenMetadata {
        token_id: token_id,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        supply: token.supply,
        max_supply: token.max_supply,
        admin: admin,
        external_authorization_required: token.external_authorization_required,
        external_authorization_party: external_authorization_party
      };
      registered_tokens.set(token_id, new_metadata);
    };
  }

  fn set_role(
    public token_id: field,
    public account: address,
    public role: u8
  ) -> Final {
    assert(token_id != CREDITS_RESERVED_TOKEN_ID);
    assert(role == MINTER_ROLE || role == BURNER_ROLE || role == SUPPLY_MANAGER_ROLE);

    let role_owner: TokenOwner = TokenOwner {
      account: account,
      token_id: token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);
    let caller: address = self.caller;

    return final {
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert_eq(caller, token.admin);

      roles.set(role_owner_hash, role);
    };
  }

  fn remove_role(
    public token_id: field,
    public account: address
  ) -> Final {
    assert(token_id != CREDITS_RESERVED_TOKEN_ID);

    let role_owner: TokenOwner = TokenOwner {
      account: account,
      token_id: token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);
    let caller: address = self.caller;

    return final {
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert_eq(caller, token.admin);

      roles.remove(role_owner_hash);
    };
  }

  fn mint_public(
    public token_id: field,
    public recipient: address,
    public amount: u128,
    public authorized_until: u32
  ) -> Final {
    let caller: address = self.caller;
    let role_owner: TokenOwner = TokenOwner {
      account: caller,
      token_id: token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);
    let token_owner: TokenOwner = TokenOwner {
      account: recipient,
      token_id: token_id
    };
    let balance_key: field = BHP256::hash_to_field(token_owner);

    return final {
      // Check that the token exists, and that the caller has permission to mint
      let token: TokenMetadata = registered_tokens.get(token_id);
      let is_admin: bool = caller == token.admin;
      if (!is_admin) {
        let role: u8 = roles.get(role_owner_hash);
        assert(role == MINTER_ROLE || role == SUPPLY_MANAGER_ROLE);
      }

      // Check that the token supply + amount <= max_supply
      let new_supply: u128 = token.supply + amount;
      assert(new_supply <= token.max_supply);

      // Get or create the balance for the recipient
      let default_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: 0u128,
        authorized_until: authorized_until
      };
      let authorization_required: bool = token.external_authorization_required;
      // Get the locked balance if authorization is required, otherwise get the authorized balance
      let balance: Balance = authorization_required
        ? balances.get_or_use(balance_key, default_balance)
        : authorized_balances.get_or_use(balance_key, default_balance);
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: balance.balance + amount,
        authorized_until: balance.authorized_until
      };
      // Update the appropriate balance
      if (authorization_required) {
        balances.set(balance_key, new_balance);
      } else {
        authorized_balances.set(balance_key, new_balance);
      }

      // Update the token supply
      let new_metadata: TokenMetadata = TokenMetadata {
        token_id: token_id,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        supply: new_supply,
        max_supply: token.max_supply,
        admin: token.admin,
        external_authorization_required: token.external_authorization_required,
        external_authorization_party: token.external_authorization_party
      };
      registered_tokens.set(token_id, new_metadata);
    };
  }

  fn mint_private(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public external_authorization_required: bool,
    public authorized_until: u32
    ) -> (Token, Final) {
    let token: Token = Token {
      owner: recipient,
      amount: amount,
      token_id: token_id,
      external_authorization_required: external_authorization_required,
      authorized_until: authorized_until
    };
    let caller: address = self.caller;
    let role_owner: TokenOwner = TokenOwner {
      account: caller,
      token_id: token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);

    return (token, final {
      // Check that the token exists, and that the caller has permission to mint
      let token_meta: TokenMetadata = registered_tokens.get(token_id);
      let is_admin: bool = caller == token_meta.admin;
      if (!is_admin) {
        let role: u8 = roles.get(role_owner_hash);
        assert(role == MINTER_ROLE || role == SUPPLY_MANAGER_ROLE);
      }

      // Check that the token supply + amount <= max_supply
      let new_supply: u128 = token_meta.supply + amount;
      assert(new_supply <= token_meta.max_supply);

      // Check that whether the token is authorized or not matches the authorized parameter
      let authorization_required: bool = token_meta.external_authorization_required;
      assert_eq(authorization_required, external_authorization_required);
      assert(authorized_until == 0u32 || !authorization_required);

      // Update the token supply
      let new_metadata: TokenMetadata = TokenMetadata {
        token_id: token_id,
        name: token_meta.name,
        symbol: token_meta.symbol,
        decimals: token_meta.decimals,
        supply: new_supply,
        max_supply: token_meta.max_supply,
        admin: token_meta.admin,
        external_authorization_required: token_meta.external_authorization_required,
        external_authorization_party: token_meta.external_authorization_party
      };
      registered_tokens.set(token_id, new_metadata);
    });
  }

  fn burn_public(
    public token_id: field,
    public owner: address,
    public amount: u128
  ) -> Final {
    let caller: address = self.caller;
    let token_owner: TokenOwner = TokenOwner {
      account: owner,
      token_id: token_id
    };
    let balance_key: field = BHP256::hash_to_field(token_owner);
    let role_owner: TokenOwner = TokenOwner {
      account: caller,
      token_id: token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);

    return final {
      // Check that the token exists, and that the caller has permission to burn
      let token: TokenMetadata = registered_tokens.get(token_id);
      if (caller != token.admin) {
        let role: u8 = roles.get(role_owner_hash);
        assert(role == BURNER_ROLE || role == SUPPLY_MANAGER_ROLE);
      }

      // Update the token supply
      let new_metadata: TokenMetadata = TokenMetadata {
        token_id: token.token_id,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        supply: token.supply - amount, // underflow will be caught by the VM
        max_supply: token.max_supply,
        admin: token.admin,
        external_authorization_required: token.external_authorization_required,
        external_authorization_party: token.external_authorization_party
      };
      registered_tokens.set(token_owner.token_id, new_metadata);

      // Get the authorized balance for the recipient
      let default_balance: Balance = Balance {
        token_id: token_owner.token_id,
        account: token_owner.account,
        balance: 0u128,
        authorized_until: 0u32
      };
      let authorized_balance: Balance = authorized_balances.get_or_use(balance_key, default_balance);
      // Burn from authorized balance first, then from locked balance if needed
      if (authorized_balance.balance > amount) {
        // Authorized balance covers the full burn
        let new_authorized_balance: Balance = Balance {
          token_id: token_owner.token_id,
          account: token_owner.account,
          balance: authorized_balance.balance - amount,
          authorized_until: authorized_balance.authorized_until
        };
        authorized_balances.set(balance_key, new_authorized_balance);
      } else {
        // Zero out authorized balance and burn remainder from locked balance
        let left_to_burn: u128 = amount - authorized_balance.balance;
        authorized_balances.set(balance_key, Balance {
          token_id: token_owner.token_id,
          account: token_owner.account,
          balance: 0u128,
          authorized_until: authorized_balance.authorized_until
        });
        if (left_to_burn > 0u128) {
          // Burn remainder from locked balance
          let locked_balance: Balance = balances.get(balance_key);
          let new_locked_balance: Balance = Balance {
            token_id: token_owner.token_id,
            account: token_owner.account,
            balance: locked_balance.balance - left_to_burn,
            authorized_until: locked_balance.authorized_until
          };
          balances.set(balance_key, new_locked_balance);
        }
      }
    };
  }

  fn burn_private(
    input_record: Token,
    public amount: u128
  ) -> (Token, Final) {
    let output_record: Token = Token {
        owner: input_record.owner,
        amount: input_record.amount - amount,
        token_id: input_record.token_id,
        external_authorization_required: input_record.external_authorization_required,
        authorized_until: input_record.authorized_until
    };
    let caller: address = self.caller;
    let role_owner: TokenOwner = TokenOwner {
      account: caller,
      token_id: input_record.token_id
    };
    let role_owner_hash: field = BHP256::hash_to_field(role_owner);
    let token_id: field = input_record.token_id;
    return (output_record, final {
      // Check that the token exists, and that the caller has permission to burn
      let token: TokenMetadata = registered_tokens.get(token_id);
      let is_admin: bool = caller == token.admin;
      if (!is_admin) {
        let role: u8 = roles.get(role_owner_hash);
        assert(role == BURNER_ROLE || role == SUPPLY_MANAGER_ROLE);
      }

      // Verify that the token supply minus the burn amount does not underflow.
      let new_supply: u128 = token.supply - amount; // underflow will be caught by the VM

      // Update the token supply
      let new_metadata: TokenMetadata = TokenMetadata {
        token_id: token_id,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        supply: new_supply,
        max_supply: token.max_supply,
        admin: token.admin,
        external_authorization_required: token.external_authorization_required,
        external_authorization_party: token.external_authorization_party
      };
      registered_tokens.set(token_id, new_metadata);
    });
  }

  fn prehook_public(
    public owner: TokenOwner,
    public amount: u128,
    public authorized_until: u32
  ) -> Final {
    let balance_key: field = BHP256::hash_to_field(owner);
    let caller: address = self.caller;
    return final {
      let token: TokenMetadata = registered_tokens.get(owner.token_id);
      // Check that the token requires external authorization
      assert(token.external_authorization_required);
      // Check that the caller has permission to authorize
      assert(caller == token.external_authorization_party);

      let default_balance: Balance = Balance {
        token_id: owner.token_id,
        account: owner.account,
        balance: 0u128,
        authorized_until: 0u32
      };
      // Get the locked balance for the recipient
      let locked_balance: Balance = balances.get_or_use(balance_key, default_balance);
      // Get the authorized balance for the recipient
      let authorized_balance: Balance = authorized_balances.get_or_use(balance_key, default_balance);
      // Check if the authorized balance is expired
      let authorized_balance_expired: bool = authorized_balance.authorized_until < block.height;
      // If the authorized balance is expired, treat is as part of the locked balance
      let actual_locked_balance: u128 = authorized_balance_expired
        ? locked_balance.balance + authorized_balance.balance
        : locked_balance.balance;
      let actual_authorized_balance: u128 = authorized_balance_expired
        ? 0u128
        : authorized_balance.balance;
      // Move the amount from the locked balance to the authorized balance
      let new_locked_balance: u128 = actual_locked_balance - amount;
      let new_authorized_balance: u128 = actual_authorized_balance + amount;

      // Update the authorized balance with the incremented amount and new expiration
      let new_authorized_balance_struct: Balance = Balance {
        token_id: owner.token_id,
        account: owner.account,
        balance: new_authorized_balance,
        authorized_until: authorized_until
      };
      authorized_balances.set(balance_key, new_authorized_balance_struct);

      // Update the locked balance
      let new_locked_balance_struct: Balance = Balance {
        token_id: owner.token_id,
        account: owner.account,
        balance: new_locked_balance,
        authorized_until: locked_balance.authorized_until
      };
      balances.set(balance_key, new_locked_balance_struct);
    };
  }

  fn prehook_private(input_record: Token, amount: u128, authorized_until: u32) -> (Token, Token, Final) {
    let unauthorized_record: Token = Token {
        owner: input_record.owner,
        amount: input_record.amount - amount,
        token_id: input_record.token_id,
        external_authorization_required: input_record.external_authorization_required,
        authorized_until: input_record.authorized_until
    };
    let authorized_record: Token = Token {
        owner: input_record.owner,
        amount: amount,
        token_id: input_record.token_id,
        external_authorization_required: input_record.external_authorization_required,
        authorized_until: authorized_until
    };
    let caller: address = self.caller;
    let token_id: field = input_record.token_id;
    return (unauthorized_record, authorized_record, final {
      // Check that the caller has permission to authorize
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert(caller == token.external_authorization_party);
    });
  }

  // -------------------------
  // Called by token owners/DeFi contracts
  // -------------------------

  fn transfer_public(
    public token_id: field,
    public recipient: address,
    public amount: u128
  ) -> Final {
    let caller: address = self.caller;
    let sender_key: TokenOwner = TokenOwner {
      account: caller,
      token_id: token_id
    };
    let sender_key_hash: field = BHP256::hash_to_field(sender_key);

    let recipient_key: TokenOwner = TokenOwner {
      account: recipient,
      token_id: token_id
    };
    let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);

    return final {
      let balance: Balance = authorized_balances.get(sender_key_hash);
      // Assert that the balance authorization is not expired or that the token does not require authorization
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert(block.height <= balance.authorized_until || !token.external_authorization_required);
      // Update the balance, and check that the balance >= amount
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: caller,
        balance: balance.balance - amount,
        authorized_until: balance.authorized_until
      };
      // Update sender balance
      authorized_balances.set(sender_key_hash, new_balance);

      // Get the locked balance if authorization is required, otherwise get the authorized balance
      let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
      let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
      let default_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: 0u128,
        authorized_until: default_expiration
      };
      let recipient_balance: Balance = authorization_required
        ? balances.get_or_use(recipient_balance_key, default_balance)
        : authorized_balances.get_or_use(recipient_balance_key, default_balance);
      let new_recipient_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: recipient_balance.balance + amount,
        authorized_until: recipient_balance.authorized_until
      };

      // Update recipient balance
      if (authorization_required) {
        balances.set(recipient_balance_key, new_recipient_balance);
      } else {
        authorized_balances.set(recipient_balance_key, new_recipient_balance);
      }
    };
  }

  fn transfer_public_as_signer(
    public token_id: field,
    public recipient: address,
    public amount: u128
  ) -> Final {
    let signer: address = self.signer;
    let sender_key: TokenOwner = TokenOwner {
      account: signer,
      token_id: token_id
    };
    let sender_key_hash: field = BHP256::hash_to_field(sender_key);
    let recipient_key: TokenOwner = TokenOwner {
      account: recipient,
      token_id: token_id
    };
    let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);
    return final {
      // Get stored balance for the owner
      let balance: Balance = authorized_balances.get(sender_key_hash);
      // Assert that the balance authorization is not expired or that the token does not require authorization
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert(block.height <= balance.authorized_until || !token.external_authorization_required);
      // Update the balance, and check that the balance >= amount
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: signer,
        balance: balance.balance - amount,
        authorized_until: balance.authorized_until
      };
      // Update sender balance
      authorized_balances.set(sender_key_hash, new_balance);

      // Get the locked balance if authorization is required, otherwise get the authorized balance
      let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
      let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
      let default_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: 0u128,
        authorized_until: default_expiration
      };
      let recipient_balance: Balance = authorization_required
        ? balances.get_or_use(recipient_balance_key, default_balance)
        : authorized_balances.get_or_use(recipient_balance_key, default_balance);
      let new_recipient_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: recipient_balance.balance + amount,
        authorized_until: recipient_balance.authorized_until
      };

      // Update recipient balance
      if (authorization_required) {
        balances.set(recipient_balance_key, new_recipient_balance);
      } else {
        authorized_balances.set(recipient_balance_key, new_recipient_balance);
      }
    };
  }

  fn approve_public(
    public token_id: field,
    public spender: address,
    public amount: u128
  ) -> Final {
    let allowance: Allowance = Allowance {
      account: self.caller,
      spender: spender,
      token_id: token_id
    };
    let allowance_key: field = BHP256::hash_to_field(allowance);

    return final {
      let current_allowance: u128 = allowances.get_or_use(allowance_key, 0u128);
      // Increase or create the allowance amount.
      allowances.set(allowance_key, current_allowance + amount);
    };
  }

  fn unapprove_public(
    public token_id: field,
    public spender: address,
    public amount: u128
  ) -> Final {
    let allowance: Allowance = Allowance {
      account: self.caller,
      spender: spender,
      token_id: token_id
    };
    let allowance_key: field = BHP256::hash_to_field(allowance);

    return final {
      let current_allowance: u128 = allowances.get(allowance_key);
      // Decrease the allowance amount.
      allowances.set(allowance_key, current_allowance - amount);
    };
  }

  fn transfer_from_public(
    public token_id: field,
    public owner: address,
    public recipient: address,
    public amount: u128
  ) -> Final {
    let allowance: Allowance = Allowance {
      account: owner,
      spender: self.caller,
      token_id: token_id
    };
    let allowance_key: field = BHP256::hash_to_field(allowance);
    let owner_key: TokenOwner = TokenOwner {
      account: owner,
      token_id: token_id
    };
    let owner_key_hash: field = BHP256::hash_to_field(owner_key);

    let recipient_key: TokenOwner = TokenOwner {
      account: recipient,
      token_id: token_id
    };
    let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);

    return final {
      // Check that the spender is authorized to spend the amount
      let current_allowance: u128 = allowances.get(allowance_key);
      // Decrease the allowance by the amount being spent
      allowances.set(allowance_key, current_allowance - amount);

      // Check that the owner has enough authorized balance
      let balance: Balance = authorized_balances.get(owner_key_hash);
      // Assert that the balance authorization is not expired or that the token does not require authorization
      let token: TokenMetadata = registered_tokens.get(token_id);
      assert(block.height <= balance.authorized_until || !token.external_authorization_required);

      // Update the balance for the owner
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: owner,
        balance: balance.balance - amount,
        authorized_until: balance.authorized_until
      };
      authorized_balances.set(owner_key_hash, new_balance);

      // Get the locked balance if authorization is required, otherwise get the authorized balance
      let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
      let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
      let default_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: 0u128,
        authorized_until: default_expiration
      };
      let recipient_balance: Balance = authorization_required
        ? balances.get_or_use(recipient_balance_key, default_balance)
        : authorized_balances.get_or_use(recipient_balance_key, default_balance);
      let new_recipient_balance: Balance = Balance {
        token_id: token_id,
        account: recipient,
        balance: recipient_balance.balance + amount,
        authorized_until: recipient_balance.authorized_until
      };
      // Update the balance of the recipient
      if (authorization_required) {
        balances.set(recipient_balance_key, new_recipient_balance);
      } else {
        authorized_balances.set(recipient_balance_key, new_recipient_balance);
      }
    };
  }

  fn transfer_public_to_private(
    public token_id: field,
    recipient: address,
    public amount: u128,
    public external_authorization_required: bool
  ) -> (Token, Final) {
    let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
    let token: Token = Token {
      owner: recipient,
      amount: amount,
      token_id: token_id,
      external_authorization_required: external_authorization_required,
      authorized_until: authorized_until
    };

    let caller: address = self.caller;
    let sender_key: TokenOwner = TokenOwner {
      account: caller,
      token_id: token_id
    };
    let sender_key_hash: field = BHP256::hash_to_field(sender_key);
    return (token, final {
      // Check that the transfer record's authorization matches the token's external_authorization_required
      let token_meta: TokenMetadata = registered_tokens.get(token_id);
      assert_eq(token_meta.external_authorization_required, external_authorization_required);

      // Get stored balances for the owner
      let balance: Balance = authorized_balances.get(sender_key_hash);
      // Assert that the balance authorization is not expired or that the token does not require authorization
      let token_metadata: TokenMetadata = registered_tokens.get(token_id);
      assert(block.height <= balance.authorized_until || !token_metadata.external_authorization_required);
      // Update the balance
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: caller,
        balance: balance.balance - amount,
        authorized_until: balance.authorized_until
      };
      authorized_balances.set(sender_key_hash, new_balance);
    });
  }

  fn transfer_from_public_to_private(
    public token_id: field,
    public owner: address,
    recipient: address,
    public amount: u128,
    public external_authorization_required: bool
  ) -> (Token, Final) {
    let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
    let token: Token = Token {
      owner: recipient,
      amount: amount,
      token_id: token_id,
      external_authorization_required: external_authorization_required,
      authorized_until: authorized_until
    };

    let allowance: Allowance = Allowance {
      account: owner,
      spender: self.caller,
      token_id: token_id
    };
    let allowance_key: field = BHP256::hash_to_field(allowance);

    let owner_key: TokenOwner = TokenOwner {
      account: owner,
      token_id: token_id
    };
    let owner_key_hash: field = BHP256::hash_to_field(owner_key);

    return (token, final {
      // Check that the transfer record's authorization matches the token's external_authorization_required
      let token_meta: TokenMetadata = registered_tokens.get(token_id);
      assert_eq(token_meta.external_authorization_required, external_authorization_required);

      // Check that the spender is authorized to spend the amount
      let current_allowance: u128 = allowances.get(allowance_key);
      // Update the allowance
      allowances.set(allowance_key, current_allowance - amount);

      // Check that the owner has enough authorized balance
      let balance: Balance = authorized_balances.get(owner_key_hash);
      // Assert that the balance authorization is not expired or that the token does not require authorization
      let token_metadata: TokenMetadata = registered_tokens.get(token_id);
      assert(block.height <= balance.authorized_until || !token_metadata.external_authorization_required);
      // Update the balance for the owner
      let new_balance: Balance = Balance {
        token_id: token_id,
        account: owner,
        balance: balance.balance - amount,
        authorized_until: balance.authorized_until
      };
      authorized_balances.set(owner_key_hash, new_balance);
    });
  }

  fn transfer_private(
    recipient: address,
    amount: u128,
    input_record: Token
  ) -> (Token, Token, Final) {
    let updated_record: Token = Token {
      owner: input_record.owner,
      amount: input_record.amount - amount,
      token_id: input_record.token_id,
      external_authorization_required: input_record.external_authorization_required,
      authorized_until: input_record.authorized_until
    };

    let external_authorization_required: bool = input_record.external_authorization_required;
    let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
    let transfer_record: Token = Token {
      owner: recipient,
      amount: amount,
      token_id: input_record.token_id,
      external_authorization_required: external_authorization_required,
      authorized_until: authorized_until
    };

    let input_token_authorized_until: u32 = input_record.authorized_until;
    return (updated_record, transfer_record, final {
      assert(block.height <= input_token_authorized_until || !external_authorization_required);
    });
  }

  fn transfer_private_to_public(
    public recipient: address,
    public amount: u128,
    input_record: Token
  ) -> (Token, Final) {
    let updated_record: Token = Token {
      owner: input_record.owner,
      amount: input_record.amount - amount,
      token_id: input_record.token_id,
      external_authorization_required: input_record.external_authorization_required,
      authorized_until: input_record.authorized_until
    };

    let recipient_key: TokenOwner = TokenOwner {
      account: recipient,
      token_id: input_record.token_id
    };
    let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);
    let token_id: field = input_record.token_id;
    let record_authorized_until: u32 = input_record.authorized_until;
    let external_authorization_required: bool = input_record.external_authorization_required;

    return (updated_record,
      final {
        // Assert that the record authorization is not expired
        assert(block.height <= record_authorized_until || !external_authorization_required);

        // Get the locked balance if authorization is required, otherwise get the authorized balance
        let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
        let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
        let default_balance: Balance = Balance {
          token_id: token_id,
          account: recipient,
          balance: 0u128,
          authorized_until: default_expiration
        };
        let recipient_balance: Balance = authorization_required
          ? balances.get_or_use(recipient_balance_key, default_balance)
          : authorized_balances.get_or_use(recipient_balance_key, default_balance);
        let new_recipient_balance: Balance = Balance {
          token_id: token_id,
          account: recipient,
          balance: recipient_balance.balance + amount,
          authorized_until: recipient_balance.authorized_until
        };
        // Update the balance of the recipient
        if (authorization_required) {
          balances.set(recipient_balance_key, new_recipient_balance);
        } else {
          authorized_balances.set(recipient_balance_key, new_recipient_balance);
        }
      });
  }

  fn join(
    private token_1: Token,
    private token_2: Token
  ) -> Token {
    // Check that the tokens are the same
    assert(token_1.token_id == token_2.token_id);
    let new_amount: u128 = token_1.amount + token_2.amount;
    // Take the smaller of the two authorized_until values
    let authorized_until: u32 = token_1.authorized_until < token_2.authorized_until
      ? token_1.authorized_until
      : token_2.authorized_until;
    let new_token: Token = Token {
      owner: token_1.owner,
      amount: new_amount,
      token_id: token_1.token_id,
      external_authorization_required: token_1.external_authorization_required,
      authorized_until: authorized_until
    };

    return new_token;
  }

  fn split(
    private token: Token,
    private amount: u128
  ) -> (Token, Token) {
    assert(token.amount >= amount);

    let new_token_1: Token = Token {
      owner: token.owner,
      amount: amount,
      token_id: token.token_id,
      external_authorization_required: token.external_authorization_required,
      authorized_until: token.authorized_until
    };
    let new_token_2: Token = Token {
      owner: token.owner,
      amount: token.amount - amount,
      token_id: token.token_id,
      external_authorization_required: token.external_authorization_required,
      authorized_until: token.authorized_until
    };

    return (new_token_1, new_token_2);
  }
}
