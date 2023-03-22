use starknet::ContractAddress;

#[abi]
trait IMintable {
    fn mint(recipient: ContractAddress, amount: u256) -> bool;
}

#[abi]
trait IBurnable {
    fn burn_away(owner: ContractAddress, amount: u256) -> bool;
}

#[contract]
mod LordsL2 {
    use array::ArrayTrait;
    use core::integer::u256;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::contract_address;
    use starknet::get_caller_address;
    use starknet::syscalls::send_message_to_l1_syscall;
    use traits::Into;
    use traits::TryInto;

    const PROCESS_WITHDRAWAL: felt252 = 1; // operation ID sent in the message payload to L1
    const U128_MAX: u128 = 0xffffffffffffffffffffffffffffffff_u128; // 2**128 - 1

    struct Storage {
        // L1 bridge contract address, the L1 counterpart to this contract
        l1_bridge: ContractAddress,
        // address of the $LORDS token contract on the L2
        l2_token: ContractAddress
    }

    #[constructor]
    fn constructor(l1_bridge: ContractAddress, l2_token: ContractAddress) {
        l1_bridge::write(l1_bridge);
        l2_token::write(l2_token);
    }

    #[l1_handler]
    fn handle_deposit(origin: ContractAddress, recipient: ContractAddress, amount_low: felt252, amount_high: felt252, _msg_sender: felt252) {
        // note: `_msg_sender` is the L1 msg.sender value, we don't use it

        assert(origin == l1_bridge::read(), 'invalid L1 message origin');

        let amount: u256 = u256 {
            low: amount_low.try_into().unwrap(),
            high: amount_high.try_into().unwrap()
        };

        IMintable.mint(l2_token::read(), recipient, amount);
    }

    #[external]
    fn initiate_withdrawal(l1_recipient: felt252, amount: u256) {
        assert_eth_address_range(l1_recipient);

        let l1_recipient_addr: ContractAddress = l1_recipient.try_into().unwrap();
        assert(l1_recipient_addr != l1_bridge::read(), 'Recipient cannot be the bridge');

        IBurnable.burn_away(l2_token::read(), get_caller_address(), amount);

        let mut message: Array<felt252> = ArrayTrait::new();
        message.append(PROCESS_WITHDRAWAL);
        message.append(l1_recipient);
        message.append(amount.low.into());
        message.append(amount.high.into());
        send_message_to_l1_syscall(l1_recipient, message.span());
    }

    #[view]
    fn get_l1_bridge() -> ContractAddress {
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
        assert(addr != 0, 'Ethereum address cannot be zero');

        // we cannot compare felt252 anymore, so we have to use u256
        // L1 addresses are 160 bits long, so the upper (exclusive) bound
        // in u256 representation is { low: 0, high: 2**(160-128) }
        let max_l1_addr_value: u256 = u256 { low: 0_u128, high: 4294967296_u128 };
        assert(addr.into() < max_l1_addr_value, 'l1 addr out of bounds');
    }
}

// TODO: test, how?
