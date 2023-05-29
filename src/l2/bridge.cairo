#[abi]
trait IToken {
    fn burn(owner: starknet::ContractAddress, amount: u256) -> bool;
    fn mint(recipient: starknet::ContractAddress, amount: u256) -> bool;
}

#[contract]
mod Bridge {
    use super::{ITokenDispatcher, ITokenDispatcherTrait};

    use array::ArrayTrait;
    use starknet::{ContractAddress, EthAddress, contract_address, get_caller_address};
    use starknet::syscalls::send_message_to_l1_syscall;
    use traits::{Into, TryInto};
    use zeroable::Zeroable;

    // operation ID sent in the message payload to L1
    const PROCESS_WITHDRAWAL: felt252 = 1;

    #[event]
    fn DepositHandled(recipient: ContractAddress, amount: u256) {}

    #[event]
    fn WithdrawalInitiated(recipient: felt252, amount: u256) {}

    struct Storage {
        // address L1 bridge contract address, the L1 counterpart to this contract
        l1_bridge: felt252,
        // the Lords ERC20 token on Starknet
        l2_token: ITokenDispatcher
    }

    #[constructor]
    fn constructor(l1_bridge: felt252, l2_token: ContractAddress) {
        l1_bridge::write(l1_bridge);
        l2_token::write(ITokenDispatcher { contract_address: l2_token });
    }

    #[l1_handler]
    fn handle_deposit(from_address: felt252, recipient: ContractAddress, amount: u256) {
        assert(from_address == l1_bridge::read(), 'Bridge: invalid L1 origin');
        l2_token::read().mint(recipient, amount);
        DepositHandled(recipient, amount);
    }

    #[external]
    fn initiate_withdrawal(l1_recipient: felt252, amount: u256) {
        assert(l1_recipient.is_non_zero(), 'Bridge: L1 address cannot be 0');
        // Ethereum addresses are bound to 2**160 which is this number below as u256
        let eth_address_bound = u256 { low: 0, high: 0x100000000 };
        assert(l1_recipient.into() < eth_address_bound, 'Bridge: L1 addr out of bounds');
        assert(l1_recipient != l1_bridge::read(), 'Bridge: invalid recipient');

        l2_token::read().burn(get_caller_address(), amount);

        let mut message: Array<felt252> = ArrayTrait::new();
        message.append(PROCESS_WITHDRAWAL);
        message.append(l1_recipient);
        message.append(amount.low.into());
        message.append(amount.high.into());

        send_message_to_l1_syscall(l1_recipient, message.span());
        WithdrawalInitiated(l1_recipient, amount);
    }

    #[view]
    fn get_l1_bridge() -> felt252 {
        l1_bridge::read()
    }

    #[view]
    fn get_token() -> ContractAddress {
        l2_token::read().contract_address
    }
}
