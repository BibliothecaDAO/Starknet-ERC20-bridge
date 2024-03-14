use starknet::ContractAddress;

#[starknet::interface]
trait IBridge<TContractState> {
    fn set_l2_token_once(ref self: TContractState, l2_token: ContractAddress);
    //fn handle_deposit(ref self: TContractState, from_address: felt252, recipient: ContractAddress, amount: u256);
    fn initiate_withdrawal(ref self: TContractState, l1_recipient: felt252, amount: u256);
    fn get_l1_bridge(self: @TContractState) -> felt252;
    fn get_token(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
trait IToken<TContractState> {
    fn burn(ref self: TContractState, owner: starknet::ContractAddress, amount: u256) -> bool;
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
mod Bridge {
    use super::{IBridge, ITokenDispatcher, ITokenDispatcherTrait};

    use array::ArrayTrait;
    use starknet::{ContractAddress, EthAddress, contract_address, get_caller_address};
    use starknet::syscalls::send_message_to_l1_syscall;
    use traits::{Into, TryInto};
    use zeroable::Zeroable;

    // operation ID sent in the message payload to L1
    const PROCESS_WITHDRAWAL: felt252 = 1;

    // Ethereum addresses are bound to 2**160
    const ETH_ADDRESS_BOUND: u256 = 0x10000000000000000000000000000000000000000_u256;

    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    enum Event {
        DepositHandled: DepositHandled,
        WithdrawalInitiated: WithdrawalInitiated
    }

    #[derive(Copy, Drop, starknet::Event)]
    struct DepositHandled {
        recipient: ContractAddress,
        amount: u256
    }

    #[derive(Copy, Drop, starknet::Event)]
    struct WithdrawalInitiated {
        recipient: felt252,
        amount: u256
    }

    #[storage]
    struct Storage {
        // address L1 bridge contract address, the L1 counterpart to this contract
        l1_bridge: felt252,
        // the Lords ERC20 token on Starknet
        l2_token: ITokenDispatcher
    }

    #[constructor]
    fn constructor(ref self: ContractState, l1_bridge: felt252) {
        self.l1_bridge.write(l1_bridge);
    }

    #[abi(per_item)]
    #[generate_trait]
    impl L1HandlerImpl of L1HandlerTrait {
        #[l1_handler]
        fn handle_deposit(ref self: ContractState, from_address: felt252, recipient: ContractAddress, amount: u256) {
            assert(from_address == self.l1_bridge.read(), 'Bridge: invalid L1 origin');
            self.l2_token.read().mint(recipient, amount);
            self.emit(DepositHandled { recipient, amount });
        }
    }

    #[abi(embed_v0)]
    impl BridgeImpl of IBridge<ContractState> {
        fn set_l2_token_once(ref self: ContractState, l2_token: ContractAddress) {
            assert(self.l2_token.read().contract_address.is_zero(), 'Bridge: L2 token already set');
            self.l2_token.write(ITokenDispatcher { contract_address: l2_token });
        }

        fn initiate_withdrawal(ref self: ContractState, l1_recipient: felt252, amount: u256) {
            assert(l1_recipient.is_non_zero(), 'Bridge: L1 address cannot be 0');
            assert(l1_recipient.into() < ETH_ADDRESS_BOUND, 'Bridge: L1 addr out of bounds');
            assert(l1_recipient != self.l1_bridge.read(), 'Bridge: invalid recipient');

            self.l2_token.read().burn(get_caller_address(), amount);

            let mut message: Array<felt252> = ArrayTrait::new();
            message.append(PROCESS_WITHDRAWAL);
            message.append(l1_recipient);
            message.append(amount.low.into());
            message.append(amount.high.into());

            send_message_to_l1_syscall(self.l1_bridge.read(), message.span());
            self.emit(WithdrawalInitiated { recipient: l1_recipient, amount });
        }

        fn get_l1_bridge(self: @ContractState) -> felt252 {
            self.l1_bridge.read()
        }

        fn get_token(self: @ContractState) -> ContractAddress {
            self.l2_token.read().contract_address
        }
    }
}
