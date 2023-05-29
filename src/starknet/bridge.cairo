use starknet::ContractAddress;

#[abi]
trait IToken {
    fn burn(owner: ContractAddress, amount: u256) -> bool;
    fn mint(recipient: ContractAddress, amount: u256) -> bool;
}

#[contract]
mod LordsL2 {
    use super::ITokenDispatcher;
    use super::ITokenDispatcherTrait;

    use array::ArrayTrait;
    use core::integer::u256;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::contract_address;
    use starknet::get_caller_address;
    use starknet::syscalls::send_message_to_l1_syscall;
    use traits::Into;
    use traits::TryInto;
    use zeroable::Zeroable;

    const PROCESS_WITHDRAWAL: felt252 = 1; // operation ID sent in the message payload to L1

    #[event]
    fn DepositHandled(recipient: ContractAddress, amount: u256) {}

    #[event]
    fn WithdrawalInitiated(recipient: felt252, amount: u256) {}

    struct Storage {
        // L1 bridge contract address, the L1 counterpart to this contract
        l1_bridge: felt252,
        // address of the $LORDS token contract on the L2
        l2_token: ContractAddress
    }

    #[constructor]
    fn constructor(l1_bridge: felt252, l2_token: ContractAddress) {
        l1_bridge::write(l1_bridge);
        l2_token::write(l2_token);
    }

    #[l1_handler]
    fn handle_deposit(from_address: felt252, recipient: ContractAddress, amount: u256) {
        assert(from_address == l1_bridge::read(), 'invalid L1 message origin');
        ITokenDispatcher { contract_address: l2_token::read() }.mint(recipient, amount);
        DepositHandled(recipient, amount);
    }

    #[external]
    fn initiate_withdrawal(l1_recipient: felt252, amount: u256) {
        assert_eth_address_range(l1_recipient);
        assert(l1_recipient != l1_bridge::read(), 'invalid recipient');

        ITokenDispatcher { contract_address: l2_token::read() }.burn(get_caller_address(), amount);

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
        l2_token::read()
    }

    //
    // Internal
    //

    fn assert_eth_address_range(addr: felt252) {
        assert(addr.is_non_zero(), 'Ethereum address cannot be zero');

        // we cannot compare felt252 anymore, so we have to use u256
        // L1 addresses are 160 bits long, so the upper (exclusive) bound
        // in u256 representation is { low: 0, high: 2**(160-128) }
        let max_l1_addr_value: u256 = u256 { low: 0_u128, high: 0x100000000_u128 };
        assert(addr.into() < max_l1_addr_value, 'l1 addr out of bounds');
    }
}

// TODO: test, how?
