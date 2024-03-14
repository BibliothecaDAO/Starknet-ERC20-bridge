use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    fn totalSupply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
trait IToken<TContractState> {
    fn burn(ref self: TContractState, owner: starknet::ContractAddress, amount: u256) -> bool;
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
mod Token {
    use super::{IERC20, IToken};
    use integer::BoundedInt;
    use starknet::{ContractAddress, contract_address, get_caller_address};
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        // address of the Lords bridge contract on Starknet, only it can mint and burn
        l2_bridge: ContractAddress,
        // ERC20 related storage vars
        supply: u256,
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval
    }


    #[derive(Copy, Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    #[derive(Copy, Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, l2_bridge: ContractAddress) {
        self.l2_bridge.write(l2_bridge);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            'Lords'
        }

        fn symbol(self: @ContractState) -> felt252 {
            'LORDS'
        }

        fn decimals(self: @ContractState) -> u8 {
            18
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.supply.read()
        }

        fn totalSupply(self: @ContractState) -> u256 {
            self.supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.approve_helper(get_caller_address(), spender, amount);
            true
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.transfer_helper(get_caller_address(), recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.spend_allowance(sender, get_caller_address(), amount);
            self.transfer_helper(sender, recipient, amount);
            true
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.transfer_from(sender, recipient, amount)
        }
    }


    #[abi(embed_v0)]
    impl ITokenImpl of IToken<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.assert_is_bridge(get_caller_address());
            // deliberately not doing any more checks because this fn
            // is called by the bridge's L1 handler, don't want it to panic

            self.supply.write(self.supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);

            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
            true
        }

        fn burn(ref self: ContractState, owner: ContractAddress, amount: u256) -> bool {
            self.assert_is_bridge(get_caller_address());

            self.supply.write(self.supply.read() - amount);
            self.balances.write(owner, self.balances.read(owner) - amount);

            self.emit(Transfer { from: owner, to: Zeroable::zero(), value: amount });
            true
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        #[inline(always)]
        fn assert_is_bridge(self: @ContractState, addr: ContractAddress) {
            assert(addr == self.l2_bridge.read(), 'ERC20: caller not bridge');
        }

        fn approve_helper(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            assert(spender.is_non_zero(), 'ERC20: approve to 0');
            self.allowances.write((owner, spender), amount);

            self.emit(Approval {owner, spender, value: amount });
        }

        fn spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            let allowance = self.allowances.read((owner, spender));
            if allowance != BoundedInt::max() {
                // if not unlimited allowance, update it
                self.approve_helper(owner, spender, allowance - amount);
            }
        }

        fn transfer_helper(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(recipient.is_non_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);

            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }
    }
}
