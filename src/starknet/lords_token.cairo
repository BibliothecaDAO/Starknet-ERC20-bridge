#[contract]
mod LordsToken {
    use starknet::{ContractAddress, contract_address, get_caller_address};
    use zeroable::Zeroable;

    struct Storage {
        // address of the Lords bridge contract on Starknet, only it can mint and burn
        l2_bridge: ContractAddress,
        // ERC20 related storage vars
        supply: u256,
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, value: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, spender: ContractAddress, value: u256) {}

    #[constructor]
    fn constructor(l2_bridge: ContractAddress) {
        l2_bridge::write(l2_bridge);
    }

    #[view]
    fn name() -> felt252 {
        'Lords'
    }

    #[view]
    fn symbol() -> felt252 {
        'LORDS'
    }

    #[view]
    fn decimals() -> u8 {
        18
    }

    #[view]
    fn total_supply() -> u256 {
        supply::read()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        balances::read(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        allowances::read((owner, spender))
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        lib::approve(get_caller_address(), spender, amount);
        true
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        lib::transfer(get_caller_address(), recipient, amount);
        true
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        lib::spend_allowance(sender, get_caller_address(), amount);
        lib::transfer(sender, recipient, amount);
        true
    }

    #[external]
    fn mint(recipient: ContractAddress, amount: u256) -> bool {
        lib::assert_is_bridge(get_caller_address());
        // deliberately not doing any more checks because this fn
        // is called by the bridge's L1 handler, don't want it to panic

        supply::write(supply::read() + amount);
        balances::write(recipient, balances::read(recipient) + amount);

        Transfer(Zeroable::zero(), recipient, amount);
        true
    }

    #[external]
    fn burn(owner: ContractAddress, amount: u256) -> bool {
        lib::assert_is_bridge(get_caller_address());

        supply::write(supply::read() - amount);
        balances::write(owner, balances::read(owner) - amount);

        Transfer(owner, Zeroable::zero(), amount);
        true
    }

    //
    // Internal
    //

    mod lib {
        use integer::BoundedInt;
        use starknet::{ContractAddress, contract_address};
        use zeroable::Zeroable;

        #[inline(always)]
        fn assert_is_bridge(addr: ContractAddress) {
            assert(addr == super::l2_bridge::read(), 'ERC20: caller not bridge');
        }

        fn approve(owner: ContractAddress, spender: ContractAddress, amount: u256) {
            assert(spender.is_non_zero(), 'ERC20: approve to 0');
            super::allowances::write((owner, spender), amount);

            super::Approval(owner, spender, amount);
        }

        fn spend_allowance(owner: ContractAddress, spender: ContractAddress, amount: u256) {
            let allowance = super::allowances::read((owner, spender));
            if allowance != BoundedInt::max() {
                // if not unlimited allowance, update it
                approve(owner, spender, allowance - amount);
            }
        }

        fn transfer(sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            assert(recipient.is_non_zero(), 'ERC20: transfer to 0');
            super::balances::write(sender, super::balances::read(sender) - amount);
            super::balances::write(recipient, super::balances::read(recipient) + amount);

            super::Transfer(sender, recipient, amount);
        }
    }
}
