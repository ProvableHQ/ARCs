program token_registry.aleo {
    @noupgrade
    constructor() {}

    record Token {
        owner: address,
        amount: u128,
        token_id: field,
        external_authorization_required: bool,
        authorized_until: u32,
    }

    struct TokenMetadata {
        token_id: field,
        name: u128,
        symbol: u128,
        decimals: u8,
        supply: u128,
        max_supply: u128,
        admin: address,
        external_authorization_required: bool,
        external_authorization_party: address,
    }

    struct TokenOwner {
        account: address,
        token_id: field,
    }

    struct Balance {
        token_id: field,
        account: address,
        balance: u128,
        authorized_until: u32,
    }

    struct Allowance {
        account: address,
        spender: address,
        token_id: field,
    }

    const CREDITS_RESERVED_TOKEN_ID: field = 3443843282313283355522573239085696902919850365217539366784739393210722344986field;
    mapping registered_tokens: field => TokenMetadata;
    mapping balances: field => Balance;
    mapping authorized_balances: field => Balance;
    mapping allowances: field => u128;

    const MINTER_ROLE: u8 = 1u8;
    const BURNER_ROLE: u8 = 2u8;
    const SUPPLY_MANAGER_ROLE: u8 = 3u8;
    mapping roles: field => u8;

    fn initialize() -> Final {
        let program_addr = self.address;
        return final {
            let already_initialized: bool = registered_tokens.contains(CREDITS_RESERVED_TOKEN_ID);
            assert_eq(already_initialized, false);
            let credits_reserved_token: TokenMetadata = TokenMetadata {
                token_id: CREDITS_RESERVED_TOKEN_ID,
                name: 1095517519u128,
                symbol: 1095517519u128,
                decimals: 6u8,
                supply: 0u128,
                max_supply: 10000000000000000u128,
                admin: program_addr,
                external_authorization_required: false,
                external_authorization_party: program_addr,
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
        public external_authorization_party: address,
    ) -> Final {
        assert(token_id != CREDITS_RESERVED_TOKEN_ID);
        let token: TokenMetadata = TokenMetadata {
            token_id: token_id,
            name: name,
            symbol: symbol,
            decimals: decimals,
            supply: 0u128,
            max_supply: max_supply,
            admin: self.caller,
            external_authorization_required: external_authorization_required,
            external_authorization_party: external_authorization_party,
        };
        return final {
            let token_exists: bool = registered_tokens.contains(token.token_id);
            assert_eq(token_exists, false);
            registered_tokens.set(token.token_id, token);
        };
    }

    fn update_token_management(
        public token_id: field,
        public admin: address,
        public external_authorization_party: address,
    ) -> Final {
        assert(token_id != CREDITS_RESERVED_TOKEN_ID);
        let caller = self.caller;
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
                external_authorization_party: external_authorization_party,
            };
            registered_tokens.set(token_id, new_metadata);
        };
    }

    fn set_role(public token_id: field, public account: address, public role: u8) -> Final {
        assert(token_id != CREDITS_RESERVED_TOKEN_ID);
        assert(role == MINTER_ROLE || role == BURNER_ROLE || role == SUPPLY_MANAGER_ROLE);
        let role_owner: TokenOwner = TokenOwner { account: account, token_id: token_id };
        let role_owner_hash: field = BHP256::hash_to_field(role_owner);
        let caller = self.caller;
        return final {
            let token: TokenMetadata = registered_tokens.get(token_id);
            assert_eq(caller, token.admin);
            roles.set(role_owner_hash, role);
        };
    }

    fn remove_role(public token_id: field, public account: address) -> Final {
        assert(token_id != CREDITS_RESERVED_TOKEN_ID);
        let role_owner: TokenOwner = TokenOwner { account: account, token_id: token_id };
        let role_owner_hash: field = BHP256::hash_to_field(role_owner);
        let caller = self.caller;
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
        public authorized_until: u32,
    ) -> Final {
        let caller = self.caller;
        let role_owner: TokenOwner = TokenOwner { account: caller, token_id: token_id };
        let role_owner_hash: field = BHP256::hash_to_field(role_owner);
        let token_owner: TokenOwner = TokenOwner { account: recipient, token_id: token_id };
        let balance_key: field = BHP256::hash_to_field(token_owner);
        return final {
            let token: TokenMetadata = registered_tokens.get(token_id);
            let is_admin: bool = caller == token.admin;
            if (!is_admin) {
                let role: u8 = roles.get(role_owner_hash);
                assert(role == MINTER_ROLE || role == SUPPLY_MANAGER_ROLE);
            }
            let new_supply: u128 = token.supply + amount;
            assert(new_supply <= token.max_supply);
            let default_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: 0u128,
                authorized_until: authorized_until,
            };
            let authorization_required: bool = token.external_authorization_required;
            let balance: Balance = authorization_required ? balances.get_or_use(balance_key, default_balance) : authorized_balances.get_or_use(balance_key, default_balance);
            let new_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: balance.balance + amount,
                authorized_until: balance.authorized_until,
            };
            if (authorization_required) {
                balances.set(balance_key, new_balance);
            } else {
                authorized_balances.set(balance_key, new_balance);
            }
            let new_metadata: TokenMetadata = TokenMetadata {
                token_id: token_id,
                name: token.name,
                symbol: token.symbol,
                decimals: token.decimals,
                supply: new_supply,
                max_supply: token.max_supply,
                admin: token.admin,
                external_authorization_required: token.external_authorization_required,
                external_authorization_party: token.external_authorization_party,
            };
            registered_tokens.set(token_id, new_metadata);
        };
    }

    fn mint_private(
        public token_id: field,
        recipient: address,
        public amount: u128,
        public external_authorization_required: bool,
        public authorized_until: u32,
    ) -> (Token, Final) {
        let token_out: Token = Token {
            owner: recipient,
            amount: amount,
            token_id: token_id,
            external_authorization_required: external_authorization_required,
            authorized_until: authorized_until,
        };
        let role_owner: TokenOwner = TokenOwner { account: self.caller, token_id: token_id };
        let role_owner_hash: field = BHP256::hash_to_field(role_owner);
        let caller = self.caller;
        return (
            token_out,
            final {
                let token: TokenMetadata = registered_tokens.get(token_id);
                let is_admin: bool = caller == token.admin;
                if (!is_admin) {
                    let role: u8 = roles.get(role_owner_hash);
                    assert(role == MINTER_ROLE || role == SUPPLY_MANAGER_ROLE);
                }
                let new_supply: u128 = token.supply + amount;
                assert(new_supply <= token.max_supply);
                let authorization_required: bool = token.external_authorization_required;
                assert_eq(authorization_required, external_authorization_required);
                assert(authorized_until == 0u32 || !authorization_required);
                let new_metadata: TokenMetadata = TokenMetadata {
                    token_id: token_id,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    supply: new_supply,
                    max_supply: token.max_supply,
                    admin: token.admin,
                    external_authorization_required: token.external_authorization_required,
                    external_authorization_party: token.external_authorization_party,
                };
                registered_tokens.set(token_id, new_metadata);
            },
        );
    }

    fn burn_public(public token_id: field, public owner: address, public amount: u128) -> Final {
        let caller = self.caller;
        let token_owner: TokenOwner = TokenOwner { account: owner, token_id: token_id };
        let balance_key: field = BHP256::hash_to_field(token_owner);
        let role_owner: TokenOwner = TokenOwner { account: caller, token_id: token_id };
        let role_owner_hash: field = BHP256::hash_to_field(role_owner);
        return final {
            let token: TokenMetadata = registered_tokens.get(token_owner.token_id);
            if (caller != token.admin) {
                let role: u8 = roles.get(role_owner_hash);
                assert(role == BURNER_ROLE || role == SUPPLY_MANAGER_ROLE);
            }
            let new_metadata: TokenMetadata = TokenMetadata {
                token_id: token.token_id,
                name: token.name,
                symbol: token.symbol,
                decimals: token.decimals,
                supply: token.supply - amount,
                max_supply: token.max_supply,
                admin: token.admin,
                external_authorization_required: token.external_authorization_required,
                external_authorization_party: token.external_authorization_party,
            };
            registered_tokens.set(token_owner.token_id, new_metadata);
            let default_balance: Balance = Balance {
                token_id: token_owner.token_id,
                account: owner,
                balance: 0u128,
                authorized_until: 0u32,
            };
            let authorized_balance: Balance = authorized_balances.get_or_use(balance_key, default_balance);
            if (authorized_balance.balance >= 0u128) {
                if (authorized_balance.balance > amount) {
                    let new_authorized_balance: Balance = Balance {
                        token_id: token_owner.token_id,
                        account: owner,
                        balance: authorized_balance.balance - amount,
                        authorized_until: authorized_balance.authorized_until,
                    };
                    authorized_balances.set(balance_key, new_authorized_balance);
                } else {
                    authorized_balances.set(balance_key, Balance {
                        token_id: token_owner.token_id,
                        account: owner,
                        balance: 0u128,
                        authorized_until: authorized_balance.authorized_until,
                    });
                    let left_to_burn: u128 = amount - authorized_balance.balance;
                    if (left_to_burn == 0u128) {
                        // done
                    } else {
                        let locked_balance: Balance = balances.get(balance_key);
                        let new_locked_balance: Balance = Balance {
                            token_id: token_owner.token_id,
                            account: owner,
                            balance: locked_balance.balance - left_to_burn,
                            authorized_until: locked_balance.authorized_until,
                        };
                        balances.set(balance_key, new_locked_balance);
                    }
                }
            } else {
                let locked_balance: Balance = balances.get(balance_key);
                let new_locked_balance: Balance = Balance {
                    token_id: token_owner.token_id,
                    account: owner,
                    balance: locked_balance.balance - amount,
                    authorized_until: locked_balance.authorized_until,
                };
                balances.set(balance_key, new_locked_balance);
            }
        };
    }

    fn prehook_public(
        public owner: TokenOwner,
        public amount: u128,
        public authorized_until: u32,
    ) -> Final {
        let balance_key: field = BHP256::hash_to_field(owner);
        let caller = self.caller;
        return final {
            let token: TokenMetadata = registered_tokens.get(owner.token_id);
            assert(token.external_authorization_required);
            assert(caller == token.external_authorization_party);
            let default_balance: Balance = Balance {
                token_id: owner.token_id,
                account: owner.account,
                balance: 0u128,
                authorized_until: 0u32,
            };
            let locked_balance: Balance = balances.get_or_use(balance_key, default_balance);
            let authorized_balance: Balance = authorized_balances.get_or_use(balance_key, default_balance);
            let authorized_balance_expired: bool = authorized_balance.authorized_until
                < block.height;
            let actual_locked_balance: u128 = authorized_balance_expired ? locked_balance.balance
                + authorized_balance.balance : locked_balance.balance;
            let actual_authorized_balance: u128 = authorized_balance_expired ? 0u128 : authorized_balance.balance;
            let new_locked_balance: u128 = actual_locked_balance - amount;
            let new_authorized_balance: u128 = actual_authorized_balance + amount;
            let new_authorized_balance_struct: Balance = Balance {
                token_id: owner.token_id,
                account: owner.account,
                balance: new_authorized_balance,
                authorized_until: authorized_until,
            };
            authorized_balances.set(balance_key, new_authorized_balance_struct);
            let new_locked_balance_struct: Balance = Balance {
                token_id: owner.token_id,
                account: owner.account,
                balance: new_locked_balance,
                authorized_until: locked_balance.authorized_until,
            };
            balances.set(balance_key, new_locked_balance_struct);
        };
    }

    fn transfer_public(
        public token_id: field,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let sender_key: TokenOwner = TokenOwner { account: self.caller, token_id: token_id };
        let sender_key_hash: field = BHP256::hash_to_field(sender_key);
        let recipient_key: TokenOwner = TokenOwner { account: recipient, token_id: token_id };
        let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);
        let owner = self.caller;
        return final {
            let balance: Balance = authorized_balances.get(sender_key_hash);
            let token: TokenMetadata = registered_tokens.get(token_id);
            assert(block.height
                <= balance.authorized_until
                || !token.external_authorization_required);
            let new_balance: Balance = Balance {
                token_id: token_id,
                account: owner,
                balance: balance.balance - amount,
                authorized_until: balance.authorized_until,
            };
            authorized_balances.set(sender_key_hash, new_balance);
            let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
            let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
            let default_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: 0u128,
                authorized_until: default_expiration,
            };
            let recipient_balance: Balance = authorization_required ? balances.get_or_use(recipient_balance_key, default_balance) : authorized_balances.get_or_use(recipient_balance_key, default_balance);
            let new_recipient_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: recipient_balance.balance + amount,
                authorized_until: recipient_balance.authorized_until,
            };
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
        public amount: u128,
    ) -> Final {
        let sender_key: TokenOwner = TokenOwner { account: self.signer, token_id: token_id };
        let sender_key_hash: field = BHP256::hash_to_field(sender_key);
        let recipient_key: TokenOwner = TokenOwner { account: recipient, token_id: token_id };
        let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);
        let owner = self.signer;
        return final {
            let balance: Balance = authorized_balances.get(sender_key_hash);
            let token: TokenMetadata = registered_tokens.get(token_id);
            assert(block.height
                <= balance.authorized_until
                || !token.external_authorization_required);
            let new_balance: Balance = Balance {
                token_id: token_id,
                account: owner,
                balance: balance.balance - amount,
                authorized_until: balance.authorized_until,
            };
            authorized_balances.set(sender_key_hash, new_balance);
            let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
            let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
            let default_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: 0u128,
                authorized_until: default_expiration,
            };
            let recipient_balance: Balance = authorization_required ? balances.get_or_use(recipient_balance_key, default_balance) : authorized_balances.get_or_use(recipient_balance_key, default_balance);
            let new_recipient_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: recipient_balance.balance + amount,
                authorized_until: recipient_balance.authorized_until,
            };
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
        public amount: u128,
    ) -> Final {
        let allowance: Allowance = Allowance {
            account: self.caller,
            spender: spender,
            token_id: token_id,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        return final {
            let current_allowance: u128 = allowances.get_or_use(allowance_key, 0u128);
            allowances.set(allowance_key, current_allowance + amount);
        };
    }

    fn unapprove_public(
        public token_id: field,
        public spender: address,
        public amount: u128,
    ) -> Final {
        let allowance: Allowance = Allowance {
            account: self.caller,
            spender: spender,
            token_id: token_id,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        return final {
            let current_allowance: u128 = allowances.get(allowance_key);
            allowances.set(allowance_key, current_allowance - amount);
        };
    }

    fn transfer_public_to_private(
        public token_id: field,
        recipient: address,
        public amount: u128,
        public external_authorization_required: bool,
    ) -> (Token, Final) {
        let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
        let token_out: Token = Token {
            owner: recipient,
            amount: amount,
            token_id: token_id,
            external_authorization_required: external_authorization_required,
            authorized_until: authorized_until,
        };
        let sender_key: TokenOwner = TokenOwner { account: self.caller, token_id: token_id };
        let sender_key_hash: field = BHP256::hash_to_field(sender_key);
        let owner = self.caller;
        return (
            token_out,
            final {
                let token: TokenMetadata = registered_tokens.get(token_id);
                assert_eq(token.external_authorization_required, external_authorization_required);
                let balance: Balance = authorized_balances.get(sender_key_hash);
                let token_metadata: TokenMetadata = registered_tokens.get(token_id);
                assert(block.height
                    <= balance.authorized_until
                    || !token_metadata.external_authorization_required);
                let new_balance: Balance = Balance {
                    token_id: token_id,
                    account: owner,
                    balance: balance.balance - amount,
                    authorized_until: balance.authorized_until,
                };
                authorized_balances.set(sender_key_hash, new_balance);
            },
        );
    }

    fn transfer_pub_to_priv_as_signer(
        public token_id: field,
        recipient: address,
        public amount: u128,
        public external_authorization_required: bool,
    ) -> (Token, Final) {
        let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
        let token_out: Token = Token {
            owner: recipient,
            amount: amount,
            token_id: token_id,
            external_authorization_required: external_authorization_required,
            authorized_until: authorized_until,
        };
        let sender_key: TokenOwner = TokenOwner { account: self.signer, token_id: token_id };
        let sender_key_hash: field = BHP256::hash_to_field(sender_key);
        let owner = self.signer;
        return (
            token_out,
            final {
                let token: TokenMetadata = registered_tokens.get(token_id);
                assert_eq(token.external_authorization_required, external_authorization_required);
                let balance: Balance = authorized_balances.get(sender_key_hash);
                let token_metadata: TokenMetadata = registered_tokens.get(token_id);
                assert(block.height
                    <= balance.authorized_until
                    || !token_metadata.external_authorization_required);
                let new_balance: Balance = Balance {
                    token_id: token_id,
                    account: owner,
                    balance: balance.balance - amount,
                    authorized_until: balance.authorized_until,
                };
                authorized_balances.set(sender_key_hash, new_balance);
            },
        );
    }

    fn transfer_from_public_to_private(
        public token_id: field,
        public owner: address,
        recipient: address,
        public amount: u128,
        public external_authorization_required: bool,
    ) -> (Token, Final) {
        let authorized_until: u32 = external_authorization_required ? 0u32 : 4294967295u32;
        let token_out: Token = Token {
            owner: recipient,
            amount: amount,
            token_id: token_id,
            external_authorization_required: external_authorization_required,
            authorized_until: authorized_until,
        };
        let allowance: Allowance = Allowance {
            account: owner,
            spender: self.caller,
            token_id: token_id,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        let owner_key: TokenOwner = TokenOwner { account: owner, token_id: token_id };
        let owner_key_hash: field = BHP256::hash_to_field(owner_key);
        return (
            token_out,
            final {
                let token: TokenMetadata = registered_tokens.get(token_id);
                assert_eq(token.external_authorization_required, external_authorization_required);
                let current_allowance: u128 = allowances.get(allowance_key);
                allowances.set(allowance_key, current_allowance - amount);
                let balance: Balance = authorized_balances.get(owner_key_hash);
                let token_metadata: TokenMetadata = registered_tokens.get(token_id);
                assert(block.height
                    <= balance.authorized_until
                    || !token_metadata.external_authorization_required);
                let new_balance: Balance = Balance {
                    token_id: token_id,
                    account: owner,
                    balance: balance.balance - amount,
                    authorized_until: balance.authorized_until,
                };
                authorized_balances.set(owner_key_hash, new_balance);
            },
        );
    }

    fn transfer_from_public(
        public token_id: field,
        public owner: address,
        public recipient: address,
        public amount: u128,
    ) -> Final {
        let allowance: Allowance = Allowance {
            account: owner,
            spender: self.caller,
            token_id: token_id,
        };
        let allowance_key: field = BHP256::hash_to_field(allowance);
        let owner_key: TokenOwner = TokenOwner { account: owner, token_id: token_id };
        let owner_key_hash: field = BHP256::hash_to_field(owner_key);
        let recipient_key: TokenOwner = TokenOwner { account: recipient, token_id: token_id };
        let recipient_balance_key: field = BHP256::hash_to_field(recipient_key);
        return final {
            let current_allowance: u128 = allowances.get(allowance_key);
            allowances.set(allowance_key, current_allowance - amount);
            let balance: Balance = authorized_balances.get(owner_key_hash);
            let token: TokenMetadata = registered_tokens.get(token_id);
            assert(block.height
                <= balance.authorized_until
                || !token.external_authorization_required);
            let new_balance: Balance = Balance {
                token_id: token_id,
                account: owner,
                balance: balance.balance - amount,
                authorized_until: balance.authorized_until,
            };
            authorized_balances.set(owner_key_hash, new_balance);
            let authorization_required: bool = registered_tokens.get(token_id).external_authorization_required;
            let default_expiration: u32 = authorization_required ? 0u32 : 4294967295u32;
            let default_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: 0u128,
                authorized_until: default_expiration,
            };
            let recipient_balance: Balance = authorization_required ? balances.get_or_use(recipient_balance_key, default_balance) : authorized_balances.get_or_use(recipient_balance_key, default_balance);
            let new_recipient_balance: Balance = Balance {
                token_id: token_id,
                account: recipient,
                balance: recipient_balance.balance + amount,
                authorized_until: recipient_balance.authorized_until,
            };
            if (authorization_required) {
                balances.set(recipient_balance_key, new_recipient_balance);
            } else {
                authorized_balances.set(recipient_balance_key, new_recipient_balance);
            }
        };
    }

    fn join(private token_1: Token, private token_2: Token) -> Token {
        assert(token_1.token_id == token_2.token_id);
        let new_amount: u128 = token_1.amount + token_2.amount;
        let authorized_until: u32 = token_1.authorized_until < token_2.authorized_until ? token_1.authorized_until : token_2.authorized_until;
        return Token {
            owner: token_1.owner,
            amount: new_amount,
            token_id: token_1.token_id,
            external_authorization_required: token_1.external_authorization_required,
            authorized_until: authorized_until,
        };
    }

    fn transfer_private(private token: Token, to: address, private amount: u128) -> (Token, Token) {
        assert(token.amount >= amount);
        let change_token: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
            token_id: token.token_id,
            external_authorization_required: token.external_authorization_required,
            authorized_until: token.authorized_until,
        };
        let new_token: Token = Token {
            owner: to,
            amount: amount,
            token_id: token.token_id,
            external_authorization_required: token.external_authorization_required,
            authorized_until: token.authorized_until,
        };
        return (change_token, new_token);
    }

    fn split(private token: Token, private amount: u128) -> (Token, Token) {
        assert(token.amount >= amount);
        let new_token_1: Token = Token {
            owner: token.owner,
            amount: amount,
            token_id: token.token_id,
            external_authorization_required: token.external_authorization_required,
            authorized_until: token.authorized_until,
        };
        let new_token_2: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
            token_id: token.token_id,
            external_authorization_required: token.external_authorization_required,
            authorized_until: token.authorized_until,
        };
        return (new_token_1, new_token_2);
    }
}
